# vector-search-share

Reference implementation for the blog post *"Cross-Workspace Vector Search Sharing with Terraform"*, which walks through sharing a Databricks Mosaic AI Vector Search index across workspaces using OAuth M2M authentication and Unity Catalog grants.

## What's here

- **`terraform/`** — Three-phase OpenTofu/Terraform deployment:
  - `01-workspaces/` — Provisions producer and consumer Databricks workspaces on AWS.
  - `02-unity-catalog/` — Creates a shared Unity Catalog metastore and the consumer service principals.
  - `03-vector-search/` — Provisions the Vector Search endpoint and index, Unity Catalog grants, endpoint ACLs, and the demo notebooks/jobs.

Each phase's outputs feed into the next phase's variables — see the `next_steps` output at the end of each `tofu apply`.

## Prerequisites

- Two Databricks workspaces on a shared Unity Catalog metastore (AWS)
- [OpenTofu](https://opentofu.org/) or Terraform with the [Databricks provider](https://registry.terraform.io/providers/databricks/databricks/latest/docs)
- Databricks CLI authenticated with profiles for both workspaces

## Usage

```bash
cd terraform/01-workspaces && tofu init && tofu apply
# copy outputs into 02-unity-catalog/terraform.tfvars
cd ../02-unity-catalog && tofu init && tofu apply
# copy outputs into 03-vector-search/terraform.tfvars
cd ../03-vector-search && tofu init && tofu apply
```

`*.tfvars` files are gitignored — never commit account IDs, workspace URLs, or service principal secrets. All sensitive inputs are declared as Terraform variables (`sensitive = true`) and OAuth client secrets are generated manually in the Databricks account console, then stored in per-service-principal Databricks secret scopes managed by Terraform.


