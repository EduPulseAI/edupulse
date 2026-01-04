Using the existing EduPulse project context, generate a concise but clear `./backend/README.md`.

Purpose of this README:
- Act as the **entry point** for all backend services
- Explain how backend services work together at a high level
- Link to **service-specific README files**
- Avoid deep implementation details (those belong in each service README)

IMPORTANT CONSTRAINTS:
- This is a documentation-only task
- Do NOT include code blocks
- Use Markdown headings, bullet points, and tables
- Keep the core README concise and navigable

---

## CONTENT TO INCLUDE

### 1. Backend Overview
- Brief description of the backend layer in EduPulse
- Emphasize:
    - Event-driven architecture
    - Confluent-managed Kafka + Schema Registry
    - Flink as the real-time compute layer
    - Spring Boot services as orchestrators and gateways

---

### 2. High-Level Backend Responsibilities
Bullet list describing what the backend as a whole is responsible for:
- Ingesting learner and instructor events
- Producing and consuming Kafka events (Avro + Schema Registry)
- Orchestrating AI calls (Vertex AI, Gemini)
- Routing real-time updates to the frontend via SSE
- Enforcing security, schema governance, and service boundaries

Explicitly state what the backend does NOT do:
- No heavy stream processing inside Spring services
- No batch analytics or data warehousing (BigQuery removed)

---

### 3. Backend Services (Current & Planned)

Provide a Markdown table with columns:
- Service Name
- Status (Implemented / Planned)
- Primary Responsibility
- Kafka Interaction (Produce / Consume)
- Link to README

Include (at minimum) the following services:

- ingest-event-service
- quizzer
- engagement-feature-service (planned)
- policy-bandit-service (planned)
- content-adapter-service (planned)
- tip-orchestration-service (planned)
- realtime-gateway-service (planned)

Links should point to:
- `./backend/<service-name>/README.md`

---

### 4. Real-Time Data Flow (Conceptual)
Textual explanation (no diagrams) describing:
- Raw events → Kafka
- Flink jobs → derived Kafka topics
- Realtime Gateway → SSE streams → Next.js UI

Clarify:
- Flink owns windowing, joins, enrichment, pattern detection
- Realtime Gateway only fans out derived events

---

### 5. Schema & Messaging Standards
Brief section describing:
- Avro as the message format
- Confluent Schema Registry usage
- BACKWARD compatibility as default
- Why schema governance matters in EduPulse

No schema definitions here — reference service READMEs instead.

---

### 6. Where to Go Next
Short “Getting Started” style section:
- If you’re new, read SYSTEM_DESIGN.md
- To work on a service, open its README
- To understand streaming logic, see Flink jobs under `infra/confluent/flink/`
- To deploy backend services, see docs/DEPLOYMENT.md

---

## OUTPUT REQUIREMENTS
- Use Markdown headings, bullets, and tables
- Keep it concise but accurate
- Ensure links are relative and consistent with repo structure
