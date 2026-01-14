# EduPulse Dev Environment

This directory contains Terraform configuration for the EduPulse development environment on Google Cloud Platform.

## Quick Start

### Prerequisites

1. **GCP Project**: `edupulse-483220`
2. **Terraform**: v1.0+ ([Install](https://developer.hashicorp.com/terraform/downloads))
3. **gcloud CLI**: Authenticated and configured ([Install](https://cloud.google.com/sdk/docs/install))
4. **Environment File**: `.env` file in project root with secrets

### Initial Setup

```bash
# 1. Authenticate with GCP
gcloud auth login
gcloud config set project edupulse-483220

# 2. Configure application default credentials (for Terraform)
gcloud auth application-default login

# 3. Create and configure your .env file
cd ../../..  # Go to project root
cp .env.example .env
# Edit .env with your actual credentials

# 4. Return to dev environment directory
cd infra/envs/dev

# 5. Initialize Terraform
terraform init

# 6. Review the plan
terraform plan -out=tfplan

# 7. Apply the configuration
terraform apply tfplan
```

### What Gets Deployed

The Terraform configuration creates:

1. **Artifact Registry**: Container image repository (`us-central1-docker.pkg.dev/edupulse-483220/edupulse`)
2. **Secret Manager**: All application secrets (Kafka, database, API keys)
3. **IAM Service Accounts**: One per microservice with appropriate permissions
4. **Cloud Run Services**: Deployed microservices (currently: quiz-service)
5. **Vertex AI Configuration**: APIs and IAM for AI-powered features

### Secrets Configuration

After deploying infrastructure with Terraform, secrets must be populated manually. For detailed information about secrets setup, see:

**[SECRETS.md](./SECRETS.md)** - Complete guide to secrets configuration

To populate or update secrets:
```bash
# From project root
scripts/gcloud/set-secrets.sh edupulse-483220
```

## Configuration Files

| File | Purpose |
|------|---------|
| `main.tf` | Main infrastructure configuration |
| `variables.tf` | Input variable definitions |
| `terraform.tfvars` | Variable values for dev environment |
| `outputs.tf` | Output values (URLs, service accounts, etc.) |
| `providers.tf` | GCP provider configuration |
| `versions.tf` | Terraform and provider version constraints |
| `backend.tf` | Remote state configuration (GCS bucket) |
| `SECRETS.md` | Complete guide to secrets configuration |

## Managing Services

### Enable/Disable Services

Edit `terraform.tfvars` to add or remove services:

```hcl
services = {
  quiz-service = {
    image_name    = "quiz-service"
    image_tag     = "latest"
    # ... configuration
  }

  # Uncomment to enable additional services:
  # bandit-engine = { ... }
  # tip-service = { ... }
  # realtime-gateway = { ... }
}
```

### Update Service Configuration

1. Modify service settings in `terraform.tfvars`
2. Plan and apply changes:
   ```bash
   terraform plan -out=tfplan
   terraform apply tfplan
   ```

## Common Operations

### View Deployed Resources

```bash
# List all resources
terraform state list

# Show Cloud Run service URLs
terraform output service_urls

# Show service account emails
terraform output service_account_emails
```

### Update Secrets

```bash
# Update values in .env file
vim .env

# Re-run secrets script (from project root)
scripts/gcloud/set-secrets.sh edupulse-483220
```

### Destroy Environment

**Warning**: This will delete all resources in the dev environment.

```bash
# Review what will be destroyed
terraform plan -destroy

# Destroy all resources
terraform destroy
```

### View Logs

```bash
# Cloud Run service logs
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=quiz-service" \
  --project=edupulse-483220 \
  --limit=50

# Terraform state changes
terraform show
```

## Terraform Modules

This configuration uses custom modules from `../../modules/`:

- **artifact_registry**: Container image repository
- **secret_manager**: GCP Secret Manager secrets
- **iam**: Service accounts and IAM bindings
- **vertex_ai**: Vertex AI APIs and permissions
- **cloud_run_service**: Cloud Run service deployment

## Environment Variables

The configuration expects these variables in `terraform.tfvars`:

### Required
- `project_id`: GCP project ID
- `region`: GCP region (e.g., us-central1)
- `environment`: Environment name (dev)
- `services`: Map of services to deploy
- `secrets`: List of secrets to create

### Optional
- `enable_vertex_ai`: Enable Vertex AI (default: true)
- `enable_vpc_connector`: Enable VPC connector (default: false)
- `allow_unauthenticated`: Allow public access (default: true for dev)

## Outputs

After `terraform apply`, useful outputs are displayed:

```hcl
# Cloud Run service URLs
service_urls = {
  quiz-service = "https://quiz-service-xxxxx-uc.a.run.app"
}

# Service account emails
service_account_emails = {
  quiz-service = "quiz-service-sa@edupulse-483220.iam.gserviceaccount.com"
}

# Artifact Registry repository
artifact_registry_repository = "us-central1-docker.pkg.dev/edupulse-483220/edupulse"
```

## Troubleshooting

### Error: "Backend configuration changed"

```bash
terraform init -reconfigure
```

### Error: "Secret not found"

Ensure Terraform has created secrets first:
```bash
terraform apply -target=module.secret_manager
```

Then run the secrets script:
```bash
scripts/gcloud/set-secrets.sh edupulse-483220
```

### Error: "Permission denied"

Check your IAM permissions:
```bash
gcloud projects get-iam-policy edupulse-483220 --flatten="bindings[].members" \
  --filter="bindings.members:user:$(gcloud config get-value account)"
```

You need these roles:
- `roles/owner` or `roles/editor` (for creating resources)
- `roles/secretmanager.admin` (for managing secrets)

### Cloud Run deployment fails

Check container image exists in Artifact Registry:
```bash
gcloud artifacts docker images list us-central1-docker.pkg.dev/edupulse-483220/edupulse \
  --project=edupulse-483220
```

## Remote State

Terraform state is stored in a GCS bucket (configured in `backend.tf`). This allows team collaboration and state locking.

**Important**: Never commit `terraform.tfstate` files to version control.

## CI/CD Integration

For automated deployments, use a service account with these roles:
- `roles/editor`
- `roles/secretmanager.admin`
- `roles/iam.serviceAccountAdmin`

Example GitHub Actions workflow:
```yaml
- name: Terraform Apply
  run: |
    cd infra/envs/dev
    terraform init
    terraform apply -auto-approve
  env:
    GOOGLE_CREDENTIALS: ${{ secrets.GCP_SA_KEY }}
```

## Additional Resources

- [Terraform GCP Provider Docs](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [GCP Secret Manager](https://cloud.google.com/secret-manager/docs)
- [Project README](../../README.md)
- [Backend Service Documentation](../../backend/README.md)
