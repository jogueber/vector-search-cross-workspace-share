variable "producer_workspace_url" {
  description = "Producer workspace URL (from 01-workspaces output)."
  type        = string
}

variable "consumer_workspace_url" {
  description = "Consumer workspace URL (from 01-workspaces output)."
  type        = string
}

variable "consumer_sp_application_id" {
  description = "Application ID of the consumer service principal (from 02-unity-catalog output)."
  type        = string
}


variable "consumer_sp_client_secret" {
  description = "OAuth client secret for the consumer service principal. Generate in the Databricks account console under Service Principals."
  type        = string
  sensitive   = true
}

variable "consumer_sp_readonly_application_id" {
  description = "Application ID of the read-only consumer service principal (account-level, from 02-unity-catalog output)."
  type        = string
}

variable "consumer_sp_readonly_client_secret" {
  description = "OAuth client secret for the read-only consumer service principal. Generate in the Databricks account console under Service Principals."
  type        = string
  sensitive   = true
}

variable "catalog_name" {
  description = "Name of the Unity Catalog catalog created in the producer workspace."
  type        = string
  default     = "producer_catalog"
}

variable "schema_name" {
  description = "Name of the schema within the catalog."
  type        = string
  default     = "vector_data"
}

variable "vs_endpoint_name" {
  description = "Name of the Vector Search endpoint in the producer workspace."
  type        = string
  default     = "producer-vs-endpoint"
}
