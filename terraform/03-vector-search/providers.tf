# Producer workspace — hosts the Vector Search endpoint and index.
provider "databricks" {
  alias   = "workspace_producer"
  host    = var.producer_workspace_url
}

# Consumer workspace — runs demo notebooks that query the producer's VS index.
provider "databricks" {
  alias   = "workspace_consumer"
  host    = var.consumer_workspace_url
}
