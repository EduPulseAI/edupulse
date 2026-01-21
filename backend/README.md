# EduPulse Backend Services

This directory contains all backend microservices for the EduPulse platform. The backend layer orchestrates real-time adaptive learning through event-driven architecture, leveraging Confluent Kafka for messaging, Kafka Streams for stream processing, and Spring Boot for service orchestration.

## Backend Overview

The EduPulse backend is built on **event-driven architecture** principles, designed to handle real-time learner interactions and adaptive responses at scale. The backend layer serves as the nervous system of the platform, connecting user actions to intelligent adaptations.

**Core Technologies:**
- **Confluent-Managed Kafka**: Event streaming backbone with Schema Registry for governance
- **Kafka Streams**: Real-time stream processing for windowing, aggregation, and engagement scoring
- **Spring Boot 3.x + Java 21**: Microservices framework for orchestration and API gateways
- **PostgreSQL**: Persistent storage for content and configuration
- **Avro**: Standardized message serialization format

The backend emphasizes clean separation of concerns: Spring Boot services handle orchestration, API endpoints, AI integration, and stream processing via embedded Kafka Streams.

## High-Level Backend Responsibilities

The backend layer is responsible for:

- **Event Ingestion**: Accepting learner interactions, quiz submissions, and navigation events via REST APIs
- **Event Production & Consumption**: Publishing and subscribing to Kafka topics using Avro schemas with Schema Registry
- **AI Orchestration**: Integrating with Vertex AI (multi-armed bandit) and Google Gemini for adaptive decision-making
- **Real-Time Routing**: Streaming derived events and insights to the frontend via Server-Sent Events (SSE)
- **Schema Governance**: Enforcing backward-compatible Avro schemas across all event types
- **Service Boundaries**: Maintaining clear microservice boundaries with well-defined APIs

The backend explicitly does **NOT**:

- Handle batch analytics or data warehousing (BigQuery removed from architecture)
- Require external stream processing clusters (Kafka Streams runs embedded in services)

## Backend Services

| Service Name                                                             | Status      | Primary Responsibility                                                                               | Kafka Interaction                                              |
|--------------------------------------------------------------------------|-------------|------------------------------------------------------------------------------------------------------|----------------------------------------------------------------|
| [**quiz-service**               ](./quiz-service/README.md)              | Implemented | Unified service: HTTP API gateway, quiz content management, session handling, AI question generation | Produces: `quiz.answers`, `session.events`                     |
| [**engagement-service**         ](./engagement-service/README.md)        | Implemented | Computes real-time engagement scores using Kafka Streams windowed aggregation                        | Consumes: `quiz.answers`, `session.events`<br>Produces: `engagement.scores` |
| [**policy-bandit-service**      ](./policy-bandit-service/README.md)     | Planned     | Executes multi-armed bandit policy via Vertex AI; selects next question difficulty                   | Consumes: engagement events<br>Produces: `adapt.actions`       |
| [**content-adapter-service**    ](./content-adapter-service/README.md)   | Planned     | Applies adaptation actions; selects content based on bandit decisions                                | Consumes: `adapt.actions`<br>Produces: adapted content events  |
| [**tip-orchestration-service**  ](./tip-orchestration-service/README.md) | Planned     | Generates instructor coaching tips using Gemini AI based on class-wide patterns                      | Consumes: aggregated engagement<br>Produces: `instructor.tips` |
| [**sse-service**                ](./sse-service/README.md)               | Implemented | SSE gateway; fans out derived Kafka events to frontend clients in real-time                          | Consumes: all derived topics<br>Produces: SSE streams          |

## Real-Time Data Flow

The backend follows a clear event flow from user interaction to adaptive response:

1. **Raw Event Ingestion**: The frontend sends user interactions (quiz answers, navigation, focus/blur events) to `quiz-service` via REST API. The service validates the payload and publishes Avro-serialized events to Kafka topics (`quiz.answers`, `session.events`).

2. **Engagement Scoring with Kafka Streams**: The `engagement-service` consumes raw events using Kafka Streams and performs real-time computations including 60-second tumbling windows, stream merging (combining quiz answers with session events), and weighted engagement score calculation (accuracy, dwell time, pacing). It produces `engagement.scores` with trend detection and alert flags.

3. **AI-Driven Adaptation**: Services like `policy-bandit-service` consume engagement scores and invoke Vertex AI to select optimal difficulty levels using multi-armed bandit algorithms. Adaptation decisions are published to `adapt.actions` topic.

4. **Content Selection**: `content-adapter-service` consumes adaptation actions and queries the `quiz-service` to select appropriate questions, publishing adapted content events back to Kafka.

5. **SSE Service**: `sse-service` subscribes to all derived topics and maintains open SSE connections with frontend clients. It fans out events based on client subscriptions (session ID, student ID, or instructor dashboard).

**Key Principle**: Stream processing is handled by embedded Kafka Streams in the engagement-service. The SSE service is a simple fan-out layer with no business logic beyond routing.

## Schema & Messaging Standards

All inter-service communication via Kafka uses **Avro schemas** managed by Confluent Schema Registry. This ensures type safety, evolvability, and documentation-as-code.

**Schema Governance:**
- **Format**: Apache Avro (binary serialization with schema evolution support)
- **Registry**: Confluent Schema Registry stores all schema versions
- **Compatibility**: Default compatibility mode is **BACKWARD**, allowing consumers to read new data with old schemas
- **Validation**: Producers validate messages against registered schemas before publishing
- **Versioning**: Schema changes follow semantic versioning; breaking changes require new topics

**Why Schema Governance Matters in EduPulse:**
- **Multi-team coordination**: Frontend and backend teams work against stable contracts
- **Zero-downtime deployments**: Services can be updated independently without breaking message compatibility
- **Auditability**: Schema Registry provides a centralized catalog of all event types and their evolution
- **Type safety**: Avro code generation ensures compile-time checks in Java and TypeScript

Specific Avro schema definitions are maintained in each service's repository. Refer to individual service READMEs for schema details.

## Where to Go Next

**New to EduPulse Backend?**
- Start with [SYSTEM_DESIGN.md](../docs/SYSTEM-DESIGN.md) for architectural context and design decisions
- Review [CLAUDE.md](../CLAUDE.md) for development commands and repository structure

**Working on a Specific Service?**
- Navigate to the service directory and open its `README.md` for detailed documentation
- Example: [quiz-service README](./quiz-service/README.md)

**Understanding Stream Processing Logic?**
- Kafka Streams topology is in `engagement-service/src/main/java/.../topology/`
- See [engagement-service README](./engagement-service/README.md) for windowing, aggregation, and scoring details

**Deploying Backend Services?**
- Refer to [docs/DEPLOYMENT.md](../docs/DEPLOYMENT.md) for local Docker Compose setup and GCP deployment instructions
- Kafka and PostgreSQL infrastructure configuration is in `infra/docker-compose.yml`

**Contributing?**
- Follow Spring Boot conventions outlined in [CLAUDE.md](../CLAUDE.md)
- Ensure all new event types include Avro schemas with backward compatibility
- Add service-specific README files for new microservices following the structure of existing services
