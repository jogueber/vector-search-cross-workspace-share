output "vs_endpoint_name" {
  description = "Name of the Vector Search endpoint in the producer workspace."
  value       = databricks_vector_search_endpoint.producer.name
}

output "vs_index_name" {
  description = "Fully qualified name of the Vector Search index (catalog.schema.index)."
  value       = databricks_vector_search_index.documents.name
}

output "producer_query_url" {
  description = "REST API URL to query the Vector Search index from the producer workspace."
  value       = "${var.producer_workspace_url}/api/2.0/vector-search/indexes/${databricks_vector_search_index.documents.name}/query"
}

output "consumer_demo_notebook_path" {
  description = "Path to the cross-workspace query demo notebook in the consumer workspace."
  value       = databricks_notebook.consumer_demo.path
}

output "consumer_demo_job_url" {
  description = "URL to run the consumer demo job (executes as the consumer SP via OIDC workload identity)."
  value       = "${var.consumer_workspace_url}/#job/${databricks_job.consumer_demo.id}"
}

output "consumer_readonly_demo_job_url" {
  description = "URL to run the read-only consumer demo job (executes as the account-level readonly SP via OAuth M2M)."
  value       = "${var.consumer_workspace_url}/#job/${databricks_job.consumer_readonly_demo.id}"
}

output "next_steps" {
  description = "Final setup steps to run the cross-workspace demo."
  value       = <<-EOT
    Phase 3 complete. Vector Search endpoint, index, and secret scope are provisioned.

    BEFORE running `tofu apply` for the first time:
      1. Generate client secrets for BOTH service principals:
         a. Go to: https://accounts.cloud.databricks.com
         b. Navigate to: User Management → Service Principals
         c. For each SP, click "Generate secret" and copy the secret
         d. Add to 03-vector-search/terraform.tfvars:
            consumer_sp_client_secret          = "<consumer SP secret>"
            consumer_sp_readonly_client_secret  = "<readonly SP secret>"
         e. Run `tofu apply` to store them in their respective secret scopes.

    After apply:
      2. Trigger the initial index sync (TRIGGERED pipeline — does not auto-sync):
         databricks vector-search indexes sync-index \
           --index-name ${var.catalog_name}.${var.schema_name}.documents_vs_index \
           --profile vs-share-producer

      3. Run the demo job in the consumer workspace (raw REST approach):
         ${var.consumer_workspace_url}/#job/${databricks_job.consumer_demo.id}
         (Runs as the consumer SP; authenticates via OAuth M2M.)

      4. Run the read-only SP demo job (SDK query_index approach):
         ${var.consumer_workspace_url}/#job/${databricks_job.consumer_readonly_demo.id}
         (Runs as the account-level readonly SP; authenticates via OAuth M2M.)

      5. Or run either notebook interactively:
         ${var.consumer_workspace_url}/#workspace${databricks_notebook.consumer_demo.path}
         ${var.consumer_workspace_url}/#workspace${databricks_notebook.consumer_readonly_demo.path}
         Set producer_workspace_url = ${var.producer_workspace_url}
  EOT
}
