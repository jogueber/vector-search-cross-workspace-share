output "metastore_id" {
  description = "ID of the Unity Catalog metastore attached to both workspaces."
  value       = databricks_metastore.this.id
}

output "consumer_sp_application_id" {
  description = "Application ID (OAuth client_id) of the consumer SP. Pass to 03-vector-search."
  value       = databricks_service_principal.consumer_sp.application_id
}

output "consumer_sp_id" {
  description = "Numeric SCIM ID of the consumer SP. Pass to 03-vector-search for run_as permissions."
  value       = databricks_service_principal.consumer_sp.id
}

output "consumer_sp_readonly_application_id" {
  description = "Application ID (OAuth client_id) of the read-only consumer SP. Pass to 03-vector-search."
  value       = databricks_service_principal.consumer_sp_readonly.application_id
}

output "consumer_sp_readonly_id" {
  description = "Numeric SCIM ID of the read-only consumer SP."
  value       = databricks_service_principal.consumer_sp_readonly.id
}

output "next_steps" {
  description = "Instructions to proceed to Phase 3."
  value       = <<-EOT
    Phase 2 complete. Unity Catalog metastore created and attached to both workspaces.

    Next steps:
      1. Copy outputs to 03-vector-search/terraform.tfvars:
           producer_workspace_url     = "${var.producer_workspace_url}"
           consumer_workspace_url     = "${var.consumer_workspace_url}"
           consumer_sp_application_id                  = "${databricks_service_principal.consumer_sp.application_id}"
           consumer_sp_id                              = "${databricks_service_principal.consumer_sp.id}"
           consumer_sp_readonly_application_id (account-level) = "${databricks_service_principal.consumer_sp_readonly.application_id}"

      2. cd ../03-vector-search && tofu init && tofu apply
  EOT
}
