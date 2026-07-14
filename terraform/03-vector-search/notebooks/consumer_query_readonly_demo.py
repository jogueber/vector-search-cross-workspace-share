# Consumer Workspace: Cross-Workspace Vector Search Query Demo (SDK / Read-Only SP)
#
# Runs in the CONSUMER workspace; queries a Vector Search index in the PRODUCER
# workspace using the Databricks SDK's vector_search_indexes.query_index() API.
#
# Differences from consumer_query_demo.py:
#   - Uses SDK query_index() instead of raw REST requests.post()
#   - Uses the read-only SP's dedicated secret scope (vs-share-readonly)
#   - Demonstrates filtered and narrow queries in addition to basic similarity
#
# Authentication: OAuth M2M using the read-only consumer SP's credentials.
# Cross-workspace VS queries require explicit M2M OAuth — ambient credentials
# from run_as are workspace-scoped and cannot be exchanged automatically.

# ── Parameters (injected by the Terraform job; editable for interactive runs) ─
dbutils.widgets.text("producer_workspace_url", "")
dbutils.widgets.text("vs_index_name", "producer_catalog.vector_data.documents_vs_index")

PRODUCER_WORKSPACE_URL = dbutils.widgets.get("producer_workspace_url")
VS_INDEX_NAME          = dbutils.widgets.get("vs_index_name")

# ── Load M2M credentials from the read-only secret scope ────────────────────
# Secret scope "vs-share-readonly" and both secrets are created by Terraform (phase 3).
CLIENT_ID     = dbutils.secrets.get("vs-share-readonly", "consumer-sp-client-id")
CLIENT_SECRET = dbutils.secrets.get("vs-share-readonly", "consumer-sp-client-secret")

# ── Authenticate to the producer workspace via OAuth M2M ─────────────────────
from databricks.sdk import WorkspaceClient

producer = WorkspaceClient(
    host=PRODUCER_WORKSPACE_URL,
    client_id=CLIENT_ID,
    client_secret=CLIENT_SECRET,
)

print(f"Authenticated as: {producer.current_user.me().user_name}")
print(f"Querying index:   {VS_INDEX_NAME}\n")

# ── Query 1: Basic similarity search (top 5) ────────────────────────────────
print("Query 1: Basic similarity search (top 5)")
print("-" * 60)
results = producer.vector_search_indexes.query_index(
    index_name=VS_INDEX_NAME,
    query_text="machine learning neural networks",
    columns=["id", "title", "content"],
    num_results=5,
)
for row in results.result.data_array:
    doc_id, title, content, score = row[0], row[1], row[2], row[-1]
    print(f"  [{score:.4f}] {title}")
    print(f"           {content[:80]}...")
print()

# ── Query 2: Filtered search (exclude specific document by id) ───────────────
print("Query 2: Filtered similarity search (exclude id=1)")
print("-" * 60)
results = producer.vector_search_indexes.query_index(
    index_name=VS_INDEX_NAME,
    query_text="retrieval augmented generation RAG",
    columns=["id", "title", "content"],
    num_results=3,
    filters_json='{"id NOT": 1}',
)
for row in results.result.data_array:
    doc_id, title, content, score = row[0], row[1], row[2], row[-1]
    print(f"  [{score:.4f}] {title}")
    print(f"           {content[:80]}...")
print()

# ── Query 3: Narrow search (top 1 result only) ──────────────────────────────
print("Query 3: Narrow similarity search (top 1)")
print("-" * 60)
results = producer.vector_search_indexes.query_index(
    index_name=VS_INDEX_NAME,
    query_text="data governance access control",
    columns=["id", "title", "content"],
    num_results=1,
)
for row in results.result.data_array:
    doc_id, title, content, score = row[0], row[1], row[2], row[-1]
    print(f"  [{score:.4f}] {title}")
    print(f"           {content[:80]}...")
print()
