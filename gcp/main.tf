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


data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
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
  policy_data = data.google_iam_policy.noauth.policy_data
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
  policy_data = data.google_iam_policy.noauth.policy_data
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

resource "google_cloud_run_service_iam_policy" "word_noauth" {
  location = google_cloud_run_service.word.location
  project = google_cloud_run_service.word.project
  service = google_cloud_run_service.word.name
  policy_data = data.google_iam_policy.noauth.policy_data
}

###############################################################################
# Module: frontend service
###############################################################################
resource "google_cloud_run_service" "frontend" {
  name     = "frontend"
  location = var.region

  template {
    spec {
      containers {
        image = "gcr.io/${var.project}/microservices-frontend:latest"
        ports {
          container_port = 8080
        }
        env {
          name = "FONT_COLOR_SVC"
          value = split("https://", google_cloud_run_service.font_color.status[0].url)[1]
        }
        env {
          name = "FONT_SIZE_SVC"
          value = split("https://", google_cloud_run_service.font_size.status[0].url)[1]
        }
        env {
          name = "WORD_SVC"
          value = split("https://", google_cloud_run_service.word.status[0].url)[1]
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
