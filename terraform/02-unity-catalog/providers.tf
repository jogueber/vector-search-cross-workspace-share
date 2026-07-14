provider "aws" {
  region  = var.aws_region
}

# Account-level provider — metastore creation and workspace assignments.
provider "databricks" {
  alias      = "mws"
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id
}

# Workspace-level providers — needed for workspace-scoped resources after UC is attached.
provider "databricks" {
  alias   = "workspace_producer"
  host    = var.producer_workspace_url
}

provider "databricks" {
  alias   = "workspace_consumer"
  host    = var.consumer_workspace_url
}

provider "random" {}
