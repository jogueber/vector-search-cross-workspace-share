resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ── Metastore S3 bucket ───────────────────────────────────────────────────────

resource "aws_s3_bucket" "metastore" {
  bucket        = "vs-share-metastore-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    ManagedBy = "opentofu"
    Project   = "vector-search-share"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "metastore" {
  bucket = aws_s3_bucket.metastore.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "metastore" {
  bucket                  = aws_s3_bucket.metastore.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "metastore" {
  bucket = aws_s3_bucket.metastore.id

  versioning_configuration {
    status = "Disabled"
  }
}

# ── IAM role for metastore data access ───────────────────────────────────────

data "aws_caller_identity" "current" {}

data "databricks_aws_assume_role_policy" "metastore" {
  provider    = databricks.mws
  external_id = var.databricks_account_id
}

locals {
  metastore_role_name = "vs-share-metastore-${random_string.suffix.result}"
}

resource "aws_iam_role" "metastore" {
  name = local.metastore_role_name

  # Unity Catalog requires the role to trust itself (self-assumption) in addition
  # to the Databricks UCMasterRole. Without this the metastore data access check
  # fails with UC_IAM_ROLE_NON_SELF_ASSUMING.
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      jsondecode(data.databricks_aws_assume_role_policy.metastore.json).Statement,
      [{
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.metastore_role_name}" }
        Action    = "sts:AssumeRole"
      }]
    )
  })

  tags = {
    ManagedBy = "opentofu"
    Project   = "vector-search-share"
  }
}

resource "aws_iam_role_policy" "metastore" {
  name = "metastore-s3-access"
  role = aws_iam_role.metastore.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation",
      ]
      Resource = [
        aws_s3_bucket.metastore.arn,
        "${aws_s3_bucket.metastore.arn}/*",
      ]
    }]
  })
}

data "databricks_aws_bucket_policy" "metastore" {
  provider         = databricks.mws
  bucket           = aws_s3_bucket.metastore.bucket
  full_access_role = aws_iam_role.metastore.arn
}

resource "aws_s3_bucket_policy" "metastore" {
  bucket     = aws_s3_bucket.metastore.id
  policy     = data.databricks_aws_bucket_policy.metastore.json
  depends_on = [aws_s3_bucket_public_access_block.metastore]
}

# ── Unity Catalog metastore ───────────────────────────────────────────────────

resource "databricks_metastore" "this" {
  provider      = databricks.mws
  name          = "vs-share-${random_string.suffix.result}"
  storage_root  = "s3://${aws_s3_bucket.metastore.bucket}/metastore"
  region        = var.aws_region
  force_destroy = true

  depends_on = [aws_s3_bucket_policy.metastore]
}

# Configures the IAM role as the default data access credential for the metastore.
# Must be created after the metastore so we have the metastore_id.
resource "databricks_metastore_data_access" "this" {
  provider     = databricks.mws
  metastore_id = databricks_metastore.this.id
  name         = "metastore-data-access"
  is_default   = true

  aws_iam_role {
    role_arn = aws_iam_role.metastore.arn
  }

  depends_on = [aws_iam_role_policy.metastore]
}

# ── Metastore assignments ─────────────────────────────────────────────────────

resource "databricks_metastore_assignment" "producer" {
  provider     = databricks.mws
  metastore_id = databricks_metastore.this.id
  workspace_id = var.producer_workspace_id
  depends_on   = [databricks_metastore_data_access.this]
}

resource "databricks_metastore_assignment" "consumer" {
  provider     = databricks.mws
  metastore_id = databricks_metastore.this.id
  workspace_id = var.consumer_workspace_id
  depends_on   = [databricks_metastore_data_access.this]
}

# ── Terraform SP: grant ADMIN in both workspaces ─────────────────────────────
# The SP running Terraform must be a workspace admin to create resources via
# the workspace-level providers in phase 3.

data "databricks_current_user" "tf" {
  provider = databricks.workspace_producer
}

resource "databricks_mws_permission_assignment" "tf_sp_in_producer" {
  provider     = databricks.mws
  workspace_id = var.producer_workspace_id
  principal_id = data.databricks_current_user.tf.id
  permissions  = ["ADMIN"]
  depends_on   = [databricks_metastore_assignment.producer]
}

resource "databricks_mws_permission_assignment" "tf_sp_in_consumer" {
  provider     = databricks.mws
  workspace_id = var.consumer_workspace_id
  principal_id = data.databricks_current_user.tf.id
  permissions  = ["ADMIN"]
  depends_on   = [databricks_metastore_assignment.consumer]
}

# ── Consumer service principal ────────────────────────────────────────────────
# This SP represents the consumer workspace identity when querying the producer's
# Vector Search endpoint cross-workspace.

resource "databricks_service_principal" "consumer_sp" {
  provider     = databricks.mws
  display_name = "vs-share-consumer-sp-${random_string.suffix.result}"
  active       = true
}

# The consumer SP must exist in the producer workspace to receive endpoint ACLs.
resource "databricks_mws_permission_assignment" "consumer_sp_in_producer" {
  provider     = databricks.mws
  workspace_id = var.producer_workspace_id
  principal_id = databricks_service_principal.consumer_sp.id
  permissions  = ["USER"]
  depends_on   = [databricks_metastore_assignment.producer]
}

# The consumer SP must also exist in its own workspace to run notebooks there.
resource "databricks_mws_permission_assignment" "consumer_sp_in_consumer" {
  provider     = databricks.mws
  workspace_id = var.consumer_workspace_id
  principal_id = databricks_service_principal.consumer_sp.id
  permissions  = ["USER"]
  depends_on   = [databricks_metastore_assignment.consumer]
}

# Grant the Terraform runner the account-level servicePrincipal.user role on the
# consumer SP. This allows them to create Databricks jobs with run_as set to this
# SP — without it the job API returns "must have servicePrincipal.user role".
resource "databricks_access_control_rule_set" "consumer_sp_users" {
  provider = databricks.mws
  name     = "accounts/${var.databricks_account_id}/servicePrincipals/${databricks_service_principal.consumer_sp.application_id}/ruleSets/default"

  grant_rules {
    principals = ["users/${data.databricks_current_user.tf.user_name}"]
    role       = "roles/servicePrincipal.user"
  }
}
