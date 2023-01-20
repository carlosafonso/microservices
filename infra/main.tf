terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.48.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.48.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# In GAE, these two GCP regions don't map directly to GAE's regions so a
# special mapping must be considered.
locals {
  gcp_to_app_engine_regions = {
    "europe-west1" : "europe-west",
    "us-central1" : "us-central"
  }
}

# This module will ensure that all the necessary GCP APIs are enabled. You'll
# see quite a bit of "depends_on" attributes scattered throughout other
# resources, as we need to wait until the services are enabled before
# proceeding. Once the rest of components are refactored into separate modules
# this dependency declaration will be simplified.
module "project_services" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 13.0"

  project_id  = var.gcp_project_id
  enable_apis = var.enable_apis

  activate_apis = [
    "appengine.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "clouddeploy.googleapis.com",
    "container.googleapis.com",
    "firestore.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "sourcerepo.googleapis.com"
  ]
  disable_services_on_destroy = false
}

###############################################################################
# Module: network
###############################################################################
resource "google_compute_network" "vpc" {
  name                    = "microservices"
  auto_create_subnetworks = "false"

  depends_on = [module.project_services]
}

resource "google_compute_subnetwork" "subnetwork" {
  name          = "microservices"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.gcp_region
  network       = google_compute_network.vpc.id
}

###############################################################################
# Module: common stuff
###############################################################################
# The Pub/Sub topic where events will be published.
#
# This topic is currently consumed only by the worker service, but we could
# also e.g. send events into BigQuery for analytical consumption in the future.
resource "google_pubsub_topic" "events" {
  name = "events"

  depends_on = [module.project_services]
}

# This IAM policy only allows Cloud Run invocations from the Frontend Service's
# service account. We'll use this to protect the private Cloud Run services.
data "google_iam_policy" "allow_frontend_only" {
  binding {
    role = "roles/run.invoker"
    members = [
      "serviceAccount:${google_service_account.frontend_svc.email}",
    ]
  }
}

# The Cloud Source Repository for the Frontend Service code.
resource "google_sourcerepo_repository" "frontend" {
  name = "microservices-frontend"

  provisioner "local-exec" {
    command = "./scripts/push-code-to-source-repository.sh ${self.url}"
  }

  depends_on = [module.project_services]
}

# The Artifact Registry repo for the Frontend Service image.
resource "google_artifact_registry_repository" "repo" {
  provider      = google-beta
  project       = var.gcp_project_id
  location      = var.gcp_region
  repository_id = "microservices"
  format        = "DOCKER"

  provisioner "local-exec" {
    command = "./scripts/push-images-to-container-registry.sh ${var.gcp_project_id} ${var.gcp_region}"
  }

  depends_on = [module.project_services]
}

###############################################################################
# Module: GKE
###############################################################################
resource "google_service_account" "gke" {
  account_id   = "microservices-gke"
  display_name = "microservices - Service account for the GKE cluster nodes"
}

# These IAM bindings allow GKE nodes to download images from Artifact Registry
# and publish messages to Pub/Sub.
#
# (In a real life scenario you'd want to use Workload Identity and grant
# permissions to each pod rather than the node.)
module "gke_nodes_svc_acct_iam_member_roles" {
  source                  = "terraform-google-modules/iam/google//modules/member_iam"
  service_account_address = google_service_account.gke.email
  project_id              = var.gcp_project_id
  project_roles = [
    "roles/artifactregistry.reader",
    "roles/pubsub.publisher",
  ]
}

resource "google_container_cluster" "cluster" {
  name       = "microservices"
  location   = var.gcp_region
  network    = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.subnetwork.self_link

  remove_default_node_pool = true
  initial_node_count       = 1

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {}

  depends_on = [module.project_services]
}

