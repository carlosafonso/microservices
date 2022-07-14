terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.28.0"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

###############################################################################
# Module: network
###############################################################################
resource "google_compute_network" "vpc" {
  name = "microservices"
  auto_create_subnetworks = "false"
}

resource "google_compute_subnetwork" "subnetwork" {
  name = "microservices"
  ip_cidr_range = "10.0.0.0/24"
  region = var.region
  network = google_compute_network.vpc.id
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
}

# The Artifact Registry repo for the Frontend Service image.
resource "google_artifact_registry_repository" "repo" {
  provider = google-beta
  location = var.region
  repository_id = "microservices"
  format = "DOCKER"
}

###############################################################################
# Module: GKE
###############################################################################
resource "google_service_account" "gke" {
  account_id   = "microservices-gke"
  display_name = "microservices - Service account for the GKE cluster nodes"
}

resource "google_project_iam_member" "gke_artifact_registry_viewer" {
  project = var.project
  role = "roles/artifactregistry.reader"
  member = "serviceAccount:${google_service_account.gke.email}"
}

resource "google_container_cluster" "cluster" {
  name = "microservices"
  location = var.region
  network = google_compute_network.vpc.self_link
  subnetwork = google_compute_subnetwork.subnetwork.self_link

  remove_default_node_pool = true
  initial_node_count = 1

  networking_mode = "VPC_NATIVE"
  ip_allocation_policy {}
}

resource "google_container_node_pool" "nodepool" {
  name = "microservices"
  cluster = google_container_cluster.cluster.id
  node_count = 1

  node_config {
    service_account = google_service_account.gke.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
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
  project = var.project
  role = "roles/owner"
  member = "serviceAccount:${google_service_account.cloudbuild.email}"
}

resource "google_service_account" "clouddeploy" {
  account_id   = "microservices-clouddeploy"
  display_name = "microservices - Service account for running Cloud Deploy delivery pipelines"
}

# To-Do: we probably want to narrow this down to just the required permissions.
resource "google_project_iam_member" "clouddeploy" {
  project = var.project
  role = "roles/owner"
  member = "serviceAccount:${google_service_account.clouddeploy.email}"
}

resource "google_cloudbuild_trigger" "trigger" {
  name = "microservices-frontend"
  service_account = google_service_account.cloudbuild.id

  trigger_template {
    repo_name = split("/repos/", google_sourcerepo_repository.frontend.id)[1]
    branch_name = ".*"
  }

  substitutions = {
    _DEFAULT_REPO = "${var.region}-docker.pkg.dev/${var.project}/microservices"
  }

  filename = "cloudbuild.yaml"
}

resource "google_clouddeploy_target" "staging" {
  location = var.region
  name = "microservices-frontend-staging"

  gke {
    cluster = google_container_cluster.cluster.id
  }

  execution_configs {
    usages = ["RENDER", "DEPLOY"]
    service_account = google_service_account.clouddeploy.email
  }
}

resource "google_clouddeploy_delivery_pipeline" "pipeline" {
  location = var.region
  name = "microservices-frontend"

  serial_pipeline {
    stages {
      target_id = "microservices-frontend-staging"
      #profiles = ["prod"]
    }
  }
}

###############################################################################
# Module: font-color service
###############################################################################
resource "google_cloud_run_service" "font_color" {
  name     = "font-color"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/${var.project}/microservices-font-color:latest"
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
}

resource "google_cloud_run_service_iam_policy" "font_color_noauth" {
  location = google_cloud_run_service.font_color.location
  project = google_cloud_run_service.font_color.project
  service = google_cloud_run_service.font_color.name
  policy_data = data.google_iam_policy.allow_frontend_only.policy_data
}

###############################################################################
# Module: font-size service
###############################################################################
resource "google_cloud_run_service" "font_size" {
  name     = "font-size"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/${var.project}/microservices-font-size:latest"
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
}

resource "google_cloud_run_service_iam_policy" "font_size_noauth" {
  location = google_cloud_run_service.font_size.location
  project = google_cloud_run_service.font_size.project
  service = google_cloud_run_service.font_size.name
  policy_data = data.google_iam_policy.allow_frontend_only.policy_data
}

###############################################################################
# Module: word service
###############################################################################
resource "google_cloud_run_service" "word" {
  name     = "word"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/${var.project}/microservices-word:latest"
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
}

resource "google_cloud_run_service_iam_policy" "word_svc" {
  location = google_cloud_run_service.word.location
  project = google_cloud_run_service.word.project
  service = google_cloud_run_service.word.name
  policy_data = data.google_iam_policy.allow_frontend_only.policy_data
}

###############################################################################
# Module: frontend service
###############################################################################
resource "google_service_account" "frontend_svc" {
  account_id = "frontend-svc"
  display_name = "Frontend Service"
}

# This IAM policy allows the Frontend Service to publish messages into Pub/Sub.
resource "google_project_iam_binding" "frontend_svc_account" {
  project = var.project
  role = "roles/pubsub.publisher"
  members = [
      "serviceAccount:${google_service_account.frontend_svc.email}",
  ]
}

resource "google_cloud_run_service" "frontend" {
  name     = "frontend"
  location = var.region

  template {
    spec {
      service_account_name = google_service_account.frontend_svc.email

      containers {
        image = "gcr.io/${var.project}/microservices-frontend:latest"
        ports {
          container_port = 8080
        }
        env {
          name = "FONT_COLOR_SVC"
          value = google_cloud_run_service.font_color.status[0].url
        }
        env {
          name = "FONT_SIZE_SVC"
          value = google_cloud_run_service.font_size.status[0].url
        }
        env {
          name = "WORD_SVC"
          value = google_cloud_run_service.word.status[0].url
        }
        env {
          name = "PUBSUB_EVENTS_TOPIC"
          value = google_pubsub_topic.events.name
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
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
  location = google_cloud_run_service.frontend.location
  project = google_cloud_run_service.frontend.project
  service = google_cloud_run_service.frontend.name
  policy_data = data.google_iam_policy.frontend.policy_data
}

###############################################################################
# Module: worker service
###############################################################################
resource "google_cloud_run_service" "worker" {
  name     = "worker"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/${var.project}/microservices-worker:latest"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_service_account" "pubsub_events_worker_svc_subscription" {
  account_id = "worker-svc-events"
  display_name = "Worker Service Subscription to Events Pub/Sub Topic"
}

resource "google_pubsub_subscription" "worker_svc_events" {
  name = "worker-svc-events"
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
  location = google_cloud_run_service.worker.location
  project = google_cloud_run_service.worker.project
  service = google_cloud_run_service.worker.name
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
}