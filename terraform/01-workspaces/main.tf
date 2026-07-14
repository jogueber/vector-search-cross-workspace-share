locals {
  workspaces = {
    producer = { name = "vs-share-producer" }
    consumer = { name = "vs-share-consumer" }
  }
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# ── Root S3 buckets (one per workspace) ──────────────────────────────────────

resource "aws_s3_bucket" "root" {
  for_each      = local.workspaces
  bucket        = "${each.value.name}-root-${random_string.suffix.result}"
  force_destroy = true

  tags = {
    Name      = "${each.value.name}-root-${random_string.suffix.result}"
    ManagedBy = "opentofu"
    Project   = "vector-search-share"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "root" {
  for_each = local.workspaces
  bucket   = aws_s3_bucket.root[each.key].bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "root" {
  for_each                = local.workspaces
  bucket                  = aws_s3_bucket.root[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "root" {
  for_each = local.workspaces
  bucket   = aws_s3_bucket.root[each.key].id

  versioning_configuration {
    status = "Disabled"
  }
}

data "databricks_aws_bucket_policy" "root" {
  for_each = local.workspaces
  provider = databricks.mws
  bucket   = aws_s3_bucket.root[each.key].bucket
}

resource "aws_s3_bucket_policy" "root" {
  for_each   = local.workspaces
  bucket     = aws_s3_bucket.root[each.key].id
  policy     = data.databricks_aws_bucket_policy.root[each.key].json
  depends_on = [aws_s3_bucket_public_access_block.root]
}

# ── IAM cross-account role ────────────────────────────────────────────────────
# Both workspaces share one role since they run in the same AWS account.

data "databricks_aws_assume_role_policy" "this" {
  provider    = databricks.mws
  external_id = var.databricks_account_id
}

data "databricks_aws_crossaccount_policy" "this" {
  provider = databricks.mws
}

resource "aws_iam_role" "cross_account" {
  name               = "vs-share-crossaccount-${random_string.suffix.result}"
  assume_role_policy = data.databricks_aws_assume_role_policy.this.json

  tags = {
    ManagedBy = "opentofu"
    Project   = "vector-search-share"
  }
}

resource "aws_iam_role_policy" "cross_account" {
  name   = "databricks-cross-account"
  role   = aws_iam_role.cross_account.id
  policy = data.databricks_aws_crossaccount_policy.this.json
}

# IAM changes take a few seconds to propagate globally before Databricks can assume the role.
resource "time_sleep" "iam_propagation" {
  create_duration = "10s"
  depends_on      = [aws_iam_role_policy.cross_account]
}

# ── MWS credentials ───────────────────────────────────────────────────────────

resource "databricks_mws_credentials" "this" {
  for_each         = local.workspaces
  provider         = databricks.mws
  credentials_name = "${each.value.name}-creds-${random_string.suffix.result}"
  role_arn         = aws_iam_role.cross_account.arn
  depends_on       = [time_sleep.iam_propagation]
}

# ── MWS storage configurations ────────────────────────────────────────────────

resource "databricks_mws_storage_configurations" "this" {
  for_each                   = local.workspaces
  provider                   = databricks.mws
  account_id                 = var.databricks_account_id
  storage_configuration_name = "${each.value.name}-storage-${random_string.suffix.result}"
  bucket_name                = aws_s3_bucket.root[each.key].bucket
  depends_on                 = [aws_s3_bucket_policy.root]
}

# ── Databricks workspaces (Databricks-managed VPC) ───────────────────────────
# network_id omitted → Databricks provisions the VPC automatically.

resource "databricks_mws_workspaces" "this" {
  for_each                 = local.workspaces
  provider                 = databricks.mws
  account_id               = var.databricks_account_id
  workspace_name           = "${each.value.name}-${random_string.suffix.result}"
  aws_region               = var.aws_region
  credentials_id           = databricks_mws_credentials.this[each.key].credentials_id
  storage_configuration_id = databricks_mws_storage_configurations.this[each.key].storage_configuration_id

  timeouts {
    create = "30m"
    update = "20m"
  }
}
