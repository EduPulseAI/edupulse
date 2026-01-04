Using the existing EduPulse project context AND the applied changes from FLINK-REFACTOR.md (BigQuery removed, Flink added), update our deployment and infrastructure to match the new architecture.

IMPORTANT NOTES (NON-NEGOTIABLE):
- Kafka, Schema Registry, and Flink are fully managed by Confluent Cloud (no GCP resources for these).
- Do NOT provision Kafka, Schema Registry, or Flink on GCP.
- Remove BigQuery entirely from infra and docs.
- GCP is used for: Cloud Run, Artifact Registry, Secret Manager, IAM, (optional) VPC connector/egress, Vertex AI/Gemini access via IAM.

You must produce:
1) `docs/DEPLOYMENT.md`
2) `scripts/deploy_with_terraform.sh`
3) Terraform under `infra/` restructured with **production-grade naming conventions** and layout.
4) `infra/README.md`

--------------------------------------------
A) `docs/DEPLOYMENT.md` (Markdown)
--------------------------------------------
Include:
1) Deployment architecture summary
- Cloud Run services list (each Spring Boot service + optional Next.js)
- Confluent Cloud managed components (Kafka, Schema Registry, Flink)
- Connectivity: Cloud Run → Confluent bootstrap servers + Schema Registry URL (auth + TLS)
- Secrets: Secret Manager strategy (what secrets exist, who can access)
- Vertex AI/Gemini access: required APIs + IAM approach

2) Prerequisites
- Tools: gcloud, terraform, docker (if used), jq (optional)
- GCP setup: project, region, APIs to enable
- Confluent prerequisites: endpoints + API keys/secrets for Kafka and Schema Registry

3) Secrets & Config
- Table of all required secrets stored in Secret Manager:
    - KAFKA_BOOTSTRAP_SERVERS, KAFKA_API_KEY, KAFKA_API_SECRET
    - SCHEMA_REGISTRY_URL, SCHEMA_REGISTRY_API_KEY, SCHEMA_REGISTRY_API_SECRET
    - Any app secrets (JWT signing key, etc.)
- Table of non-secret env vars (service names, topic names, env, etc.)
- How Cloud Run services map secrets to env vars

4) Networking / Egress
- Explain default Cloud Run egress to Confluent Cloud
- Only include VPC connector if truly needed; justify when it’s required
- Note any allowlisting considerations if applicable

5) Confluent Flink Operations (No GCP)
- How Flink jobs are deployed in Confluent Cloud (SQL statements / pipelines)
- Where these definitions live in the repo (e.g., `infra/confluent/flink/`)
- How to validate Flink jobs and output topics

6) Step-by-step deployment flow
- Terraform apply (GCP only)
- Build & push images to Artifact Registry
- Deploy Cloud Run services
- Verify service health
- Verify Kafka + Schema Registry connectivity (smoke test)
- Deploy/enable Flink jobs in Confluent Cloud (documented process)
- End-to-end demo validation

7) Post-deploy validation checklist
- Cloud Run URLs reachable
- Kafka producer/consumer smoke test
- Schema Registry subjects + compatibility
- Flink job running and producing expected output topics
- Vertex AI + Gemini calls succeed
- UI real-time updates work

--------------------------------------------
B) `scripts/deploy_with_terraform.sh`
--------------------------------------------
Create a bash script that:
- Validates required env vars (project_id, region, env, image tags, Confluent secrets)
- Runs terraform fmt/init/validate/plan/apply using environment-specific tfvars
- Builds/pushes images to Artifact Registry (or calls a `scripts/build_and_push.sh`)
- Deploys Cloud Run services (choose terraform-managed or gcloud-managed; stick to one)
- Prints Cloud Run URLs and next steps
- Does NOT provision Confluent resources on GCP
- Includes optional steps to apply Confluent Flink SQL via CLI/API if feasible; otherwise prints clear manual steps pointing to docs and repo paths
- Is idempotent where possible, with clear logging/echo statements and safe exits

--------------------------------------------
C) Terraform (Production-grade structure under `infra/`)
--------------------------------------------
Requirement:
Use **production file/folder naming conventions**. Organize Terraform with:
- Environment separation (dev/stage/prod)
- Reusable modules
- Clear naming, minimal duplication
- Standard files: providers, versions, variables, outputs, locals
- A root module per environment that composes shared modules

Output the `infra/` directory tree first, then provide the full contents of each Terraform file with a header indicating its path.

Required `infra/` layout (example — you may refine, but keep production conventions):

infra/
README.md
modules/
artifact_registry/
main.tf
variables.tf
outputs.tf
cloud_run_service/
main.tf
variables.tf
outputs.tf
iam/
main.tf
variables.tf
outputs.tf
secret_manager/
main.tf
variables.tf
outputs.tf
vertex_ai/
main.tf
variables.tf
outputs.tf
networking/
main.tf
variables.tf
outputs.tf
envs/
dev/
backend.tf
providers.tf
versions.tf
variables.tf
terraform.tfvars
main.tf
outputs.tf
prod/
backend.tf
providers.tf
versions.tf
variables.tf
terraform.tfvars
main.tf
outputs.tf

Terraform scope (GCP only):
- Enable required APIs
- Artifact Registry
- Secret Manager secrets placeholders + IAM access to Cloud Run SA
- Service accounts + IAM roles for:
    - Cloud Run runtime
    - Vertex AI invocation
    - Secret Manager access
    - Artifact Registry pull
- Cloud Run services (one per backend, optional Next.js)
    - Env vars from Secret Manager
    - Autoscaling defaults
    - Liveness/readiness via health endpoints (document)
- Optional networking (only if needed for egress)
- Vertex AI related API enablement and IAM bindings

Explicitly remove:
- Any BigQuery resources, datasets, tables, sinks, IAM bindings

Confluent side:
- Do NOT implement Confluent Kafka/SR/Flink in Terraform (unless you are explicitly using official Confluent Terraform provider AND it is truly needed; otherwise keep Confluent provisioning documented only).

--------------------------------------------
Output formatting rules:
--------------------------------------------
- Provide `docs/DEPLOYMENT.md` and `scripts/deploy_with_terraform.sh` in full.
- Provide Terraform files in full, with their intended paths as headers.
- Terminal commands and scripts may use code blocks.
- Keep it realistic for a 48-hour hackathon (avoid over-engineering).
- Prefer clarity and working defaults.

Proceed to generate the files now.
