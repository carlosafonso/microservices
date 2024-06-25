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

variable "initial_words" {
  type        = list(string)
  default     = ["function", "overcharge", "consensus", "pest", "related", "locate", "earwax", "refund", "lead", "stage"]
  description = "The initial set of words to store in the word service."
}

variable "enable_load_generator" {
  type        = bool
  default     = false
  description = "Whether to deploy synthetic load against the production environment. If enabled, this can incur additional cost."
}
