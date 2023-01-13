variable "gcp_project_id" {
  type        = string
  description = "The ID of the GCP project where the template should be deployed."
}

variable "gcp_region" {
  type        = string
  description = "The GCP region where the template should be deployed."
}

variable "enable_apis" {
  type        = bool
  default     = true
  description = "Whether to automatically enable the necessary Google Cloud APIs."
}

variable "enable_app_engine" {
  type        = bool
  default     = true
  description = "Whether to automatically create and enable App Engine. If an App Engine application has already been defined, you should set this to `false`."
}
