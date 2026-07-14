# ── Secret scope + credentials for the read-only consumer SP ─────────────────
# Separate scope from the existing vs-share scope. The readonly SP reads its
# own M2M credentials from here to authenticate to the producer workspace.
# Cross-workspace VS queries require explicit M2M OAuth — ambient credentials
# from run_as are workspace-scoped and cannot be exchanged automatically.

resource "databricks_secret_scope" "vs_share_readonly" {
  provider = databricks.workspace_consumer
  name     = "vs-share-readonly"
}

resource "databricks_secret" "consumer_sp_readonly_client_id" {
  provider     = databricks.workspace_consumer
  scope        = databricks_secret_scope.vs_share_readonly.name
  key          = "consumer-sp-client-id"
  string_value = var.consumer_sp_readonly_application_id
}

resource "databricks_secret" "consumer_sp_readonly_client_secret" {
  provider     = databricks.workspace_consumer
  scope        = databricks_secret_scope.vs_share_readonly.name
  key          = "consumer-sp-client-secret"
  string_value = var.consumer_sp_readonly_client_secret
}

resource "databricks_secret_acl" "consumer_sp_readonly_read" {
  provider   = databricks.workspace_consumer
  scope      = databricks_secret_scope.vs_share_readonly.name
  principal  = var.consumer_sp_readonly_application_id
  permission = "READ"
}

# ── Read-only consumer demo notebook + job ───────────────────────────────────
# Uses the Databricks SDK's vector_search_indexes.query_index() API with
# explicit M2M OAuth (client_id + client_secret) for cross-workspace auth.

resource "databricks_notebook" "consumer_readonly_demo" {
  provider = databricks.workspace_consumer
  path     = "/Shared/vs-share/cross-workspace-query-readonly-demo"
  source   = "${path.module}/notebooks/consumer_query_readonly_demo.py"
  language = "PYTHON"
}

resource "databricks_job" "consumer_readonly_demo" {
  provider = databricks.workspace_consumer
  name     = "vs-share-cross-workspace-query-readonly-demo"

  run_as {
    service_principal_name = var.consumer_sp_readonly_application_id
  }

  task {
    task_key = "cross_workspace_query_readonly"

    notebook_task {
      notebook_path = databricks_notebook.consumer_readonly_demo.path
      source        = "WORKSPACE"

      base_parameters = {
        producer_workspace_url = var.producer_workspace_url
        vs_index_name          = "${var.catalog_name}.${var.schema_name}.documents_vs_index"
      }
    }

    # No cluster spec → serverless compute.
  }

  depends_on = [
    databricks_grants.vs_index,
    databricks_permissions.vs_endpoint,
    databricks_secret.consumer_sp_readonly_client_id,
    databricks_secret.consumer_sp_readonly_client_secret,
  ]
}
