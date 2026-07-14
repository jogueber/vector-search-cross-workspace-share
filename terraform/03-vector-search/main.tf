# ── Unity Catalog objects (producer workspace) ───────────────────────────────

resource "databricks_catalog" "producer" {
  provider = databricks.workspace_producer
  name     = var.catalog_name
  comment  = "Producer catalog for vector search cross-workspace sharing demo."
}

resource "databricks_schema" "vector_data" {
  provider     = databricks.workspace_producer
  catalog_name = databricks_catalog.producer.name
  name         = var.schema_name
  comment      = "Schema holding the source Delta table and Vector Search index."
}

# Grant the consumer SP access to the catalog hierarchy.
# databricks_grants is authoritative — it replaces all existing grants on the target.
resource "databricks_grants" "catalog" {
  provider = databricks.workspace_producer
  catalog  = databricks_catalog.producer.name

  grant {
    principal  = var.consumer_sp_application_id
    privileges = ["USE_CATALOG"]
  }

  grant {
    principal  = var.consumer_sp_readonly_application_id
    privileges = ["USE_CATALOG"]
  }
}

resource "databricks_grants" "schema" {
  provider = databricks.workspace_producer
  schema   = "${databricks_catalog.producer.name}.${databricks_schema.vector_data.name}"

  grant {
    principal  = var.consumer_sp_application_id
    privileges = ["USE_SCHEMA"]
  }

  grant {
    principal  = var.consumer_sp_readonly_application_id
    privileges = ["USE_SCHEMA"]
  }
}

# ── Bootstrap notebook + job (producer workspace) ────────────────────────────
# Creates the source Delta table with CDF enabled and inserts sample documents.
# The job runs once automatically via the terraform_data provisioner below.

resource "databricks_notebook" "bootstrap" {
  provider = databricks.workspace_producer
  path     = "/Shared/vs-share/bootstrap-source-table"
  source   = "${path.module}/notebooks/bootstrap_source_table.py"
  language = "PYTHON"
}

resource "databricks_job" "bootstrap" {
  provider = databricks.workspace_producer
  name     = "vs-share-bootstrap-source-table"

  task {
    task_key = "create_and_populate_table"

    notebook_task {
      notebook_path = databricks_notebook.bootstrap.path
      source        = "WORKSPACE"

      base_parameters = {
        "bootstrap.catalog" = var.catalog_name
        "bootstrap.schema"  = var.schema_name
      }
    }

    # No cluster spec → serverless compute.
  }

  depends_on = [databricks_schema.vector_data]
}

# Run the bootstrap job once and wait for it to complete (CLI waits by default).
# Requires the Databricks CLI and the vs-share-producer profile in ~/.databrickscfg.
resource "terraform_data" "run_bootstrap" {
  input = databricks_job.bootstrap.id

  provisioner "local-exec" {
    command = "databricks jobs run-now ${self.input}"
    environment = {
      DATABRICKS_HOST           = var.producer_workspace_url
    }
  }

  depends_on = [databricks_job.bootstrap]
}

# ── Vector Search endpoint (producer workspace) ───────────────────────────────

resource "databricks_vector_search_endpoint" "producer" {
  provider      = databricks.workspace_producer
  name          = var.vs_endpoint_name
  endpoint_type = "STANDARD"
}

# ── Vector Search index (producer workspace) ──────────────────────────────────
# DELTA_SYNC with Databricks-managed embeddings (databricks-gte-large-en, 1024 dim).
# pipeline_type = TRIGGERED: sync is triggered manually or via the bootstrap job.
# Source table must exist before this resource is created — enforced via depends_on.

resource "databricks_vector_search_index" "documents" {
  provider      = databricks.workspace_producer
  name          = "${var.catalog_name}.${var.schema_name}.documents_vs_index"
  endpoint_name = databricks_vector_search_endpoint.producer.name
  primary_key   = "id"
  index_type    = "DELTA_SYNC"

  delta_sync_index_spec {
    source_table  = "${var.catalog_name}.${var.schema_name}.documents"
    pipeline_type = "TRIGGERED"

    embedding_source_columns {
      name                          = "content"
      embedding_model_endpoint_name = "databricks-gte-large-en"
    }
  }

  depends_on = [terraform_data.run_bootstrap]
}

