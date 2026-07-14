# Consumer Workspace: Cross-Workspace Vector Search Query Demo
#
# Runs in the CONSUMER workspace; queries a Vector Search index in the PRODUCER
# workspace. Both workspaces share a Unity Catalog metastore — the consumer SP
# has been granted CAN_USE on the VS endpoint and SELECT on the VS index.
#
# Authentication: OAuth M2M using the consumer SP's client_id + client_secret.
# WorkspaceClient(host=producer_url, client_id=..., client_secret=...) exchanges
# the SP credentials against the PRODUCER workspace token endpoint, returning a
# token that is workspace-scoped to the producer — unlike the cluster token which
# is scoped to the consumer workspace and rejected cross-workspace.

# ── Parameters (injected by the Terraform job; editable for interactive runs) ─
dbutils.widgets.text("producer_workspace_url", "")
dbutils.widgets.text("vs_index_name", "producer_catalog.vector_data.documents_vs_index")

PRODUCER_WORKSPACE_URL = dbutils.widgets.get("producer_workspace_url")
VS_INDEX_NAME          = dbutils.widgets.get("vs_index_name")

# ── Load M2M credentials from secret scope ────────────────────────────────────
# Secret scope "vs-share" and both secrets are created by Terraform (phase 3).
CLIENT_ID     = dbutils.secrets.get("vs-share", "consumer-sp-client-id")
CLIENT_SECRET = dbutils.secrets.get("vs-share", "consumer-sp-client-secret")

# ── Authenticate to the producer workspace via OAuth M2M ──────────────────────
# Passing client_id + client_secret overrides environment-based credential
# detection. The SDK requests a token from the PRODUCER workspace's token
# endpoint, so the resulting token is accepted by the producer VS service.
from databricks.sdk import WorkspaceClient

producer = WorkspaceClient(
    host=PRODUCER_WORKSPACE_URL,
    client_id=CLIENT_ID,
    client_secret=CLIENT_SECRET,
)

print(f"Authenticated as: {producer.current_user.me().user_name}")
print(f"Querying index:   {VS_INDEX_NAME}\n")

# ── Similarity queries ────────────────────────────────────────────────────────
import requests

queries = [
    "machine learning neural networks",
    "retrieval augmented generation RAG",
    "data governance access control",
]

auth_headers = {**producer.config.authenticate(), "Content-Type": "application/json"}

for query in queries:
    print(f"Query: '{query}'")
    print("-" * 60)
    resp = requests.post(
        f"{PRODUCER_WORKSPACE_URL}/api/2.0/vector-search/indexes/{VS_INDEX_NAME}/query",
        headers=auth_headers,
        json={"query_text": query, "num_results": 3, "columns": ["id", "title", "content"]},
    )
    resp.raise_for_status()
    for row in resp.json().get("result", {}).get("data_array", []):
        doc_id, title, content, score = row[0], row[1], row[2], row[-1]
        print(f"  [{score:.4f}] {title}")
        print(f"           {content[:80]}...")
    print()
