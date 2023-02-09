variable "env" {
  type        = string
  description = "The environment that this stack belongs to (e.g., 'staging', 'prod', etc.)."
}

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
  description = "Whether to automatically enable the necessary Google Cloud APIs."
}

variable "enable_app_engine" {
  type        = bool
  description = "Whether to automatically create and enable App Engine. If an App Engine application has already been defined, you should set this to `false`."
}

variable "initial_words" {
  type        = list(string)
  description = "The initial set of words to store in the word service."
}
