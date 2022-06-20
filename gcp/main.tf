terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.25.0"
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
  name                    = "vpc"
  auto_create_subnetworks = "false"
}

# This IAM policy allows Cloud Run invocations from everywhere, including
# unauthenticated users. We'll use this to allow requests to the Frontend 
# Service from the public Internet, as this is the intended behavior.
data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
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
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }
}

resource "google_cloud_run_service_iam_policy" "frontend_noauth" {
  location = google_cloud_run_service.frontend.location
  project = google_cloud_run_service.frontend.project
  service = google_cloud_run_service.frontend.name
  policy_data = data.google_iam_policy.noauth.policy_data
}
