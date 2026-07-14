provider "aws" {
  region  = var.aws_region
}

# Account-level provider for Multi-Workspace APIs (databricks_mws_* resources).
provider "databricks" {
  alias      = "mws"
  host       = "https://accounts.cloud.databricks.com"
  account_id = var.databricks_account_id
}

provider "random" {}

provider "time" {}
