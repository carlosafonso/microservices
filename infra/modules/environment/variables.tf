variable "prefix" {
  type        = string
  description = "A prefix to use with all resource name in this environment."
  default     = "msvc"
}

variable "env" {
  type        = string
  description = "The environment that this stack belongs to (e.g., 'staging', 'prod', etc.)."
}

variable "gcp_folder_id" {
  type        = string
  description = "The ID of the GCP folder where the environment should be deployed."
}

variable "gcp_billing_account_id" {
  type        = string
  description = "The ID of the billing account to attach to the environment project."
}