resource "google_container_node_pool" "nodepool" {
  name    = "microservices"
  cluster = google_container_cluster.cluster.id

  node_config {
    service_account = google_service_account.gke.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  autoscaling {
    min_node_count = 0
    max_node_count = 2
  }
}

resource "google_service_account" "cloudbuild" {
  account_id   = "microservices-cloudbuild"
  display_name = "microservices - Service account for running Cloud Build builds"
}

# To-Do: we probably want to narrow this down to just the required permissions,
# including the clouddeploy.released role (https://cloud.google.com/deploy/docs/integrating-ci#calling_from_your_ci_pipeline)
# for creating a Cloud Deploy release after a successful build.
resource "google_project_iam_member" "cloudbuild" {
  project = var.gcp_project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_service_account" "clouddeploy" {
  account_id   = "microservices-clouddeploy"
  display_name = "microservices - Service account for running Cloud Deploy delivery pipelines"
}

# To-Do: we probably want to narrow this down to just the required permissions.
resource "google_project_iam_member" "clouddeploy" {
  project = var.gcp_project_id
  role    = "roles/owner"
  member  = "serviceAccount:${google_service_account.clouddeploy.email}"
}

resource "google_cloudbuild_trigger" "trigger" {
  name            = "microservices-frontend"
  service_account = google_service_account.cloudbuild.id

  trigger_template {
    repo_name   = split("/repos/", google_sourcerepo_repository.frontend.id)[1]
    branch_name = ".*"
  }

  substitutions = {
    _DEFAULT_REPO = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/microservices"
    _REGION       = "${var.gcp_region}"
  }

  filename = "cloudbuild.yaml"

  depends_on = [module.project_services]
}

resource "google_clouddeploy_target" "staging" {
  location = var.gcp_region
  name     = "microservices-frontend-staging"

  gke {
    cluster = google_container_cluster.cluster.id
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.clouddeploy.email
  }

  depends_on = [module.project_services]
}

resource "google_clouddeploy_target" "prod" {
  location = var.gcp_region
  name     = "microservices-frontend-prod"

  gke {
    cluster = google_container_cluster.cluster.id
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.clouddeploy.email
  }

  require_approval = true

  depends_on = [module.project_services]
}

resource "google_clouddeploy_delivery_pipeline" "pipeline" {
  location = var.gcp_region
  name     = "microservices-frontend"

  serial_pipeline {
    stages {
      target_id = "microservices-frontend-staging"
      profiles  = ["staging"]
    }

    stages {
      target_id = "microservices-frontend-prod"
      profiles  = ["prod"]
    }
  }

  depends_on = [module.project_services]
}

###############################################################################
# Module: font-color service
###############################################################################
resource "google_cloud_run_service" "font_color" {
  name     = "font-color"
  location = var.gcp_region

  template {
    spec {
      containers {
        image = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/microservices/microservices-font-color:latest"
        ports {
          container_port = 8080
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  # We must wait until the Artifact Registry repository is created, because it
  # has a local provisioner which will push the images after pulling them from
  # the authoritative source (Docker Hub).
  #
  # If there was a way to obtain Artifact Registry repository URLs from
  # Terraform attributes, the dependency between Cloud Run services and the
  # repository would be implicit. However, Terraform does not seem to expose
  # such attributes so the image URLs are constructed by hand. Thus, the
  # dependency must be declared explicitly.
  #
  # (If no dependency was declared, the Cloud Run services would be created in
  # parallel and the images might not be present by the time Cloud Run attempts
  # to pull them, leading to a stack creation error.)
  #
  # Note that we are also declaring a dependency on the project_services
  # module, which ensures that the required GCP APIs are enabled.
  depends_on = [
    google_artifact_registry_repository.repo,
    module.project_services
  ]
}

resource "google_cloud_run_service_iam_policy" "font_color_noauth" {
  location    = google_cloud_run_service.font_color.location
  project     = google_cloud_run_service.font_color.project
  service     = google_cloud_run_service.font_color.name
  policy_data = data.google_iam_policy.allow_frontend_only.policy_data
}

###############################################################################
# Module: font-size service
###############################################################################
resource "google_cloud_run_service" "font_size" {
  name     = "font-size"
  location = var.gcp_region

  template {
    spec {
      containers {
        image = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/microservices/microservices-font-size:latest"
        ports {
          container_port = 8080
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  # See comment in google_cloud_run_service.font_color.
  depends_on = [
    google_artifact_registry_repository.repo,
    module.project_services
  ]
}

resource "google_cloud_run_service_iam_policy" "font_size_noauth" {
  location    = google_cloud_run_service.font_size.location
  project     = google_cloud_run_service.font_size.project
  service     = google_cloud_run_service.font_size.name
  policy_data = data.google_iam_policy.allow_frontend_only.policy_data
}

###############################################################################
# Module: word service
###############################################################################
resource "google_service_account" "word_svc" {
  account_id   = "word-svc"
  display_name = "Word Service"
}

module "word_svc_acct_roles" {
  source                  = "terraform-google-modules/iam/google//modules/member_iam"
  service_account_address = resource.google_service_account.word_svc.email
  project_id              = var.gcp_project_id
  project_roles           = ["roles/datastore.user"]
}

resource "google_app_engine_application" "main" {
  count         = var.enable_app_engine ? 1 : 0
  project       = var.gcp_project_id
  location_id   = lookup(local.gcp_to_app_engine_regions, var.gcp_region, var.gcp_region)
  database_type = "CLOUD_FIRESTORE"
}

resource "google_cloud_run_service" "word" {
  name     = "word"
  location = var.gcp_region

  template {
    spec {
      service_account_name = google_service_account.word_svc.email

      containers {
        image = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/microservices/microservices-word:latest"
        ports {
          container_port = 80
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  # See comment in google_cloud_run_service.font_color.
  depends_on = [
    google_artifact_registry_repository.repo,
    module.project_services
  ]
}

resource "google_cloud_run_service_iam_policy" "word_svc" {
  location    = google_cloud_run_service.word.location
  project     = google_cloud_run_service.word.project
  service     = google_cloud_run_service.word.name
  policy_data = data.google_iam_policy.allow_frontend_only.policy_data
}

###############################################################################
# Module: frontend service
###############################################################################
resource "google_service_account" "frontend_svc" {
  account_id   = "frontend-svc"
  display_name = "Frontend Service"
}

# This IAM policy allows the Frontend Service to publish messages into Pub/Sub.
resource "google_project_iam_binding" "frontend_svc_account" {
  project = var.gcp_project_id
  role    = "roles/pubsub.publisher"
  members = [
    "serviceAccount:${google_service_account.frontend_svc.email}",
  ]
}

resource "google_cloud_run_service" "frontend" {
  name     = "frontend"
  location = var.gcp_region

  template {
    spec {
      service_account_name = google_service_account.frontend_svc.email

      containers {
        image = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/microservices/microservices-frontend:latest"
        ports {
          container_port = 8080
        }
        env {
          name  = "MICROSERVICES_ENV"
          value = "prod"
        }
        env {
          name  = "FONT_COLOR_SVC"
          value = google_cloud_run_service.font_color.status[0].url
        }
        env {
          name  = "FONT_SIZE_SVC"
          value = google_cloud_run_service.font_size.status[0].url
        }
        env {
          name  = "WORD_SVC"
          value = google_cloud_run_service.word.status[0].url
        }
        env {
          name  = "PUBSUB_EVENTS_TOPIC"
          value = google_pubsub_topic.events.name
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  # See comment in google_cloud_run_service.font_color.
  depends_on = [
    google_artifact_registry_repository.repo,
    module.project_services
  ]
}

# This IAM policy allows Cloud Run invocations from everywhere, including
# unauthenticated users. We'll use this to allow requests to the Frontend
# Service from the public Internet, as this is the intended behavior.
#
# This policy is attached directly to the Cloud Run service.
data "google_iam_policy" "frontend" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

# This is the attachment of the previous IAM policy to the Cloud Run service.
resource "google_cloud_run_service_iam_policy" "frontend" {
  location    = google_cloud_run_service.frontend.location
  project     = google_cloud_run_service.frontend.project
  service     = google_cloud_run_service.frontend.name
  policy_data = data.google_iam_policy.frontend.policy_data
}

###############################################################################
# Module: worker service
###############################################################################
resource "google_cloud_run_service" "worker" {
  name     = "worker"
  location = var.gcp_region

  template {
    spec {
      containers {
        image = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/microservices/microservices-worker:latest"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  # See comment in google_cloud_run_service.font_color.
  depends_on = [
    google_artifact_registry_repository.repo,
    module.project_services
  ]
}

resource "google_service_account" "pubsub_events_worker_svc_subscription" {
  account_id   = "worker-svc-events"
  display_name = "Worker Service Subscription to Events Pub/Sub Topic"
}

resource "google_pubsub_subscription" "worker_svc_events" {
  name  = "worker-svc-events"
  topic = google_pubsub_topic.events.name

  # Setting this to the maximum value, as recommended by the Cloud Run docs
  # (https://cloud.google.com/run/docs/triggering/pubsub-push#ack-deadline)
  ack_deadline_seconds = 600

  push_config {
    push_endpoint = join("", [google_cloud_run_service.worker.status[0].url, "/pubsub/push"])

    oidc_token {
      service_account_email = google_service_account.pubsub_events_worker_svc_subscription.email
    }
  }
}

# This IAM policy allows Cloud Run invocations from the Pub/Sub subscription.
#
# This policy is attached directly to the Cloud Run service.
data "google_iam_policy" "worker" {
  binding {
    role = "roles/run.invoker"
    members = [
      "serviceAccount:${google_service_account.pubsub_events_worker_svc_subscription.email}",
    ]
  }
}

# This is the attachment of the previous IAM policy to the Cloud Run service.
resource "google_cloud_run_service_iam_policy" "worker" {
  location    = google_cloud_run_service.worker.location
  project     = google_cloud_run_service.worker.project
  service     = google_cloud_run_service.worker.name
  policy_data = data.google_iam_policy.worker.policy_data
}

###############################################################################
# Module: monitoring
###############################################################################
resource "google_monitoring_dashboard" "dashboard" {
  dashboard_json = <<-EOF
    {
      "displayName": "Microservices",
      "gridLayout": {
        "columns": "1",
        "widgets": [
          {
            "title": "Frontend Service - Response Latency - All Status Codes",
            "xyChart": {
              "dataSets": [
                {
                  "timeSeriesQuery": {
                    "timeSeriesFilter": {
                      "filter": "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"${google_cloud_run_service.frontend.name}\"",
                      "aggregation": {
                        "alignmentPeriod": "60s",
                        "perSeriesAligner": "ALIGN_PERCENTILE_50",
                        "crossSeriesReducer": "REDUCE_MAX"
                      }
                    }
                  },
                  "legendTemplate": "P50"
                },
                {
                  "timeSeriesQuery": {
                    "timeSeriesFilter": {
                      "filter": "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"${google_cloud_run_service.frontend.name}\"",
                      "aggregation": {
                        "alignmentPeriod": "60s",
                        "perSeriesAligner": "ALIGN_PERCENTILE_95",
                        "crossSeriesReducer": "REDUCE_MAX"
                      }
                    }
                  },
                  "legendTemplate": "P95"
                },
                {
                  "timeSeriesQuery": {
                    "timeSeriesFilter": {
                      "filter": "metric.type=\"run.googleapis.com/request_latencies\" resource.type=\"cloud_run_revision\" resource.label.\"service_name\"=\"${google_cloud_run_service.frontend.name}\"",
                      "aggregation": {
                        "alignmentPeriod": "60s",
                        "perSeriesAligner": "ALIGN_PERCENTILE_99",
                        "crossSeriesReducer": "REDUCE_MAX"
                      }
                    }
                  },
                  "legendTemplate": "P99"
                }
              ]
            }
          }
        ]
      }
    }
  EOF

  depends_on = [module.project_services]
}
