# EduPulse Deployment Guide

Complete deployment guide for the EduPulse real-time adaptive learning platform on Google Cloud Platform with Confluent Cloud.

---

## Table of Contents

1. [Deployment Architecture](#deployment-architecture)
2. [Prerequisites](#prerequisites)
3. [Secrets & Configuration](#secrets--configuration)
4. [Networking & Connectivity](#networking--connectivity)
5. [Confluent Flink Operations](#confluent-flink-operations)
6. [Deployment Methods](#deployment-methods)
   - [Method 1: Automated Script Deployment](#method-1-automated-script-deployment-recommended)
   - [Method 2: Manual Terraform Deployment](#method-2-manual-terraform-deployment)
   - [Method 3: Per-Module Terraform Deployment](#method-3-per-module-terraform-deployment)
   - [Method 4: Per-Service Deployment](#method-4-per-service-deployment)
7. [Post-Deployment Validation](#post-deployment-validation)
8. [Troubleshooting](#troubleshooting)
9. [Rollback & Updates](#rollback--updates)

---

## Deployment Architecture

### Architecture Summary

EduPulse uses a **fully event-driven architecture** with managed services and strict separation of concerns:

**Key Principle**: Flink does ALL real-time computation. Realtime Gateway does ONLY fan-out and SSE delivery.

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Google Cloud Platform                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │  Cloud Run Services (Microservices)                         │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │    │
│  │  │ Event Ingest │  │   Quizzer    │  │    Bandit    │      │    │
│  │  │   Service    │  │   Service    │  │    Engine    │      │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │    │
│  │  │ Tip Service  │  │   Content    │  │  Realtime    │      │    │
│  │  │              │  │   Adapter    │  │   Gateway    │      │    │
│  │  └──────────────┘  └──────────────┘  └──────────────┘      │    │
│  └─────────────────────────────────────────────────────────────┘    │
│           │                    │                    │                │
│           │                    │                    │                │
│  ┌────────▼────────┐  ┌────────▼────────┐  ┌───────▼──────┐        │
│  │ Artifact        │  │ Secret          │  │  Vertex AI   │        │
│  │ Registry        │  │ Manager         │  │  (Bandit)    │        │
│  └─────────────────┘  └─────────────────┘  └──────────────┘        │
│  ┌─────────────────────────────────────────────────────────┐        │
│  │ Memorystore (Redis) - SSE routing maps                  │        │
│  └─────────────────────────────────────────────────────────┘        │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
                                 │
                                 │ HTTPS + TLS + API Keys
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         Confluent Cloud                              │
├─────────────────────────────────────────────────────────────────────┤
│  ┌───────────────┐  ┌───────────────┐  ┌──────────────────┐        │
│  │ Kafka Cluster │  │ Schema        │  │ Confluent Flink  │        │
│  │ Raw + Derived │  │ Registry      │  │ (ALL Compute)    │        │
│  │ Topics        │  │ (Avro)        │  │ Stream Proc.     │        │
│  └───────────────┘  └───────────────┘  └──────────────────┘        │
│                                                                       │
│  Event Flow:                                                         │
│  Raw Events → Flink (compute) → Derived Topics → Realtime Gateway   │
└─────────────────────────────────────────────────────────────────────┘
```

### Cloud Run Services

| Service | Purpose | Port | Ingress | Resources | Special Features |
|---------|---------|------|---------|-----------|------------------|
| **event-ingest-service** | HTTP API for quiz events → Kafka | 8080 | Public | 1 CPU, 512Mi | Entry point for all events |
| **quizzer** | Quiz content management | 8080 | Public | 1 CPU, 512Mi | PostgreSQL integration |
| **bandit-engine** | Multi-armed bandit difficulty adaptation | 8080 | Internal | 2 CPU, 1Gi | Vertex AI integration |
| **tip-service** | AI-powered hint generation via Gemini | 8080 | Internal | 1 CPU, 512Mi | Gemini API integration |
| **content-adapter** | Dynamic content difficulty adjustment | 8080 | Internal | 500m CPU, 256Mi | Lightweight processor |
| **sse-service** | SSE gateway for real-time updates (Kafka → SSE fan-out ONLY, NO computation) | 8080 | Public | 1 CPU, 512Mi | Redis-backed routing, min 1 instance |

### Confluent Cloud Managed Components

**Critical**: Kafka, Schema Registry, and Flink are **fully managed by Confluent Cloud**. They are **NOT provisioned on GCP**.

- **Kafka Cluster**: Event streaming backbone (raw + derived topics)
- **Schema Registry**: Avro schema management and compatibility enforcement
- **Confluent Flink**: **ALL** real-time stream processing, analytics, and aggregations
  - Windowed metrics (tumbling, sliding, session windows)
  - Stream joins (enrichment, temporal joins)
  - Pattern detection (Complex Event Processing)
  - Produces derived topics consumed by SSE Service and microservices

### GCP Resources Managed by Terraform

- **Artifact Registry**: Container image storage
- **Secret Manager**: Credentials for Kafka, Schema Registry, Gemini API, PostgreSQL
- **Cloud Run**: Serverless container execution
- **Service Accounts**: Per-service IAM isolation (least privilege)
- **IAM Bindings**: Secret access, Vertex AI permissions
- **API Enablement**: Cloud Run, Artifact Registry, Secret Manager, Vertex AI, Gemini

---

## Prerequisites

### Required Tools

Install the following tools on your local machine:

```bash
# Google Cloud SDK
# Install: https://cloud.google.com/sdk/docs/install
gcloud --version  # Should be >= 450.0.0

# Terraform
# Install: https://developer.hashicorp.com/terraform/downloads
terraform --version  # Should be >= 1.6.0

# Docker (for building images)
# Install: https://docs.docker.com/get-docker/
docker --version

# jq (optional, for JSON parsing)
sudo apt-get install jq  # Ubuntu/Debian
brew install jq          # macOS
```

### GCP Project Setup

1. **Create or select a GCP project**:
   ```bash
   export PROJECT_ID="edupulse-483220"  # Replace with your project ID
   gcloud config set project $PROJECT_ID
   ```

2. **Enable billing** (required for Cloud Run, Artifact Registry):
   ```bash
   # Verify billing is enabled
   gcloud billing accounts list
   gcloud billing projects describe $PROJECT_ID
   ```

3. **Set default region**:
   ```bash
   export REGION="us-central1"
   gcloud config set compute/region $REGION
   ```

4. **Enable required GCP APIs** (Terraform will also enable these):
   ```bash
   gcloud services enable \
     run.googleapis.com \
     artifactregistry.googleapis.com \
     secretmanager.googleapis.com \
     cloudresourcemanager.googleapis.com \
     iam.googleapis.com \
     compute.googleapis.com \
     aiplatform.googleapis.com \
     generativelanguage.googleapis.com
   ```

5. **Authenticate gcloud**:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

6. **Create Terraform state bucket** (for remote state):
   ```bash
   gsutil mb -p $PROJECT_ID -l $REGION gs://${PROJECT_ID}-terraform-state-dev
   gsutil versioning set on gs://${PROJECT_ID}-terraform-state-dev
   ```

   Then update `infra/envs/dev/backend.tf`:
   ```hcl
   bucket = "<YOUR_PROJECT_ID>-terraform-state-dev"
   ```

### Confluent Cloud Prerequisites

You must have a Confluent Cloud account with:

1. **Kafka Cluster** created (Basic or Standard tier recommended)
2. **API Key and Secret** for Kafka authentication
3. **Schema Registry** enabled in the same cloud/region as Kafka
4. **Schema Registry API Key and Secret**
5. **Flink Compute Pool** (optional, for stream processing)

**Get Confluent Cloud Credentials**:

```bash
# Log in to Confluent Cloud
confluent login

# Get Kafka bootstrap servers
confluent kafka cluster describe <CLUSTER_ID>

# Create API key for Kafka
confluent api-key create --resource <CLUSTER_ID>

# Get Schema Registry endpoint
confluent schema-registry cluster describe

# Create API key for Schema Registry
confluent api-key create --resource <SR_CLUSTER_ID>
```

**Note down**:
- Kafka bootstrap servers (e.g., `pkc-xxxxx.us-east-1.aws.confluent.cloud:9092`)
- Kafka API Key and Secret
- Schema Registry URL (e.g., `https://psrc-xxxxx.us-east-1.aws.confluent.cloud`)
- Schema Registry API Key and Secret

### Gemini API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Create an API key for Gemini
3. Save the API key securely

### PostgreSQL Database (Optional for Local Dev)

For production, quizzer service can use:
- **Cloud SQL** (recommended for production)
- **External PostgreSQL** (self-managed)

For dev, the local Docker Compose PostgreSQL is sufficient.

---

## Secrets & Configuration

### Secret Manager Secrets

All secrets are stored in **Google Secret Manager** and mounted as environment variables to Cloud Run services.

#### Required Secrets Table

| Secret Name                  | Description                        | Used By                     | Example Value                                      |
|------------------------------|------------------------------------|-----------------------------|----------------------------------------------------|
| `kafka-bootstrap-servers`    | Confluent Kafka bootstrap endpoint | All services except quizzer | `pkc-xxxxx.us-east-1.aws.confluent.cloud:9092`     |
| `kafka-api-key`              | Kafka SASL API key                 | All services except quizzer | `ABCDEFGHIJ123456`                                 |
| `kafka-api-secret`           | Kafka SASL API secret              | All services except quizzer | `xyz123...secretvalue`                             |
| `schema-registry-url`        | Confluent Schema Registry endpoint | All services except quizzer | `https://psrc-xxxxx.us-east-1.aws.confluent.cloud` |
| `schema-registry-api-key`    | Schema Registry API key            | All services except quizzer | `SR_API_KEY_123`                                   |
| `schema-registry-api-secret` | Schema Registry API secret         | All services except quizzer | `sr_secret_xyz...`                                 |
| `gemini-api-key`             | Google Gemini API key              | tip-service                 | `AIzaSyC...`                                       |
| `jwt-signing-key`            | JWT token signing key for sessions | event-ingest-service        | `base64-encoded-random-string`                     |
| `postgres-user`              | PostgreSQL username                | quizzer                     | `edupulse`                                         |
| `postgres-password`          | PostgreSQL password                | quizzer                     | `securepassword123`                                |
| `postgres-database`          | PostgreSQL database name           | quizzer                     | `edupulse`                                         |

#### Set Secrets via gcloud CLI

**One-time setup** (after Terraform creates secret placeholders):

```bash
# Confluent Kafka credentials
echo -n "pkc-xxxxx.us-east-1.aws.confluent.cloud:9092" | \
  gcloud secrets versions add kafka-bootstrap-servers --data-file=-

echo -n "YOUR_KAFKA_API_KEY" | \
  gcloud secrets versions add kafka-api-key --data-file=-

echo -n "YOUR_KAFKA_API_SECRET" | \
  gcloud secrets versions add kafka-api-secret --data-file=-

# Confluent Schema Registry credentials
echo -n "https://psrc-xxxxx.us-east-1.aws.confluent.cloud" | \
  gcloud secrets versions add schema-registry-url --data-file=-

echo -n "YOUR_SR_API_KEY" | \
  gcloud secrets versions add schema-registry-api-key --data-file=-

echo -n "YOUR_SR_API_SECRET" | \
  gcloud secrets versions add schema-registry-api-secret --data-file=-

# Gemini API key
echo -n "YOUR_GEMINI_API_KEY" | \
  gcloud secrets versions add gemini-api-key --data-file=-

# PostgreSQL credentials (for quizzer service)
echo -n "edupulse" | \
  gcloud secrets versions add postgres-user --data-file=-

echo -n "$(openssl rand -base64 24)" | \
  gcloud secrets versions add postgres-password --data-file=-

echo -n "edupulse" | \
  gcloud secrets versions add postgres-database --data-file=-

# JWT signing key (random secure key)
echo -n "$(openssl rand -base64 32)" | \
  gcloud secrets versions add jwt-signing-key --data-file=-
```

**Verify secrets**:
```bash
gcloud secrets list
gcloud secrets versions access latest --secret=kafka-bootstrap-servers
```

### Non-Secret Environment Variables

These are set in `terraform.tfvars` and passed to Cloud Run services:

| Variable                 | Purpose                               | Example Value              |
|--------------------------|---------------------------------------|----------------------------|
| `SPRING_PROFILES_ACTIVE` | Spring Boot profile                   | `dev` or `prod`            |
| `SERVER_PORT`            | Container port                        | `8080`                     |
| `LOGGING_LEVEL_ROOT`     | Log level                             | `INFO` or `DEBUG`          |
| `VERTEX_AI_PROJECT`      | GCP project for Vertex AI             | `edupulse-483220`          |
| `VERTEX_AI_REGION`       | Vertex AI region                      | `us-central1`              |
| `VERTEX_AI_ENDPOINT_ID`  | Vertex AI model endpoint ID           | `1234567890` (if deployed) |
| `GEMINI_MODEL`           | Gemini model name                     | `gemini-2.0-flash-exp`     |
| `REDIS_HOST`             | Redis host for SSE routing maps       | `10.x.x.x` (Memorystore)   |
| `REDIS_PORT`             | Redis port                            | `6379`                     |

---

## Networking & Connectivity

### Cloud Run → Confluent Cloud Connectivity

- **Protocol**: HTTPS with TLS 1.2+ (Kafka SASL_SSL)
- **Authentication**: SASL/PLAIN with API key/secret
- **Egress**: Cloud Run uses **default internet egress** (no VPC connector needed)
- **Endpoints**: Public Confluent Cloud endpoints with TLS encryption

**No VPC Connector Required**: Confluent Cloud provides public endpoints with enterprise-grade security. Cloud Run can connect directly without private networking.

### Ingress Configuration

| Service              | Ingress Setting | Access                                   |
|----------------------|-----------------|------------------------------------------|
| event-ingest-service | `all`           | Public internet (frontend calls)         |
| quizzer              | `all`           | Public internet (quiz content API)       |
| sse-service          | `all`           | Public internet (SSE connections)        |
| bandit-engine        | `internal`      | Internal only (called by other services) |
| tip-service          | `internal`      | Internal only (called by other services) |
| content-adapter      | `internal`      | Internal only (called by other services) |

### Firewall & Allowlisting

- **Cloud Run outbound**: No restrictions, can connect to any public endpoint
- **Confluent Cloud**: No IP allowlisting required (uses API key authentication)
- **If using Confluent Cloud IP allowlisting**: Add Cloud Run NAT IPs (not recommended for hackathon)

---

## Confluent Flink Operations

Flink jobs run **in Confluent Cloud**, not on GCP. They are managed via Confluent Cloud Console or CLI.

**Critical Responsibility**: Flink performs **ALL** real-time computation for EduPulse. The Realtime Gateway service does **NO** stream processing—it only fans out Flink's derived topics to SSE clients.

### Real-Time Pipeline

```
Frontend → Event Ingest Service → Kafka Raw Topics
  → Flink (compute, joins, windowing) → Kafka Derived Topics
  → Realtime Gateway (fan-out only) → Next.js (SSE)
```

### Derived Topics Produced by Flink

Flink jobs produce derived topics that are consumed by the Realtime Gateway and other microservices:

| Topic Name | Produced By | Key | Purpose | Consumed By |
|------------|-------------|-----|---------|-------------|
| `engagement.scores` | Flink Engagement Analytics Job | `studentId` | Real-time engagement metrics per student | Realtime Gateway, Bandit Engine |
| `decision.context` | Flink Engagement Analytics Job | `sessionId` | Enriched context for AI decision-making | Bandit Engine, Tip Service |
| `cohort.heatmap` | Flink Instructor Metrics Job | `cohortId` | Aggregated cohort performance heatmap data | Realtime Gateway |
| `instructor.tips` | Flink Instructor Metrics Job | `cohortId` or `studentId` | Coaching suggestions for instructors | Realtime Gateway |

**Note**: `adapt.actions` is produced by Bandit Engine (not Flink), which consumes `decision.context`.

### Flink SQL Statements Location

Store Flink SQL definitions in the repository:

```
infra/confluent/flink/
├── engagement_aggregation.sql    # Real-time engagement scoring, produces engagement.scores
├── decision_context.sql          # Enriched decision context, produces decision.context
├── instructor_metrics.sql        # Cohort aggregates and tips, produces cohort.heatmap + instructor.tips
└── README.md                     # Deployment instructions
```

### Deploying Flink Jobs

**Manual Deployment** (Confluent Cloud Console):

1. Log in to [Confluent Cloud Console](https://confluent.cloud/)
2. Navigate to **Flink** → **SQL Workspaces**
3. Create a new Flink Compute Pool (if not exists)
4. Copy-paste SQL statements from `infra/confluent/flink/*.sql`
5. Execute statements to create Flink tables and streaming queries
6. Monitor Flink job status

**Automated Deployment** (Confluent CLI):

```bash
# Install Confluent CLI
curl -sL --http1.1 https://cnfl.io/cli | sh -s -- latest

# Login
confluent login

# Set environment and cluster
confluent environment use <ENV_ID>
confluent kafka cluster use <CLUSTER_ID>

# Deploy Flink SQL (example)
confluent flink statement create \
  --sql "$(cat infra/confluent/flink/engagement_aggregation.sql)" \
  --compute-pool <POOL_ID>
```

### Validating Flink Jobs

```bash
# List running Flink statements
confluent flink statement list

# Describe a statement
confluent flink statement describe <STATEMENT_ID>

# Check output topics
confluent kafka topic list
confluent kafka topic consume engagement.scores --from-beginning
```

### Flink Job Data Flow

| Flink Job | Input Topics | Output Topics | Computation |
|-----------|-------------|---------------|-------------|
| Engagement Analytics Job | `quiz.answers`, `session.events` | `engagement.scores`, `decision.context` | 60-sec tumbling windows, pattern detection, enrichment joins |
| Instructor Metrics Job | `engagement.scores`, `quiz.answers` | `cohort.heatmap`, `instructor.tips` | 5-min sliding windows, cohort aggregates, skill-level analysis |

**Note**: `adapt.actions` is produced by the **Bandit Engine microservice** (not Flink), which consumes `decision.context` from Flink.

---

## Deployment Methods

Choose one of the following deployment methods based on your needs.

---

## Method 1: Automated Script Deployment (Recommended)

**Best for**: Full end-to-end deployment with minimal manual steps.

### Using `scripts/deploy_with_terraform.sh`

The deployment script automates:
- Terraform initialization and validation
- Infrastructure provisioning (Artifact Registry, Secret Manager, IAM, Cloud Run)
- Container image building and pushing (optional)
- Secret validation
- Service health checks

### Script Usage

```bash
# Navigate to scripts directory
cd scripts

# Make script executable
chmod +x deploy_with_terraform.sh

# Run deployment
./deploy_with_terraform.sh --env dev --project-id edupulse-483220 --region us-central1
```

### Script Options

```bash
./deploy_with_terraform.sh \
  --env dev|prod \                    # Environment (required)
  --project-id PROJECT_ID \           # GCP project ID (required)
  --region REGION \                   # GCP region (optional, default: us-central1)
  --build-images \                    # Build and push container images
  --skip-terraform \                  # Skip Terraform apply (images only)
  --auto-approve \                    # Skip Terraform approval prompt
  --destroy                           # Destroy infrastructure
```

### Example: Full Deployment

```bash
# Full deployment with image builds
./deploy_with_terraform.sh \
  --env dev \
  --project-id edupulse-483220 \
  --region us-central1 \
  --build-images \
  --auto-approve
```

### Example: Terraform Only (Images Already Built)

```bash
# Deploy infrastructure only
./deploy_with_terraform.sh \
  --env dev \
  --project-id edupulse-483220
```

### Script Output

The script prints:
- Terraform plan summary
- Image build progress
- Cloud Run service URLs
- Next steps (secret setup, Flink deployment)

---

## Method 2: Manual Terraform Deployment

**Best for**: Understanding Terraform resources, manual control.

### Step 1: Configure Terraform Backend

Edit `infra/envs/dev/backend.tf` and replace placeholder:

```hcl
terraform {
  backend "gcs" {
    bucket = "edupulse-483220-terraform-state-dev"  # Replace with your project ID
    prefix = "edupulse/dev"
  }
}
```

### Step 2: Configure Variables

Edit `infra/envs/dev/terraform.tfvars` (or copy and customize):

```hcl
project_id  = "edupulse-483220"       # Your GCP project ID
region      = "us-central1"           # Your GCP region
environment = "dev"                   # Environment name

# Ensure service configurations match your needs
# Default values are production-ready
```

### Step 3: Initialize Terraform

```bash
cd infra/envs/dev

# Initialize Terraform (downloads providers, configures backend)
terraform init
```

### Step 4: Validate Configuration

```bash
# Format Terraform files
terraform fmt -recursive

# Validate configuration
terraform validate
```

### Step 5: Plan Deployment

```bash
# Preview changes
terraform plan -out=tfplan

# Review the plan carefully
# Should create ~50-70 resources:
# - 1 Artifact Registry repository
# - 11 Secret Manager secrets
# - 6 Service Accounts
# - ~30 IAM bindings
# - 6 Cloud Run services
# - API enablements
```

### Step 6: Apply Terraform

```bash
# Apply changes
terraform apply tfplan

# Or apply directly (with approval prompt)
terraform apply
```

**Expected Output**:
```
Apply complete! Resources: 67 added, 0 changed, 0 destroyed.

Outputs:

artifact_registry_repository_url = "us-central1-docker.pkg.dev/edupulse-483220/edupulse"
cloud_run_service_urls = {
  "bandit-engine" = "https://bandit-engine-xyz-uc.a.run.app"
  "content-adapter" = "https://content-adapter-xyz-uc.a.run.app"
  "event-ingest-service" = "https://event-ingest-service-xyz-uc.a.run.app"
  ...
}
```

### Step 7: Set Secrets

See [Secrets & Configuration](#set-secrets-via-gcloud-cli) section above.

### Step 8: Build and Push Images

```bash
# Authenticate Docker
gcloud auth configure-docker us-central1-docker.pkg.dev

# Build and push each service
cd ../../../backend/event-ingest-service
docker build -t us-central1-docker.pkg.dev/edupulse-483220/edupulse/event-ingest-service:latest .
docker push us-central1-docker.pkg.dev/edupulse-483220/edupulse/event-ingest-service:latest

# Repeat for other services
cd ../quizzer
docker build -t us-central1-docker.pkg.dev/edupulse-483220/edupulse/quizzer:latest .
docker push us-central1-docker.pkg.dev/edupulse-483220/edupulse/quizzer:latest

# ... and so on
```

### Step 9: Update Cloud Run with New Images

```bash
# Trigger a new revision deploy (Terraform will detect image changes)
terraform apply

# Or manually update a service
gcloud run services update event-ingest-service \
  --image us-central1-docker.pkg.dev/edupulse-483220/edupulse/event-ingest-service:latest \
  --region us-central1
```

---

## Method 3: Per-Module Terraform Deployment

**Best for**: Testing individual modules, modular updates.

### Deploy Artifact Registry Only

```bash
cd infra/envs/dev

# Target only artifact registry module
terraform apply -target=module.artifact_registry
```

### Deploy Secret Manager Only

```bash
terraform apply -target=module.secret_manager
```

### Deploy IAM (Service Accounts) Only

```bash
terraform apply -target=module.iam
```

### Deploy Cloud Run Services Only

```bash
# Deploy all Cloud Run services
terraform apply -target=module.cloud_run_services

# Deploy a specific service
terraform apply -target='module.cloud_run_services["event-ingest-service"]'
```

### Useful for Iterative Development

```bash
# Update and redeploy just one service
terraform apply -target='module.cloud_run_services["bandit-engine"]'
```

---

## Method 4: Per-Service Deployment

**Best for**: Rapid iteration on a single service, debugging.

### Deploy Single Service with gcloud

**Build and deploy in one command**:

```bash
cd backend/event-ingest-service

gcloud run deploy event-ingest-service \
  --source . \
  --region us-central1 \
  --project edupulse-483220 \
  --service-account event-ingest-service-sa@edupulse-483220.iam.gserviceaccount.com \
  --set-env-vars "SPRING_PROFILES_ACTIVE=dev,SERVER_PORT=8080" \
  --set-secrets "KAFKA_BOOTSTRAP_SERVERS=kafka-bootstrap-servers:latest,KAFKA_API_KEY=kafka-api-key:latest" \
  --cpu 1 \
  --memory 512Mi \
  --min-instances 0 \
  --max-instances 10 \
  --allow-unauthenticated
```

### Deploy from Pre-Built Image

```bash
gcloud run deploy event-ingest-service \
  --image us-central1-docker.pkg.dev/edupulse-483220/edupulse/event-ingest-service:latest \
  --region us-central1 \
  --project edupulse-483220 \
  --service-account event-ingest-service-sa@edupulse-483220.iam.gserviceaccount.com \
  --allow-unauthenticated
```

### Update Environment Variables Only

```bash
gcloud run services update event-ingest-service \
  --region us-central1 \
  --update-env-vars "LOGGING_LEVEL_ROOT=DEBUG"
```

### Update Secrets Only

```bash
gcloud run services update event-ingest-service \
  --region us-central1 \
  --update-secrets "KAFKA_API_SECRET=kafka-api-secret:latest"
```

---

## Post-Deployment Validation

### Validation Checklist

#### 1. Cloud Run Services Reachable

```bash
# List all services
gcloud run services list --region us-central1

# Get service URLs
terraform output cloud_run_service_urls

# Test public endpoints
curl https://event-ingest-service-xyz-uc.a.run.app/actuator/health
curl https://quizzer-xyz-uc.a.run.app/actuator/health
curl https://sse-service-xyz-uc.a.run.app/actuator/health
```

**Expected**: HTTP 200 with `{"status":"UP"}`

#### 2. Kafka Producer/Consumer Smoke Test

**Test event ingestion**:

```bash
# Submit a test quiz answer
curl -X POST https://event-ingest-service-xyz-uc.a.run.app/api/quiz/answer \
  -H "Content-Type: application/json" \
  -d '{
    "studentId": "test-student-123",
    "questionId": "q1",
    "answer": "A",
    "isCorrect": true,
    "timeSpent": 15000
  }'
```

**Verify in Confluent Cloud**:

```bash
# Check topic has messages
confluent kafka topic consume quiz.answers --from-beginning

# Should see the test message
```

#### 3. Schema Registry Subjects & Compatibility

```bash
# List registered schemas
curl -u <SR_API_KEY>:<SR_API_SECRET> \
  https://psrc-xxxxx.us-east-1.aws.confluent.cloud/subjects

# Expected subjects:
# - quiz.answers-value
# - session.events-value
# - engagement.scores-value
# - adapt.actions-value
# - instructor.tips-value
```

#### 4. Flink Jobs Running

```bash
# List Flink statements
confluent flink statement list

# Check statement status
confluent flink statement describe <STATEMENT_ID>
```

**Expected**: All Flink jobs in `RUNNING` state.

**Verify output topics**:

```bash
confluent kafka topic consume engagement.scores --from-beginning
confluent kafka topic consume adapt.actions --from-beginning
```

#### 5. Vertex AI + Gemini Calls Succeed

**Test bandit-engine** (requires internal service invocation):

```bash
# Get bandit-engine URL
BANDIT_URL=$(gcloud run services describe bandit-engine --region us-central1 --format='value(status.url)')

# Invoke with authenticated request
curl -H "Authorization: Bearer $(gcloud auth print-identity-token)" \
  $BANDIT_URL/actuator/health
```

**Test tip-service Gemini integration**:

```bash
# Check logs for Gemini API calls
gcloud run services logs read tip-service --region us-central1 --limit 50
```

#### 6. UI Real-Time Updates Work (SSE)

**Test SSE connection**:

```bash
# Get sse-service URL
GATEWAY_URL=$(gcloud run services describe sse-service --region us-central1 --format='value(status.url)')

# Test SSE endpoint
curl -N -H "Accept: text/event-stream" $GATEWAY_URL/sse/student/test-student-123

# Or use JavaScript EventSource (in browser console or Node.js)
# const es = new EventSource('https://<gateway-url>/sse/student/alice');
# es.addEventListener('engagement', (e) => console.log(e.data));
```

**Send test event via Event Ingest Service and verify SSE receives it**:

```bash
# Submit a test quiz answer
curl -X POST $EVENT_INGEST_URL/api/quiz/answer \
  -H "Content-Type: application/json" \
  -d '{
    "studentId": "test-student-123",
    "questionId": "q1",
    "answer": "A",
    "isCorrect": false,
    "timeSpent": 15000
  }'

# Check if SSE connection receives engagement.scores event (within ~1 second)
```

---

## Troubleshooting

### Common Issues

#### Issue: Terraform Backend Error

```
Error: Failed to get existing workspaces: storage.objects.list access denied
```

**Solution**: Create GCS bucket and update `backend.tf`:

```bash
gsutil mb -p $PROJECT_ID -l $REGION gs://${PROJECT_ID}-terraform-state-dev
gsutil versioning set on gs://${PROJECT_ID}-terraform-state-dev
```

#### Issue: Cloud Run Service Won't Start

```
Error: Container failed to start. Failed to start and then listen on the port defined by the PORT environment variable.
```

**Solution**:
1. Check logs: `gcloud run services logs read <SERVICE_NAME> --region us-central1 --limit 100`
2. Verify Spring Boot uses `SERVER_PORT=8080` (Cloud Run expects this)
3. Ensure health check endpoints exist: `/actuator/health/readiness`, `/actuator/health/liveness`
4. Check secret values are set: `gcloud secrets versions access latest --secret=kafka-bootstrap-servers`

#### Issue: Kafka Connection Timeout

```
org.apache.kafka.common.errors.TimeoutException: Failed to update metadata after 60000 ms
```

**Solution**:
1. Verify Kafka bootstrap servers: `echo $KAFKA_BOOTSTRAP_SERVERS`
2. Check API key/secret are correct
3. Ensure Confluent Cloud cluster is running
4. Verify Cloud Run has internet egress (default behavior)
5. Check Kafka SASL configuration in Spring Boot:
   ```yaml
   spring:
     kafka:
       bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS}
       properties:
         sasl.mechanism: PLAIN
         security.protocol: SASL_SSL
         sasl.jaas.config: org.apache.kafka.common.security.plain.PlainLoginModule required username="${KAFKA_API_KEY}" password="${KAFKA_API_SECRET}";
   ```

#### Issue: Schema Registry Authentication Failed

```
io.confluent.kafka.schemaregistry.client.rest.exceptions.RestClientException: Unauthorized
```

**Solution**:
1. Verify Schema Registry URL and credentials
2. Ensure `basic.auth.credentials.source=USER_INFO`
3. Check `basic.auth.user.info=${SCHEMA_REGISTRY_API_KEY}:${SCHEMA_REGISTRY_API_SECRET}`

#### Issue: Vertex AI Permission Denied

```
PERMISSION_DENIED: Permission 'aiplatform.endpoints.predict' denied
```

**Solution**:
1. Verify service account has `roles/aiplatform.user`
2. Check IAM bindings: `gcloud projects get-iam-policy $PROJECT_ID`
3. Ensure Vertex AI API is enabled: `gcloud services enable aiplatform.googleapis.com`

#### Issue: Secret Not Found

```
Error: Secret not found: projects/PROJECT_ID/secrets/SECRET_NAME
```

**Solution**:
1. Check secret exists: `gcloud secrets list`
2. Add secret version: `echo -n "VALUE" | gcloud secrets versions add SECRET_NAME --data-file=-`
3. Verify service account has `secretAccessor` role

### Debug Logs

```bash
# View service logs
gcloud run services logs read <SERVICE_NAME> --region us-central1 --limit 100 --format json

# Tail logs in real-time
gcloud run services logs tail <SERVICE_NAME> --region us-central1

# Filter logs by severity
gcloud run services logs read <SERVICE_NAME> --region us-central1 --log-filter='severity>=ERROR'

# Export logs to file
gcloud run services logs read <SERVICE_NAME> --region us-central1 --limit 1000 > service-logs.txt
```

### Health Checks

```bash
# Check service health
curl https://<SERVICE_URL>/actuator/health

# Check readiness
curl https://<SERVICE_URL>/actuator/health/readiness

# Check liveness
curl https://<SERVICE_URL>/actuator/health/liveness

# Check info
curl https://<SERVICE_URL>/actuator/info
```

---

## Rollback & Updates

### Rollback to Previous Revision

```bash
# List revisions
gcloud run revisions list --service event-ingest-service --region us-central1

# Rollback to specific revision
gcloud run services update-traffic event-ingest-service \
  --region us-central1 \
  --to-revisions <REVISION_NAME>=100
```

### Blue/Green Deployment

```bash
# Deploy new revision with tag
gcloud run deploy event-ingest-service \
  --image <NEW_IMAGE> \
  --region us-central1 \
  --no-traffic \
  --tag blue

# Test blue revision
curl https://blue---event-ingest-service-xyz-uc.a.run.app/actuator/health

# Gradually shift traffic
gcloud run services update-traffic event-ingest-service \
  --region us-central1 \
  --to-revisions LATEST=50,<PREVIOUS_REVISION>=50

# Full cutover
gcloud run services update-traffic event-ingest-service \
  --region us-central1 \
  --to-latest
```

### Update Terraform-Managed Resources

```bash
# Update terraform.tfvars or variables
vim infra/envs/dev/terraform.tfvars

# Plan changes
terraform plan

# Apply changes
terraform apply
```

### Update Container Images

```bash
# Build new image
docker build -t us-central1-docker.pkg.dev/edupulse-483220/edupulse/event-ingest-service:v2 .

# Push image
docker push us-central1-docker.pkg.dev/edupulse-483220/edupulse/event-ingest-service:v2

# Update terraform.tfvars
image_tag = "v2"

# Apply
terraform apply
```

---

## Additional Resources

- [Cloud Run Documentation](https://cloud.google.com/run/docs)
- [Confluent Cloud Documentation](https://docs.confluent.io/cloud/current/overview.html)
- [Terraform Google Provider](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Spring Boot Actuator](https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html)
- [Vertex AI Documentation](https://cloud.google.com/vertex-ai/docs)

---

## Support & Troubleshooting

For issues or questions:
1. Check [Troubleshooting](#troubleshooting) section above
2. Review service logs: `gcloud run services logs read <SERVICE>`
3. Check Terraform state: `terraform show`
4. Validate secrets: `gcloud secrets versions access latest --secret=<SECRET_NAME>`

---

**Last Updated**: 2026-01-03
**Terraform Version**: 1.6.0+
**Google Cloud Provider**: 5.44.0+
