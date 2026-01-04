Using the existing EduPulse project context and the recent decision to use **Flink + Confluent** for all real-time computation, update our documentation to reflect the new real-time architecture and remove/replace any references to WebSockets.

Important context (must be reflected in docs):
- Flink does the hard real-time work:
    - windowed metrics, joins, enrichment, pattern detection
    - reads Avro from Kafka + Schema Registry
    - writes derived Avro back to Kafka topics (e.g., cohort.heatmap, decision.context, adapt.actions, instructor.tips, etc.)
- The Realtime Gateway service does only:
    - consume Kafka derived topics (Avro + Schema Registry)
    - route messages to subscribers by sessionId/studentId/cohortId
    - push to Next.js using **SSE** (not WebSockets)
- The realtime-gateway-service is not scaffolded yet; this task is documentation-only.

Task:
1) Identify documentation files that reference:
    - WebSockets
    - “realtime gateway” responsibilities that imply stream processing
    - BigQuery (should already be removed but verify)
2) Update documentation to:
    - Replace “WebSockets” with “SSE” everywhere appropriate
    - Clarify strict separation of responsibilities:
        - Flink = compute
        - Realtime Gateway (Spring MVC) = fan-out + SSE delivery only
    - Add a clear “Real-time Pipeline” section:
        - Kafka raw events → Flink jobs → Kafka derived topics → Realtime Gateway → Next.js via SSE
    - Add a “Derived Topics” subsection with a Markdown table including:
        - Topic name
        - Produced by (Flink job)
        - Key (studentId/sessionId/cohortId)
        - Purpose
        - Consumed by (Realtime Gateway / services)
        - UI surface (student vs instructor)
    - Add a “Realtime Gateway” subsection describing:
        - What it does
        - What it does NOT do
        - Routing keys and subscription models (student stream vs instructor/cohort stream)
        - Why SSE is preferred (simplicity, one-way push, browser-native)
3) Ensure all updates are consistent with:
    - Confluent-managed Kafka, Schema Registry, Flink
    - Avro contracts and Schema Registry governance
    - Spring Boot microservices + Next.js UI
4) Output deliverable as:
    - A patch/diff style update OR the full updated content for each changed doc (choose whichever is clearer)

Files to update (use what exists; update only those present in repo):
- docs/SYSTEM_DESIGN.md
- docs/DEPLOYMENT.md
- ./README.md 

Output requirements:
- Documentation only (no code scaffolding)
- Use Markdown headings and Markdown tables for structured sections
- Be explicit about responsibilities and dataflow
- Do not introduce new services beyond the Realtime Gateway and Flink jobs already described
