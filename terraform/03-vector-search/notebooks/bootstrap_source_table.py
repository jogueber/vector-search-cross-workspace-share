# Bootstrap: Create source Delta table for Vector Search
# This notebook runs once to initialize the producer catalog data.
# The table must exist before the Vector Search index can sync.

import sys

catalog = dbutils.widgets.get("bootstrap.catalog")
schema  = dbutils.widgets.get("bootstrap.schema")
table   = f"{catalog}.{schema}.documents"

print(f"Creating source table: {table}")

# Create the table with Change Data Feed enabled.
# CDF is required for DELTA_SYNC indexes on standard Vector Search endpoints.
spark.sql(f"""
  CREATE TABLE IF NOT EXISTS {table} (
    id      STRING NOT NULL,
    title   STRING NOT NULL,
    content STRING NOT NULL
  )
  USING DELTA
  TBLPROPERTIES (
    'delta.enableChangeDataFeed' = 'true'
  )
""")

sample_docs = [
    ("1",  "Introduction to Machine Learning",
     "Machine learning is a subset of artificial intelligence enabling computers to learn from data without explicit programming."),
    ("2",  "Deep Learning Fundamentals",
     "Deep learning uses multi-layer neural networks to progressively extract higher-level features from raw input data."),
    ("3",  "Natural Language Processing",
     "NLP enables computers to understand, interpret, and generate human language, powering chatbots and translation services."),
    ("4",  "Vector Databases Explained",
     "Vector databases store high-dimensional embeddings and enable semantic similarity search for AI-powered applications."),
    ("5",  "Retrieval Augmented Generation",
     "RAG combines document retrieval with language generation, grounding AI responses in specific knowledge bases to improve accuracy."),
    ("6",  "Databricks Lakehouse Architecture",
     "The Databricks Lakehouse unifies data warehousing and data lake capabilities on a Delta Lake foundation with ACID transactions."),
    ("7",  "Unity Catalog Data Governance",
     "Unity Catalog provides centralized governance, discovery, and access control for all data and AI assets across workspaces."),
    ("8",  "Spark Structured Streaming",
     "Spark Structured Streaming processes real-time data with end-to-end exactly-once fault tolerance and low latency."),
    ("9",  "MLflow Experiment Tracking",
     "MLflow tracks ML experiments, packages models for reproducibility, and manages the full machine learning lifecycle."),
    ("10", "Delta Lake ACID Transactions",
     "Delta Lake brings ACID transactions, scalable metadata handling, and time travel to large-scale data workloads."),
]

df = spark.createDataFrame(sample_docs, ["id", "title", "content"])
df.write.mode("append").saveAsTable(table)

count = spark.table(table).count()
print(f"Bootstrap complete. {table} contains {count} documents.")
print("Change Data Feed is enabled — the Vector Search index is ready to sync.")
