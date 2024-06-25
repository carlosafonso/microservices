terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.65.2"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 4.65.2"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

provider "google-beta" {
  project = var.gcp_project_id
  region  = var.gcp_region
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
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
    "clouddeploy.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "sourcerepo.googleapis.com"
  ]
  disable_services_on_destroy = false
}

# We use this null resource to trigger a local provisioner that modifies and
# hydrates manifests and other files which are external to Terraform.
#
# This hydrates generic values which are not environment-dependent.
# Environment-specific hydration should take place in the environment module
# (./modules/infra).
resource "null_resource" "generic_hydration" {
  provisioner "local-exec" {
    # Replace placeholders in Kubernetes manifests.
    command = "./scripts/hydrate-generic-placeholders.sh ${var.gcp_project_id}"
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
  location      = var.gcp_region
  repository_id = "microservices"
  format        = "DOCKER"

  provisioner "local-exec" {
    command = "./scripts/push-images-to-container-registry.sh ${var.gcp_project_id} ${var.gcp_region}"
  }

  depends_on = [module.project_services]
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

resource "google_clouddeploy_target" "frontend_gke_staging" {
  location = var.gcp_region
  name     = "msvc-fe-gke-staging"

  gke {
    cluster = module.infra_staging.gke_cluster.id
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.clouddeploy.email
  }

  depends_on = [module.project_services]
}

resource "google_clouddeploy_target" "frontend_gke_prod" {
  location = var.gcp_region
  name     = "msvc-fe-gke-prod"

  gke {
    cluster = module.infra_prod.gke_cluster.id
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.clouddeploy.email
  }

  require_approval = true

  depends_on = [module.project_services]
}

resource "google_clouddeploy_delivery_pipeline" "frontend_gke" {
  provider = google-beta
  location = var.gcp_region
  name     = "msvc-fe-gke"

  serial_pipeline {
    stages {
      target_id = "msvc-fe-gke-staging"
      profiles  = ["staging"]
    }

    stages {
      target_id = "msvc-fe-gke-prod"
      profiles  = ["prod"]

      strategy {
        canary {
          canary_deployment {
            percentages = [10, 50]
          }

          runtime_config {
            kubernetes {
              service_networking {
                deployment = "frontend-prod"
                service    = "frontend-prod"
              }
            }
          }
        }
      }
    }
  }

  depends_on = [module.project_services]
}

resource "google_clouddeploy_target" "frontend_run_staging" {
  provider = google-beta
  location = var.gcp_region
  name     = "msvc-fe-run-staging"

  run {
    location = "projects/${var.gcp_project_id}/locations/${var.gcp_region}"
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.clouddeploy.email
  }

  depends_on = [module.project_services]
}

resource "google_clouddeploy_target" "frontend_run_prod" {
  provider = google-beta
  location = var.gcp_region
  name     = "msvc-fe-run-prod"

  run {
    location = "projects/${var.gcp_project_id}/locations/${var.gcp_region}"
  }

  execution_configs {
    usages          = ["RENDER", "DEPLOY"]
    service_account = google_service_account.clouddeploy.email
  }

  depends_on = [module.project_services]
}

resource "google_clouddeploy_delivery_pipeline" "frontend_run" {
  provider = google-beta
  location = var.gcp_region
  name     = "msvc-fe-run"

  serial_pipeline {
    stages {
      target_id = "msvc-fe-run-staging"
      profiles  = ["run-staging"]
    }

    stages {
      target_id = "msvc-fe-run-prod"
      profiles  = ["run-prod"]

      strategy {
        canary {
          canary_deployment {
            percentages = [10, 50]
          }

          runtime_config {
            cloud_run {
              automatic_traffic_control = true
            }
          }
        }
      }
    }
  }

  depends_on = [module.project_services]
}

module "infra_staging" {
  source            = "./modules/infra"
  env               = "staging"
  gcp_project_id    = var.gcp_project_id
  gcp_region        = var.gcp_region
  enable_apis       = var.enable_apis
  enable_app_engine = var.enable_app_engine
  initial_words     = var.initial_words
  # Load generation is intentionally disabled in staging.
  enable_load_generator = false

  depends_on = [
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
    google_artifact_registry_repository.repo,
    module.project_services
  ]
}

module "infra_prod" {
  source            = "./modules/infra"
  env               = "prod"
  gcp_project_id    = var.gcp_project_id
  gcp_region        = var.gcp_region
  enable_apis       = var.enable_apis
  enable_app_engine = var.enable_app_engine
  initial_words     = var.initial_words
  # Load generation is enabled in prod depending on the user's settings.
  enable_load_generator = var.enable_load_generator

  depends_on = [
    google_artifact_registry_repository.repo,
    module.project_services
  ]
}
