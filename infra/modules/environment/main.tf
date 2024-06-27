locals {
  base_name = "${var.prefix}-${var.env}"
}

module "project-factory" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 15.0"

  name              = local.base_name
  random_project_id = true
  folder_id         = var.gcp_folder_id
  billing_account   = var.gcp_billing_account_id
}
