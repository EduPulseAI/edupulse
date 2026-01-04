# EduPulse: Real-Time Adaptive Learning Platform

> **AI-powered adaptive learning with Confluent Kafka, Avro, and real-time engagement detection**

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Backend Services](./backend/README.md)
- [Frontend Applications](./frontend/README.md)
- [Cloud & Infrastructure](./infra/README.md)
- [Schema Registry & Avro](#schema-registry--avro)
- [Demo Instructions](#demo-instructions)
- [Troubleshooting](#troubleshooting)

---

## Overview

EduPulse is a real-time adaptive learning platform that detects student disengagement and intervenes during active learning sessions using AI-driven decision-making powered by Confluent Kafka.

**Key Features:**
- Real-time engagement scoring from student interactions
- AI-powered difficulty adjustment (Vertex AI multi-armed bandit)
- Contextual hint generation (Google Gemini)
- Live instructor coaching tips
- Event-driven architecture with Kafka as system of record
- Strict schema governance with Avro and Confluent Schema Registry

**Technology Stack:**
- **Backend:** Spring Boot 3.5, Java 21
- **Stream Processing:** Apache Flink 1.18+
- **Frontend:** Next.js 15, React 19, TypeScript
- **Messaging:** Confluent Kafka, Schema Registry, Avro
- **AI/ML:** Vertex AI, Google Gemini
- **Data:** PostgreSQL, Redis
- **Deployment:** Docker, Google Cloud (GKE, Cloud SQL, Memorystore), Confluent Cloud

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend (Next.js)                       │
│  Student UI              │          Instructor Dashboard    │
└────────────┬─────────────┴──────────────────┬──────────────┘
             │ WebSocket/SSE                   │
             ▼                                 ▼
┌────────────────────────────────────────────────────────────┐
│              Realtime Gateway Service                       │
│         (WebSocket/SSE → Kafka Consumer)                    │
└────────────┬───────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────────────────────┐
│               Confluent Kafka Cluster                       │
│  Topics: quiz.answers, session.events, engagement.scores,  │
│          adapt.actions, instructor.tips, cohort.metrics     │
│  (Schema Registry enforces Avro schemas - BACKWARD compat)  │
└─────┬────────────────────────────────┬────────────────────┘
      │                                │
      │  ┌─────────────────────────────▼────────────────────┐
      │  │         Apache Flink Cluster                     │
      │  │  ┌──────────────────────────────────────────┐    │
      │  │  │  Engagement Analytics Job                │    │
      │  │  │  • Windowed metrics (60s tumbling)       │    │
      │  │  │  • Pattern detection (CEP)               │    │
      │  │  │  • Enrichment joins                      │    │
      │  │  │  IN: quiz.answers, session.events        │    │
      │  │  │  OUT: engagement.scores                  │    │
      │  │  └──────────────────────────────────────────┘    │
      │  │  ┌──────────────────────────────────────────┐    │
      │  │  │  Instructor Metrics Job                  │    │
      │  │  │  • Cohort aggregates (5-min sliding)     │    │
      │  │  │  • Heatmap data                          │    │
      │  │  │  • Skill-level struggle detection        │    │
      │  │  │  IN: engagement.scores, quiz.answers     │    │
      │  │  │  OUT: cohort.metrics, instructor.tips    │    │
      │  │  └──────────────────────────────────────────┘    │
      │  └─────────────────────────────────────────────────┘
      │
      ├──> Event Ingest Service (HTTP → Kafka producer)
      ├──> Bandit Engine (Kafka consumer → Vertex AI → Kafka producer)
      ├──> Tip Service (Kafka consumer → Gemini → Kafka producer)
      └──> Content Adapter (Kafka consumer → enriches adapt.actions)
```

---

## Repository Structure

```
edupulse/
├── backend/
│   ├── event-ingest-service/
│   │   ├── src/
│   │   ├── pom.xml
│   │   └── README.md
│   ├── bandit-engine/
│   │   ├── src/
│   │   ├── pom.xml
│   │   └── README.md
│   ├── tip-service/
│   │   ├── src/
│   │   ├── pom.xml
│   │   └── README.md
│   ├── content-adapter/
│   │   ├── src/
│   │   ├── pom.xml
│   │   └── README.md
│   ├── realtime-gateway/
│   │   ├── src/
│   │   ├── pom.xml
│   │   └── README.md
│   └── shared/
│       └── avro-schemas/
│           ├── event-envelope.avsc
│           ├── quiz-answer.avsc
│           ├── engagement-score.avsc
│           ├── adapt-action.avsc
│           └── instructor-tip.avsc
├── frontend/
│   ├── quizzer-frontend (nx monorepo)
│   └── README.md
├── infrastructure/
│   ├── docker/
│   │   └── docker-compose.yml
│   └── terraform/
├── scripts/
│   ├── register-schemas.sh
│   ├── seed-data.sql
│   └── start-local.sh
├── docs/
│   ├── SYSTEM_DESIGN.md
│   ├── API.md
│   └── DEMO.md
└── README.md (this file)
```

---

## Quick Start

### Prerequisites

- Java 21+
- Node.js 18+
- Docker Desktop
- Confluent Cloud account (or local Kafka with Docker)
- Google Cloud account (for Vertex AI, Gemini)

### One-Command Local Setup

```bash
# Clone repository
git clone https://github.com/EduPulseAI/edupulse.git
cd edupulse

# Start infrastructure (Kafka, PostgreSQL, Redis)
docker compose -f infra/docker/docker-compose up -d

# Set environment variables
cp .env.example .env
# Edit .env with your Confluent Cloud and GCP credentials

# Register Avro schemas
./scripts/register-schemas.sh

# Seed database
psql -h localhost -U edupulse -d edupulse -f scripts/seed-data.sql

## Start all backend services (in separate terminals)
#cd backend/event-ingest-service && ./gradlew bootRun
#cd backend/engagement-service && ./gradlew bootRun
#cd backend/bandit-engine && ./gradlew bootRun
#cd backend/realtime-gateway && ./gradlew bootRun

# Start frontend
#cd frontend && npm install && npm run dev

# Open browser
#open http://localhost:3000
```

---



## Cloud & Infrastructure

### Required GCP Resources

#### Setup
```bash
bash ./scripts/gcloud/setup.sh
```

**Revoke existing auth**
```bash
gcloud auth application-default revoke
```
#### 1. Vertex AI

**Purpose:** Multi-armed bandit inference

**Setup:**

```bash
# Enable Vertex AI API
gcloud services enable aiplatform.googleapis.com

# Create service account
gcloud iam service-accounts create edupulse-vertex \
  --display-name="EduPulse Vertex AI"

# Grant permissions
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:edupulse-vertex@PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/aiplatform.user"

# Create key
gcloud iam service-accounts keys create vertex-key.json \
  --iam-account=edupulse-vertex@PROJECT_ID.iam.gserviceaccount.com

# Deploy model (example with pre-trained model)
gcloud ai models upload \
  --region=us-central1 \
  --display-name=edupulse-bandit-v1 \
  --artifact-uri=gs://your-bucket/model/

# Create endpoint
gcloud ai endpoints create \
  --region=us-central1 \
  --display-name=edupulse-bandit-endpoint

# Deploy model to endpoint
gcloud ai endpoints deploy-model ENDPOINT_ID \
  --region=us-central1 \
  --model=MODEL_ID \
  --display-name=edupulse-bandit-v1 \
  --machine-type=n1-standard-4 \
  --min-replica-count=1 \
  --max-replica-count=3
```

#### 2. Gemini API

**Setup:**

```bash
# Enable Vertex AI Gemini API
gcloud services enable generativelanguage.googleapis.com

# Get API key from Cloud Console or use service account
export GEMINI_API_KEY=$(gcloud auth print-access-token)
```

#### 3. Cloud SQL (PostgreSQL)

```bash
# Create instance
gcloud sql instances create edupulse-db \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=us-central1

# Create database
gcloud sql databases create edupulse \
  --instance=edupulse-db

# Create user
gcloud sql users create edupulse \
  --instance=edupulse-db \
  --password=SECURE_PASSWORD
```

#### 4. Memorystore (Redis)

```bash
# Create instance
gcloud redis instances create edupulse-redis \
  --size=1 \
  --region=us-central1 \
  --redis-version=redis_7_0
```

---

### Confluent Cloud Resources

#### 1. Kafka Cluster

**Setup via UI:**

1. Go to https://confluent.cloud
2. Create account / log in
3. Create environment: "EduPulse Production"
4. Create cluster: Standard tier, us-east-1, 3 zones
5. Generate API keys:
    - Cluster API key (for Kafka)
    - Schema Registry API key

**Setup via CLI:**

```bash
# Install Confluent CLI
brew install confluentinc/tap/cli

# Login
confluent login

# Create cluster
confluent kafka cluster create edupulse-cluster \
  --cloud aws \
  --region us-east-1 \
  --type standard

# Get bootstrap servers
confluent kafka cluster describe

# Create API key
confluent api-key create --resource <cluster-id>
```

#### 2. Topics

```bash
# Create topics
confluent kafka topic create session.events --partitions 6
confluent kafka topic create quiz.answers --partitions 6
confluent kafka topic create engagement.scores --partitions 6
confluent kafka topic create adapt.actions --partitions 6
confluent kafka topic create instructor.tips --partitions 3

# Create DLQ topics
confluent kafka topic create quiz.answers.dlq --partitions 3
confluent kafka topic create engagement.scores.dlq --partitions 3
```

#### 3. Schema Registry

```bash
# Get Schema Registry endpoint
confluent schema-registry cluster describe

# Create API key
confluent api-key create --resource <sr-cluster-id>

# Register schemas (see scripts/register-schemas.sh)
./scripts/register-schemas.sh
```

---

### Local Development Setup (Docker Compose)

**Start local infrastructure:**

```bash
docker-compose up -d

# Check health
docker-compose ps

# View logs
docker-compose logs -f kafka
```

**Create topics locally:**

```bash
# Install Kafka CLI tools
brew install kafka

# Create topics
kafka-topics --create --topic session.events --partitions 6 --bootstrap-server localhost:9092
kafka-topics --create --topic quiz.answers --partitions 6 --bootstrap-server localhost:9092
kafka-topics --create --topic engagement.scores --partitions 6 --bootstrap-server localhost:9092
kafka-topics --create --topic adapt.actions --partitions 6 --bootstrap-server localhost:9092
kafka-topics --create --topic instructor.tips --partitions 3 --bootstrap-server localhost:9092

# List topics
kafka-topics --list --bootstrap-server localhost:9092
```

---

### Complete Environment Variable Reference

**.env (for local development):**

```bash
# Kafka (Confluent Cloud or local)
KAFKA_BOOTSTRAP_SERVERS=localhost:9092
KAFKA_API_KEY=
KAFKA_API_SECRET=

# Schema Registry
SCHEMA_REGISTRY_URL=http://localhost:8081
SCHEMA_REGISTRY_KEY=
SCHEMA_REGISTRY_SECRET=

# PostgreSQL
POSTGRES_URL=jdbc:postgresql://localhost:5432/edupulse
POSTGRES_USER=edupulse
POSTGRES_PASSWORD=edupulse

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379

# Google Cloud
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
VERTEX_AI_PROJECT_ID=your-project-id
VERTEX_AI_LOCATION=us-central1
VERTEX_AI_ENDPOINT=projects/.../locations/.../endpoints/...
GEMINI_API_KEY=your-gemini-key

# Service Ports
EVENT_INGEST_PORT=8081
ENGAGEMENT_SERVICE_PORT=8082
BANDIT_ENGINE_PORT=8083
TIP_SERVICE_PORT=8084
CONTENT_ADAPTER_PORT=8085
REALTIME_GATEWAY_PORT=8086

# Frontend
NEXT_PUBLIC_API_URL=http://localhost:8081
NEXT_PUBLIC_WS_URL=ws://localhost:8086
```

---

### One-Command Startup

**scripts/start-local.sh:**

```bash
#!/bin/bash
set -e

echo "🚀 Starting EduPulse local environment..."

# Start infrastructure
echo "📦 Starting Docker containers..."
docker-compose up -d

# Wait for services
echo "⏳ Waiting for services to be ready..."
sleep 10

# Create topics
echo "📝 Creating Kafka topics..."
kafka-topics --create --if-not-exists --topic session.events --partitions 6 --bootstrap-server localhost:9092
kafka-topics --create --if-not-exists --topic quiz.answers --partitions 6 --bootstrap-server localhost:9092
kafka-topics --create --if-not-exists --topic engagement.scores --partitions 6 --bootstrap-server localhost:9092
kafka-topics --create --if-not-exists --topic adapt.actions --partitions 6 --bootstrap-server localhost:9092
kafka-topics --create --if-not-exists --topic instructor.tips --partitions 3 --bootstrap-server localhost:9092

# Register schemas
echo "📋 Registering Avro schemas..."
./scripts/register-schemas.sh

# Seed database
echo "🌱 Seeding database..."
psql -h localhost -U edupulse -d edupulse -f scripts/seed-data.sql

echo "✅ Infrastructure ready!"
echo ""
echo "Start backend services (in separate terminals):"
echo "  cd backend/event-ingest-service && ./gradlew bootRun"
echo "  cd backend/engagement-service && ./gradlew bootRun"
echo "  cd backend/bandit-engine && ./gradlew bootRun"
echo "  cd backend/realtime-gateway && ./gradlew bootRun"
echo ""
echo "Start frontend:"
echo "  cd frontend && npm run dev"
echo ""
echo "Open http://localhost:3000"
```

**Run:**

```bash
chmod +x scripts/start-local.sh
./scripts/start-local.sh
```

---

## Schema Registry & Avro

### Schema Folder Strategy

**Location:** `backend/common/src/main/avro`

**Structure:**

```
backend/shared/avro-schemas/
├── common/
│   └── event-envelope.avsc
├── session/
│   ├── session-event.avsc
│   └── session-event-key.avsc
├── quiz/
│   ├── quiz-answer.avsc
│   └── quiz-answer-key.avsc
├── engagement/
│   └── engagement-score.avsc
├── adapt/
│   └── adapt-action.avsc
└── instructor/
    └── instructor-tip.avsc
```

### Register Schemas Script

**scripts/register-schemas.sh:**

```bash
#!/bin/bash
set -e

SCHEMA_REGISTRY_URL=${SCHEMA_REGISTRY_URL:-http://localhost:8081}
SCHEMA_DIR="backend/shared/avro-schemas"

echo "Registering schemas to $SCHEMA_REGISTRY_URL..."

# Function to register schema
register_schema() {
    local subject=$1
    local schema_file=$2
    
    echo "Registering $subject..."
    
    curl -X POST \
        -H "Content-Type: application/vnd.schemaregistry.v1+json" \
        --data "{\"schema\": $(cat $schema_file | jq -R -s -c .)}" \
        "$SCHEMA_REGISTRY_URL/subjects/$subject/versions"
    
    echo ""
}

# Register event envelope (referenced by other schemas)
register_schema "event-envelope" "$SCHEMA_DIR/common/event-envelope.avsc"

# Register quiz schemas
register_schema "quiz.answers-key" "$SCHEMA_DIR/quiz/quiz-answer-key.avsc"
register_schema "quiz.answers-value" "$SCHEMA_DIR/quiz/quiz-answer.avsc"

# Register engagement schemas
register_schema "engagement.scores-value" "$SCHEMA_DIR/engagement/engagement-score.avsc"

# Register adapt schemas
register_schema "adapt.actions-value" "$SCHEMA_DIR/adapt/adapt-action.avsc"

# Register instructor schemas
register_schema "instructor.tips-value" "$SCHEMA_DIR/instructor/instructor-tip.avsc"

echo "✅ All schemas registered!"

# Set compatibility mode
echo "Setting compatibility mode to BACKWARD..."
curl -X PUT \
    -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data '{"compatibility": "BACKWARD"}' \
    "$SCHEMA_REGISTRY_URL/config"

echo ""
echo "✅ Schema Registry configured!"
```

### Gradle Avro Plugin

**backend/engagement-service/build.gradle:**

```gradle
plugins {
    id "com.github.davidmc24.gradle.plugin.avro" version "1.9.1"
}

dependencies {
    implementation 'org.apache.avro:avro:1.11.3'
}

avro {
    fieldVisibility = "PRIVATE"
    outputCharacterEncoding = "UTF-8"
    stringType = "String"
}

// Generate Java classes from .avsc files
generateAvroJava {
    source = file("../shared/avro-schemas")
}
```

**Generate classes:**

```bash
cd backend/engagement-service
./gradlew generateAvroJava
```

---

## Demo Instructions

### Pre-Demo Setup (5 minutes)

1. **Start all services:**

```bash
# Terminal 1: Infrastructure
docker-compose up -d

# Terminal 2: Event Ingest
cd backend/event-ingest-service && ./gradlew bootRun

# Terminal 3: Engagement Service
cd backend/engagement-service && ./gradlew bootRun

# Terminal 4: Bandit Engine
cd backend/bandit-engine && ./gradlew bootRun

# Terminal 5: Realtime Gateway
cd backend/realtime-gateway && ./gradlew bootRun

# Terminal 6: Frontend
cd frontend && npm run dev
```

2. **Open browser windows:**

- Student UI: http://localhost:3000/student/alice
- Instructor Dashboard: http://localhost:3000/instructor/dashboard
- Confluent Cloud UI: https://confluent.cloud (show live topics)

3. **Pre-warm services:**

```bash
# Call Vertex AI once to avoid cold start
curl -X POST http://localhost:8083/api/health/vertex-ai
```

---

### Demo Script (3 minutes)

**[0:00-0:30] Setup & Introduction**

> "EduPulse detects student disengagement in real-time and adapts learning experiences using AI on streaming data."

- Show both screens: Student UI (left), Instructor Dashboard (right)
- Point out Alice's green engagement tile (score: 0.72)

**[0:30-1:15] Student Struggles**

> "Watch what happens when Alice struggles with a question..."

1. Alice answers incorrectly (attempt 1)
    - Show: Engagement tile turns yellow (0.51)
2. Alice answers incorrectly (attempt 2)
    - Show: Engagement tile turns orange (0.45)
3. Alice answers incorrectly (attempt 3)
    - Show: Engagement tile turns red (0.38) with alert icon
    - Instructor dashboard: Tip appears "Alice may need help with linear equations..."

**[1:15-2:00] AI Intervention**

> "EduPulse's AI responds in milliseconds. Let me show you what's happening under the hood..."

- Switch to Confluent Cloud UI
- Show messages flowing through quiz.answers topic
- Show engagement.scores topic with alertThresholdCrossed = true
- Point out Avro schema enforcement

> "Our bandit model at Vertex AI selects the optimal difficulty..."

- Show adapt.actions topic with DIFFICULTY_ADJUST
- Show modelMetadata: inference latency ~187ms

**[2:00-2:30] Student Recovery**

> "Watch Alice's screen..."

- Hint appears: "Try isolating the variable by working backwards"
- New easier question appears (difficulty 2 vs 4)
- Alice answers correctly
- Engagement tile recovers to green (0.68)

**[2:30-3:00] Schema Governance**

> "Everything you saw is governed by Avro schemas in Schema Registry..."

- Show Schema Registry UI
- Point out BACKWARD compatibility
- Mention schema evolution example (optional field addition)

> "This architecture is production-ready: event sourcing, schema governance, and sub-500ms AI-driven personalization."

---

### Demo Checklist

**Before presenting:**

- [ ] All services healthy (check actuator/health endpoints)
- [ ] WebSocket connections established
- [ ] Alice's initial state reset (engagement: 0.72, difficulty: 4)
- [ ] Instructor dashboard showing 3-5 students
- [ ] Confluent Cloud UI open (topics tab)
- [ ] Demo questions loaded (q1-q5)
- [ ] Backup video accessible
- [ ] Laptop charged, HDMI adapter ready

**During demo:**

- [ ] Speak clearly and slowly
- [ ] Point mouse at relevant UI elements
- [ ] Show timestamps/latency numbers
- [ ] Highlight "real-time" updates
- [ ] Mention Kafka, Avro, Schema Registry by name

**After demo:**

- [ ] Thank judges
- [ ] Offer to answer questions
- [ ] Provide GitHub link or QR code

---

## Troubleshooting

### Kafka Connection Issues

**Problem:** `Connection to node -1 could not be established`

**Solution:**

```bash
# Check Kafka is running
docker-compose ps kafka

# Check bootstrap servers
echo $KAFKA_BOOTSTRAP_SERVERS

# Test connection
kafka-broker-api-versions --bootstrap-server localhost:9092
```

---

### Schema Registry Errors

**Problem:** `Schema not found: event-envelope`

**Solution:**

```bash
# Re-register schemas
./scripts/register-schemas.sh

# Verify registration
curl http://localhost:8081/subjects
```

---

### Avro Deserialization Errors

**Problem:** `Error deserializing Avro message for id 123`

**Solution:**

```bash
# Check schema compatibility
curl -X POST \
  http://localhost:8081/compatibility/subjects/quiz.answers-value/versions/latest \
  -d @backend/shared/avro-schemas/quiz/quiz-answer.avsc

# If incompatible, check DLQ topic
kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic quiz.answers.dlq \
  --from-beginning
```

---

### WebSocket Disconnections

**Problem:** WebSocket closes immediately after connecting

**Solution:**

```bash
# Check JWT token validation
# Disable auth temporarily for debugging
# In WebSocketConfig.java:
registry.addHandler(realtimeHandler(), "/ws")
    .setAllowedOrigins("*")
    // .addInterceptors(authInterceptor()); // Comment out

# Restart Realtime Gateway
```

---

### Vertex AI Timeout

**Problem:** `Vertex AI call timed out after 500ms`

**Solution:**

```bash
# Increase timeout
# In application.yml:
vertex:
  ai:
    timeout-ms: 2000

# Verify fallback is working
curl http://localhost:8083/actuator/metrics/bandit.fallback.count
```

---

### PostgreSQL Connection Refused

**Problem:** `Connection to localhost:5432 refused`

**Solution:**

```bash
# Check PostgreSQL is running
docker-compose ps postgres

# Test connection
psql -h localhost -U edupulse -d edupulse -c "SELECT 1"

# Check environment variable
echo $POSTGRES_URL
```

---

**For additional help:**
- Check service logs: `docker-compose logs -f <service-name>`
- View Spring Boot actuator: `curl http://localhost:808X/actuator/health`
- Monitor Kafka in Confluent Cloud UI
- Review SYSTEM_DESIGN.md for architecture details

---

**End of README**