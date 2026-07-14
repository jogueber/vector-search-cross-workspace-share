variable "aws_region" {
  description = "AWS region for workspace deployment."
  type        = string
  default     = "eu-central-1"
}

variable "databricks_account_id" {
  description = "Databricks account ID for the AWS account."
  type        = string
  sensitive   = true
}


