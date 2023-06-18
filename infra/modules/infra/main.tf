locals {
  base_name = "msvc-${var.env}"
  gcp_to_app_engine_regions = {
    "europe-west1" : "europe-west",
    "us-central1" : "us-central"
  }
}

# We'll use this if we need to access the project's number.
data "google_project" "project" {
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
    "container.googleapis.com",
    "firestore.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
  ]
  disable_services_on_destroy = false
}

###############################################################################
# Module: network
###############################################################################
resource "google_compute_network" "vpc" {
  name                    = local.base_name
  auto_create_subnetworks = "false"

  depends_on = [module.project_services]
}

resource "google_compute_subnetwork" "subnetwork" {
  name          = local.base_name
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
  name = "${local.base_name}-events"

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

###############################################################################
# Module: GKE
###############################################################################
resource "google_service_account" "gke" {
  account_id   = "${local.base_name}-gke"
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
    # Needed by the logging / metric collection agents to send data to Cloud
    # Operations.
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/stackdriver.resourceMetadata.writer",
    # Needed by the word service to read from Cloud Firestore (if configured).
    "roles/datastore.user",
  ]
}

resource "google_container_cluster" "cluster" {
  name       = local.base_name
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
  name    = local.base_name
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

###############################################################################
# Module: font-color service
###############################################################################
resource "google_cloud_run_service" "font_color" {
  name     = "${local.base_name}-font-color"
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

  depends_on = [
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
  name     = "${local.base_name}-font-size"
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

  depends_on = [
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
  account_id   = "${local.base_name}-word-svc"
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
  name     = "${local.base_name}-word"
  location = var.gcp_region

  template {
    spec {
      service_account_name = google_service_account.word_svc.email

      containers {
        image = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/microservices/microservices-word:latest"
        ports {
          container_port = 80
        }
        env {
          name  = "USE_DATABASE"
          value = "true"
        }
        env {
          name  = "FIRESTORE_COLLECTION_NAME"
          value = google_firestore_document.word_data.collection
        }
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    module.project_services
  ]
}

resource "google_cloud_run_service_iam_policy" "word_svc" {
  location    = google_cloud_run_service.word.location
  project     = google_cloud_run_service.word.project
  service     = google_cloud_run_service.word.name
  policy_data = data.google_iam_policy.allow_frontend_only.policy_data
}

resource "google_firestore_document" "word_data" {
  collection  = "${local.base_name}-words"
  document_id = "words"
  fields = jsonencode(
    {
      "words" = {
        "arrayValue" = {
          "values" = [for word in var.initial_words : { "stringValue" = word }]
        }
      }
    }
  )
}

###############################################################################
# Module: frontend service
###############################################################################
resource "google_service_account" "frontend_svc" {
  account_id   = "${local.base_name}-frontend-svc"
  display_name = "Frontend Service"
}

# These IAM policies allow the Frontend Service to publish messages into
# Pub/Sub and retrieving secrets from Secret Manager.
module "frontend_svc_acct_iam_member_roles" {
  source                  = "terraform-google-modules/iam/google//modules/member_iam"
  service_account_address = google_service_account.frontend_svc.email
  project_id              = var.gcp_project_id
  project_roles = [
    "roles/pubsub.publisher",
    "roles/secretmanager.secretAccessor",
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

# The frontend service will be deployed via Cloud Deploy. However, we need to
# provision and attach related infra like roles and policies.
#
# This is a skeleton service that allows us to do that easily. However, we
# detach its lifecycle from Terraform's control because, once created, it will
# be managed by Cloud Deploy.
#
# Otherwise, after Cloud Deploy rolls out a new release, Terraform will see
# drift and will try to fix it, which is not what we want.
resource "google_cloud_run_service" "frontend" {
  name     = "${local.base_name}-frontend"
  location = var.gcp_region

  template {
    spec {
      service_account_name = google_service_account.frontend_svc.email

      containers {
        image = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/microservices/microservices-frontend:latest"
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

  depends_on = [
    module.project_services
  ]

  lifecycle {
    # Modifications to this service should occur via Cloud Deploy, so Terraform
    # must ignore the drift after creation.
    ignore_changes        = all
    create_before_destroy = false
  }
}

# These are attachments of the previous IAM policy to the frontend Cloud Run
# services.
resource "google_cloud_run_service_iam_policy" "frontend_svc" {
  location    = google_cloud_run_service.frontend.location
  project     = google_cloud_run_service.frontend.project
  service     = google_cloud_run_service.frontend.name
  policy_data = data.google_iam_policy.frontend.policy_data
}

###############################################################################
# Module: worker service
###############################################################################
resource "google_cloud_run_service" "worker" {
  name     = "${local.base_name}-worker"
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

  depends_on = [
    module.project_services
  ]
}

resource "google_service_account" "pubsub_events_worker_svc_subscription" {
  account_id   = "${local.base_name}-worker-svc-events"
  display_name = "Worker Service Subscription to Events Pub/Sub Topic"
}

resource "google_pubsub_subscription" "worker_svc_events" {
  name  = "${local.base_name}-worker-svc-events"
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

resource "google_secret_manager_secret" "font_color_run_svc_url" {
  secret_id = "${local.base_name}-font_color_run_svc_url"
  replication {
    user_managed {
      replicas {
        location = var.gcp_region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "font_color_run_svc_url" {
  secret      = google_secret_manager_secret.font_color_run_svc_url.id
  secret_data = google_cloud_run_service.font_color.status[0].url
}

resource "google_secret_manager_secret" "font_size_run_svc_url" {
  secret_id = "${local.base_name}-font_size_run_svc_url"
  replication {
    user_managed {
      replicas {
        location = var.gcp_region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "font_size_run_svc_url" {
  secret      = google_secret_manager_secret.font_size_run_svc_url.id
  secret_data = google_cloud_run_service.font_size.status[0].url
}

resource "google_secret_manager_secret" "word_run_svc_url" {
  secret_id = "${local.base_name}-word_run_svc_url"
  replication {
    user_managed {
      replicas {
        location = var.gcp_region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "word_run_svc_url" {
  secret      = google_secret_manager_secret.word_run_svc_url.id
  secret_data = google_cloud_run_service.word.status[0].url
}

resource "google_secret_manager_secret" "pubsub_events_topic_name" {
  secret_id = "${local.base_name}-pubsub_events_topic_name"
  replication {
    user_managed {
      replicas {
        location = var.gcp_region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "pubsub_events_topic_name" {
  secret      = google_secret_manager_secret.pubsub_events_topic_name.id
  secret_data = google_pubsub_topic.events.name
}

###############################################################################
# Module: monitoring
###############################################################################
resource "google_monitoring_dashboard" "dashboard" {
  dashboard_json = <<-EOF
    {
      "displayName": "Microservices (${var.env})",
      "gridLayout": {
        "columns": "1",
        "widgets": [
          {
            "title": "Frontend Service (Cloud Run) (${var.env}) - Response Latency - All Status Codes",
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

###############################################################################
# Module: analytics
###############################################################################
# Allow Pub/Sub to push data to BigQuery. Permissions must be assigned to the
# Pub/Sub service account.
#
# (See: https://cloud.google.com/pubsub/docs/create-subscription#assign_bigquery_service_account)
module "pubsub_svc_acct_pubsub_2_bq_iam_member_roles" {
  source                  = "terraform-google-modules/iam/google//modules/member_iam"
  service_account_address = "service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
  project_id              = var.gcp_project_id
  project_roles = [
    "roles/bigquery.metadataViewer",
    "roles/bigquery.dataEditor",
  ]
}

resource "google_bigquery_dataset" "main" {
  dataset_id = replace(local.base_name, "-", "_") # Can't have hyphens, apparently.
}

resource "google_bigquery_table" "events" {
  deletion_protection = false
  table_id            = "events"
  dataset_id          = google_bigquery_dataset.main.dataset_id

  schema = <<EOF
[
  {
    "name": "data",
    "type": "STRING",
    "mode": "NULLABLE",
    "description": "The data"
  }
]
EOF
}

resource "google_pubsub_subscription" "events_to_bigquery" {
  name  = "${local.base_name}-events-2-bq"
  topic = google_pubsub_topic.events.name

  bigquery_config {
    table = "${google_bigquery_table.events.project}:${google_bigquery_table.events.dataset_id}.${google_bigquery_table.events.table_id}"
  }

  # Make sure that the appropriate IAM permissions are set.
  depends_on = [module.pubsub_svc_acct_pubsub_2_bq_iam_member_roles]
}

# We use this null resource to trigger a local provisioner that modifies and
# hydrates manifests and other files which are external to Terraform.
resource "null_resource" "environment" {
  # Changes to the following resources will trigger this provisioner.
  triggers = {
    frontend_svc_acct_email = google_service_account.frontend_svc.email
  }

  provisioner "local-exec" {
    # Replace placeholders in Kubernetes manifests.
    command = "./scripts/replace-env-placeholders.sh ${var.env} ${google_service_account.frontend_svc.email}"
  }
}
