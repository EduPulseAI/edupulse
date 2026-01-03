# FLINK-REFACTOR.md (Claude-Friendly Spec)

## Purpose

Refactor **EduPulse — Adaptive Learning with Real-Time Engagement** to **remove BigQuery entirely** and implement **Apache Flink** (with **Confluent Kafka + Schema Registry + Avro**) for all real-time analytics:

* Real-time aggregates
* Enrichment + joins
* Pattern detection
* Windowed metrics
* Heatmaps + cohort insights

This document is the **source of truth** for the refactor. Claude should follow it strictly.

---

## Non-Negotiables

* **Kafka remains the system of record** for events and derived signals.
* **All Kafka messages are Avro** and governed by **Confluent Schema Registry**.
* **Schema compatibility:** BACKWARD by default (unless explicitly overridden).
* **No BigQuery** (no sinks, datasets, tables, replay strategies based on BigQuery).
* **Spring Boot stays** for orchestration and APIs; it should **not** do heavy streaming aggregation.
* **Next.js stays** for UI; real-time updates continue via SSE/WebSocket.
* Keep the build **hackathon-realistic** (48 hours).

---

## What Changes

### Remove

* BigQuery analytics sink(s)
* Any “analytics/replay” requirements that assume BigQuery
* Any architecture sections that treat BigQuery as required

### Add / Replace With Flink

* One or more Flink jobs that compute:

    * engagement scoring (windowed)
    * adaptive actions (features + policies)
    * instructor tips/metrics streams (aggregates)
* Flink state + checkpointing (hackathon-appropriate defaults)
* Clear Kafka topic I/O mapping for each Flink job

---

## Architectural Target State

### Dataflow Principle

**Kafka → Flink → Kafka → Gateway/UI**
and **Kafka → Spring Boot (AI orchestration) → Kafka** where needed.

### Responsibilities

* **Flink:** streaming computation (windowing, joins, enrichment, CEP-style detection, metric emission)
* **Spring Boot services:** ingest, API endpoints, user/session orchestration, calling Vertex AI & Gemini, emitting resulting events
* **Next.js:** visualization + interaction, consumes real-time topics via Gateway push (SSE/WebSocket)

---

## Required Flink Capabilities for EduPulse

Claude must design Flink to support these (at minimum):

1. **Windowed Engagement Metrics**

    * Sliding/tumbling windows for engagement score per student/session
    * Metrics: dwell time bands, rapid guessing, retries, hint dependence, idle spikes

2. **Enrichment + Joins**

    * Join student events with content metadata (e.g., difficulty, skill tags)
    * Join with session context (cohort, lesson plan, instructor policies)

3. **Pattern Detection**

    * Detect sequences like:

        * repeated wrong answers + short dwell time
        * rapid answer bursts + no improvement
        * engagement collapse events
    * Output “signals” for policy engine / instructor tips

4. **Real-Time Heatmaps**

    * Cohort-level aggregates for instructor dashboard
    * Per-skill struggling distribution and trend in the last N minutes

---

## Topic Model (Keep, Extend Carefully)

Existing topics (keep conceptually; rename only if necessary and explained):

* `session.events`
* `quiz.answers`
* `engagement.scores`
* `adapt.actions`
* `instructor.tips`

If Claude proposes new topics, it must:

* justify why
* specify keys/partitioning
* specify Avro schemas + subjects
* keep it minimal

---

## Avro + Schema Registry Rules

Claude must adhere to these governance rules:

### Subject Naming Strategy

Pick one (default preferred for speed):

* **TopicNameStrategy** (recommended for hackathon)

### Compatibility

* BACKWARD for all primary subjects unless a strong reason exists.

### Contract Design Requirements

* Use clear namespaces and record names.
* Use Avro logical types for timestamps.
* Include defaults for new optional fields.
* Define a DLQ schema approach for malformed events.

### Schema Evolution Requirements

Provide at least:

* one “safe add field” evolution example
* one “breaking change avoided” example with the safe alternative

---

## Flink Job Design Requirements (What Claude Must Produce)

Claude must define **1–3 Flink jobs** (prefer fewer jobs for hackathon simplicity).

For each job, Claude must provide a table including:

* Job name
* Purpose
* Input topics
* Output topics
* Keying strategy (studentId/sessionId/cohortId)
* Windowing strategy (type + durations)
* State kept (what and why)
* Joins/enrichment (what streams/tables)
* Pattern detection logic (if any)
* Delivery guarantees (exactly-once vs at-least-once) and rationale

---

## Deployment Guidance (Hackathon-Friendly)

Claude must recommend **one** deployment approach and stick to it:

Preferred options:

1. **Confluent Cloud for Flink** (if available in the challenge environment)
2. **Flink locally with Docker Compose** for demo reliability
3. **Flink on GKE** only if strongly justified (complexity cost must be addressed)

Claude must include:

* checkpointing approach
* state backend approach (simple for demo; explain trade-offs)
* how to monitor backpressure/checkpoint failures at a basic level

---

## Storage & Replay Strategy Without BigQuery

Claude must replace BigQuery with:

* Kafka retention strategy (and possibly compacted topics)
* optional minimal Postgres tables only if absolutely required (and justified)
* a “demo reset” strategy that does not involve BigQuery

---

## Instructor Dashboard Metric Contract

Claude must output a table describing instructor-facing metrics:

* Metric name
* Definition
* Key (cohortId, skillTag, etc.)
* Window type/duration
* Output topic
* UI usage

---

## Output Requirements for Claude

When applying this refactor, Claude must output in this order:

1. **Refactor Summary**

    * what was removed
    * what was added
    * what changed in dataflow

2. **Updated End-to-End Dataflows**

    * student answer → engagement score → adapt action → UI update
    * hint request → hint response → UI update
    * instructor intervention → adapt action → UI update

3. **Flink Job Specs**

    * job tables and clear responsibilities

4. **Updated Topic + Schema Plan**

    * topic tables
    * subject tables
    * schema evolution rules
    * DLQ approach

5. **Operational Plan**

    * deployment choice
    * checkpoint/state strategy
    * monitoring signals

---

## Guardrails (Prevent Drift)

Claude must NOT:

* reintroduce BigQuery “because it’s easy”
* shift analytics into Spring Boot services
* propose a complex multi-system warehouse architecture
* over-scope beyond hackathon feasibility
* invent new personas/features unrelated to the core demo

---

## Acceptance Criteria (What “Done” Means)

The refactor is successful if:

* BigQuery is completely removed from the architecture and runbook.
* Flink is the primary engine for windowed metrics, joins, and patterns.
* All derived metrics/actions are emitted back to Kafka as Avro with Schema Registry governance.
* The instructor dashboard can be driven by Flink-produced topics.
* The design remains implementable in ~48 hours for a small team.

---

## How to Use This With Claude Code

Claude should follow this workflow:

1. Read this file fully and confirm understanding.
2. Propose the minimal Flink job set and topic I/O mapping.
3. Update architecture docs to match (removing BigQuery).
4. Produce schema/subject tables and evolution guidance.
5. Produce a hackathon-grade deployment plan for Flink.
