output "producer_workspace_url" {
  description = "URL of the producer workspace. Required input for 02-unity-catalog and 03-vector-search."
  value       = databricks_mws_workspaces.this["producer"].workspace_url
}

output "producer_workspace_id" {
  description = "Numeric ID of the producer workspace. Required input for 02-unity-catalog."
  value       = databricks_mws_workspaces.this["producer"].workspace_id
}

output "consumer_workspace_url" {
  description = "URL of the consumer workspace. Required input for 02-unity-catalog and 03-vector-search."
  value       = databricks_mws_workspaces.this["consumer"].workspace_url
}

output "consumer_workspace_id" {
  description = "Numeric ID of the consumer workspace. Required input for 02-unity-catalog."
  value       = databricks_mws_workspaces.this["consumer"].workspace_id
}

output "next_steps" {
  description = "Instructions to proceed to Phase 2."
  value       = <<-EOT
    Phase 1 complete. Both workspaces are provisioned.

    Next steps:
      1. Log in to both workspaces so the workspace-level Terraform providers can authenticate:
         databricks auth login --host ${databricks_mws_workspaces.this["producer"].workspace_url} --profile vs-share-producer
         databricks auth login --host ${databricks_mws_workspaces.this["consumer"].workspace_url} --profile vs-share-consumer

      2. Copy outputs to 02-unity-catalog/terraform.tfvars:
           producer_workspace_url = "${databricks_mws_workspaces.this["producer"].workspace_url}"
           producer_workspace_id  = "${databricks_mws_workspaces.this["producer"].workspace_id}"
           consumer_workspace_url = "${databricks_mws_workspaces.this["consumer"].workspace_url}"
           consumer_workspace_id  = "${databricks_mws_workspaces.this["consumer"].workspace_id}"

      3. cd ../02-unity-catalog && tofu init && tofu apply
  EOT
}
