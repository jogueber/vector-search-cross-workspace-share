# ── Read-only consumer service principal ──────────────────────────────────────
# A second account-level SP with least-privilege access to the vector store.
# Demonstrates the recommended VectorSearchClient SDK query pattern.

resource "databricks_service_principal" "consumer_sp_readonly" {
  provider     = databricks.mws
  display_name = "vs-share-consumer-sp-readonly-account-${random_string.suffix.result}"
  active       = true
}

 resource "databricks_mws_permission_assignment" "consumer_sp_readonly_in_producer" {
  provider     = databricks.mws
  workspace_id = var.producer_workspace_id
  principal_id = databricks_service_principal.consumer_sp_readonly.id
  permissions  = ["USER"]
  depends_on   = [databricks_metastore_assignment.producer]
}

resource "databricks_mws_permission_assignment" "consumer_sp_readonly_in_consumer" {
  provider     = databricks.mws
  workspace_id = var.consumer_workspace_id
  principal_id = databricks_service_principal.consumer_sp_readonly.id
  permissions  = ["USER"]
  depends_on   = [databricks_metastore_assignment.consumer]
} 

resource "databricks_access_control_rule_set" "consumer_sp_readonly_users" {
  provider = databricks.mws
  name     = "accounts/${var.databricks_account_id}/servicePrincipals/${databricks_service_principal.consumer_sp_readonly.application_id}/ruleSets/default"

  grant_rules {
    principals = ["users/${data.databricks_current_user.tf.user_name}"]
    role       = "roles/servicePrincipal.user"
  }
}
