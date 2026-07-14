variable "aws_region" {
  description = "AWS region — must match Phase 1."
  type        = string
  default     = "eu-central-1"
}

variable "databricks_account_id" {
  description = "Databricks account ID for the AWS account."
  type        = string
  sensitive   = true
}

variable "producer_workspace_url" {
  description = "Producer workspace URL (from 01-workspaces output)."
  type        = string
}

variable "producer_workspace_id" {
  description = "Producer workspace numeric ID (from 01-workspaces output)."
  type        = string
}

variable "consumer_workspace_url" {
  description = "Consumer workspace URL (from 01-workspaces output)."
  type        = string
}

variable "consumer_workspace_id" {
  description = "Consumer workspace numeric ID (from 01-workspaces output)."
  type        = string
}