# Grant SELECT on the VS index to the consumer SP (Unity Catalog level).
resource "databricks_grants" "vs_index" {
  provider = databricks.workspace_producer
  table    = databricks_vector_search_index.documents.name

  grant {
    principal  = var.consumer_sp_application_id
    privileges = ["SELECT"]
  }

  grant {
    principal  = var.consumer_sp_readonly_application_id
    privileges = ["SELECT"]
  }

  depends_on = [databricks_vector_search_index.documents]
}

# ── Vector Search endpoint permissions (producer workspace) ───────────────────
# IMPORTANT: vector_search_endpoint_id must use .endpoint_id (UUID), NOT .id (name).
# Using .id here causes a silent failure with no error message.

resource "databricks_permissions" "vs_endpoint" {
  provider = databricks.workspace_producer

  vector_search_endpoint_id = databricks_vector_search_endpoint.producer.endpoint_id

  access_control {
    # Consumer SP needs CAN_USE to create queries against indexes on this endpoint.
    service_principal_name = var.consumer_sp_application_id
    permission_level       = "CAN_USE"
  }

  access_control {
    # Read-only consumer SP (account-level) also needs CAN_USE for query access.
    service_principal_name = var.consumer_sp_readonly_application_id
    permission_level       = "CAN_USE"
  }
}

# ── Secret scope + SP credentials (consumer workspace) ───────────────────────
# The notebook reads M2M credentials from this scope to authenticate to the
# producer workspace. The client_secret must be generated in the Databricks
# account console before running `tofu apply` (see outputs.next_steps).

resource "databricks_secret_scope" "vs_share" {
  provider = databricks.workspace_consumer
  name     = "vs-share"
}

resource "databricks_secret" "consumer_sp_client_id" {
  provider     = databricks.workspace_consumer
  scope        = databricks_secret_scope.vs_share.name
  key          = "consumer-sp-client-id"
  string_value = var.consumer_sp_application_id
}

resource "databricks_secret" "consumer_sp_client_secret" {
  provider     = databricks.workspace_consumer
  scope        = databricks_secret_scope.vs_share.name
  key          = "consumer-sp-client-secret"
  string_value = var.consumer_sp_client_secret
}

# Grant the consumer SP READ access to the secret scope so that the job
# running AS the SP can call dbutils.secrets.get().
resource "databricks_secret_acl" "consumer_sp_read" {
  provider   = databricks.workspace_consumer
  scope      = databricks_secret_scope.vs_share.name
  principal  = var.consumer_sp_application_id
  permission = "READ"
}

# ── Consumer demo notebook + job ──────────────────────────────────────────────

resource "databricks_notebook" "consumer_demo" {
  provider = databricks.workspace_consumer
  path     = "/Shared/vs-share/cross-workspace-query-demo"
  source   = "${path.module}/notebooks/consumer_query_demo.py"
  language = "PYTHON"
}

# The job runs AS the consumer SP (created in phase 2 and assigned to both
# workspaces). The SP's OIDC workload identity token is automatically exchanged
# for a producer-workspace token by the Databricks SDK — no client secrets needed.
# The servicePrincipal.user role grant is managed in phase 2 via
# databricks_access_control_rule_set.consumer_sp_users.
resource "databricks_job" "consumer_demo" {
  provider = databricks.workspace_consumer
  name     = "vs-share-cross-workspace-query-demo"

  run_as {
    service_principal_name = var.consumer_sp_application_id
  }

  task {
    task_key = "cross_workspace_query"

    notebook_task {
      notebook_path = databricks_notebook.consumer_demo.path
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
    databricks_secret.consumer_sp_client_id,
    databricks_secret.consumer_sp_client_secret,
  ]
}
