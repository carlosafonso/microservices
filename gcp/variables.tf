variable "project" {}

variable "region" {}

variable "zone" {}

variable "enable_apis" {
  type = bool
  default = true
  description = "Whether to automatically enable the necessary Google Cloud APIs."
}
