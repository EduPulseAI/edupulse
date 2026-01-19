# EduPulse System Design

**Real-Time Adaptive Learning Platform with Event-Driven Architecture**

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Real-Time Pipeline](#real-time-pipeline)
3. [Event Flow & Data Flow](#event-flow--data-flow)
4. [Flink Stream Processing](#flink-stream-processing)
5. [Derived Topics](#derived-topics)
6. [SSE Service](#sse-service)
7. [Backend Services](#backend-services)
8. [Schema Governance with Avro](#schema-governance-with-avro)
9. [AI/ML Integration](#aiml-integration)
10. [Scalability & Performance](#scalability--performance)

---

## Architecture Overview

EduPulse is built on a **fully event-driven architecture** using Confluent Kafka as the system of record. The platform follows a strict separation of concerns:

- **Confluent Flink**: ALL real-time stream processing and computation
- **Spring Boot Microservices**: Business logic, AI integration, content management
- **SSE Service**: Fan-out and SSE delivery ONLY (no computation)
- **Next.js Frontend**: Student UI and Instructor Dashboard with SSE

### Core Principles

1. **Event Sourcing**: Kafka topics are the source of truth
2. **Schema Governance**: Avro with Schema Registry enforces contracts
3. **Separation of Concerns**: Flink does compute, Gateway does routing
4. **Managed Services**: Confluent Cloud for Kafka, Schema Registry, Flink
5. **Serverless Backend**: Google Cloud Run for microservices

### Technology Stack

| Layer                 | Technology                             | Purpose                                |
|-----------------------|----------------------------------------|----------------------------------------|
| **Frontend**          | Next.js 15, React 19, TypeScript       | Student UI, Instructor Dashboard       |
| **API Gateway**       | Spring Boot 3.5 (Quiz Service)         | HTTP → Kafka producer, content management |
| **Messaging**         | Confluent Kafka (KRaft mode)           | Event streaming backbone               |
| **Stream Processing** | Confluent Flink 1.18+                  | Real-time analytics, aggregations, CEP |
| **Schema Registry**   | Confluent Schema Registry              | Avro schema management                 |
| **Microservices**     | Spring Boot 3.5, Java 21               | Business logic, AI orchestration       |
| **Realtime Delivery** | Spring MVC with SSE                    | Kafka → SSE fan-out                    |
| **State Store**       | Redis (Memorystore)                    | SSE connection routing maps            |
| **AI/ML**             | Vertex AI, Google Gemini               | Bandit model, hint generation          |
| **Deployment**        | Google Cloud Run, Confluent Cloud      | Serverless containers, managed Kafka   |

---

## Real-Time Pipeline

### Strict Separation of Responsibilities

**Flink (Confluent Managed) = ALL Computation**
- Windowed aggregations (tumbling, sliding, session windows)
- Stream joins (enrichment, temporal joins, interval joins)
- Pattern detection (Complex Event Processing with CEP)
- Stateful transformations (map, flatMap, reduce, aggregate)
- Reads Avro from raw topics via Schema Registry
- Writes Avro to derived topics via Schema Registry

**Realtime Gateway (Spring Boot) = Fan-out ONLY**
- Consumes derived topics from Kafka (NO raw topics)
- Routes messages by routing keys (sessionId, studentId, cohortId)
- Pushes to Next.js clients via SSE (Server-Sent Events)
- NO stream processing, NO computation, NO aggregation
- NO business logic beyond routing
- Uses Redis for SSE connection routing (stateless, horizontally scalable)

### Event Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                        Frontend (Next.js)                        │
│                                                                  │
│  Student submits quiz answer                                    │
│  Frontend sends HTTP POST to Quiz Service                       │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                         Quiz Service                             │
│                                                                  │
│  • Validates request                                            │
│  • Enriches with metadata (timestamp, sessionId)                │
│  • Produces Avro message to quiz.answers topic                  │
│  • Manages quiz content (topics, questions, sessions)           │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                      Confluent Kafka Cluster                     │
│                                                                  │
│  Raw Topics:                                                    │
│    • quiz.answers (key: studentId, value: QuizAnswer)           │
│    • session.events (key: sessionId, value: SessionEvent)       │
│                                                                  │
│  Schema Registry validates Avro schemas on produce/consume      │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                    Confluent Flink Jobs                          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Engagement Analytics Job                                │   │
│  │ • Consumes: quiz.answers, session.events                │   │
│  │ • Windowing: 60-second tumbling windows                 │   │
│  │ • Computation: engagement score, pattern detection      │   │
│  │ • Enrichment: join with student history                 │   │
│  │ • Produces: engagement.scores, decision.context         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Instructor Metrics Job                                  │   │
│  │ • Consumes: engagement.scores, quiz.answers             │   │
│  │ • Windowing: 5-minute sliding windows                   │   │
│  │ • Computation: cohort aggregates, heatmap data          │   │
│  │ • Produces: cohort.heatmap, instructor.tips             │   │
│  └─────────────────────────────────────────────────────────┘   │
└────────────────────────────┬─────────────────────────────────────┘
                             │
                             ▼
┌──────────────────────────────────────────────────────────────────┐
│                      Confluent Kafka Cluster                     │
│                                                                  │
│  Derived Topics (produced by Flink):                            │
│    • engagement.scores (key: studentId)                         │
│    • decision.context (key: sessionId)                          │
│    • cohort.heatmap (key: cohortId)                             │
│    • instructor.tips (key: cohortId or studentId)               │
│                                                                  │
│  Derived Topics (produced by microservices):                    │
│    • adapt.actions (key: studentId) - from Bandit Engine        │
└────────────────────────────┬─────────────────────────────────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
              ▼                             ▼
┌──────────────────────────┐  ┌────────────────────────────────────┐
│  Bandit Engine           │  │  Realtime Gateway                  │
│                          │  │                                    │
│  • Consumes:             │  │  • Consumes ALL derived topics     │
│    decision.context      │  │  • Routes by routing keys          │
│  • Calls Vertex AI       │  │  • Maintains SSE connections       │
│  • Produces:             │  │  • Uses Redis for routing maps     │
│    adapt.actions         │  │  • Pushes to Next.js clients       │
└──────────────────────────┘  └────────────────┬───────────────────┘
                                               │
                                               │ SSE (Server-Sent Events)
                                               ▼
                              ┌────────────────────────────────────┐
                              │     Frontend (Next.js)             │
                              │                                    │
                              │  • EventSource connections         │
                              │  • Real-time updates to UI         │
                              │  • Engagement indicators           │
                              │  • Adaptive hints                  │
                              │  • Instructor alerts               │
                              └────────────────────────────────────┘
```

### Why SSE over WebSockets?

| Feature             | SSE                          | WebSockets                          |
|---------------------|------------------------------|-------------------------------------|
| **Direction**       | One-way (server → client)    | Bi-directional                      |
| **Protocol**        | HTTP (chunked transfer)      | Custom protocol over HTTP           |
| **Browser Support** | Native (`EventSource` API)   | Native (`WebSocket` API)            |
| **Reconnection**    | Automatic browser retry      | Manual implementation needed        |
| **Firewall/Proxy**  | HTTP-friendly                | May require configuration           |
| **Overhead**        | Lower (no handshake)         | Higher (handshake protocol)         |
| **Use Case**        | Real-time push notifications | Chat, gaming, collaborative editing |

**EduPulse Choice**: SSE is perfect for our use case (server-to-client real-time updates). We don't need bi-directional communication since clients send events via REST API, not WebSocket.

---

## Event Flow & Data Flow

### 1. Student Answers Question

```
Student UI → POST /api/quiz/answer/submit
  {
    "studentId": "alice",
    "questionId": "q1",
    "answer": "A",
    "isCorrect": false,
    "timeSpent": 15000
  }

Quiz Service → Kafka (quiz.answers topic)
  Key: "alice"
  Value (Avro):
  {
    "studentId": "alice",
    "questionId": "q1",
    "answer": "A",
    "isCorrect": false,
    "timeSpent": 15000,
    "timestamp": 1704402345000,
    "sessionId": "session-123"
  }
```

### 2. Flink Computes Engagement Score

```
Flink Engagement Analytics Job:
  • Consumes quiz.answers (alice's answer)
  • Consumes session.events (alice's recent activity)
  • Applies 60-second tumbling window
  • Computes engagement score:
    - correctnessRate = 0.33 (1 correct out of 3 recent)
    - avgTimeSpent = 18000ms (above threshold → struggling)
    - pattern: "rapid_incorrect_submissions"
    - engagementScore = 0.38 (red alert)
  • Produces to engagement.scores topic

Kafka (engagement.scores topic)
  Key: "alice"
  Value (Avro):
  {
    "studentId": "alice",
    "score": 0.38,
    "alertLevel": "RED",
    "pattern": "rapid_incorrect_submissions",
    "timestamp": 1704402345000,
    "windowStart": 1704402285000,
    "windowEnd": 1704402345000
  }
```

### 3. Realtime Gateway Pushes to UI

```
Realtime Gateway:
  • Consumes engagement.scores
  • Routes by studentId = "alice"
  • Queries Redis for alice's SSE emitter instance
  • Sends SSE event:

SSE Event (to alice's browser):
  event: engagement
  data: {"score": 0.38, "alertLevel": "RED", "pattern": "rapid_incorrect_submissions"}

Frontend (Next.js):
  eventSource.addEventListener('engagement', (e) => {
    const score = JSON.parse(e.data);
    updateEngagementIndicator(score); // Turn indicator red
  });
```

### 4. Bandit Engine Adjusts Difficulty

```
Flink Decision Context Job:
  • Consumes engagement.scores (alice at 0.38)
  • Enriches with alice's history
  • Produces to decision.context topic

Bandit Engine:
  • Consumes decision.context
  • Sends context to Vertex AI bandit model
  • Receives action: "DIFFICULTY_ADJUST: reduce from 4 to 2"
  • Produces to adapt.actions topic

Kafka (adapt.actions topic)
  Key: "alice"
  Value (Avro):
  {
    "studentId": "alice",
    "actionType": "DIFFICULTY_ADJUST",
    "oldDifficulty": 4,
    "newDifficulty": 2,
    "reason": "LOW_ENGAGEMENT",
    "timestamp": 1704402346000
  }

Realtime Gateway:
  • Consumes adapt.actions
  • Routes to alice's SSE connection via Redis lookup
  • Sends SSE event

SSE Event (to alice's browser):
  event: adapt
  data: {"actionType": "DIFFICULTY_ADJUST", "newDifficulty": 2}

Frontend:
  • Fetches new question at difficulty 2
  • Displays easier content
```

---

## Flink Stream Processing

### Flink Job Architecture

All Flink jobs run on **Confluent Cloud** (not GCP). They are deployed as Flink SQL statements.

### Engagement Analytics Job

**Purpose**: Real-time engagement scoring and pattern detection

**Flink SQL Definition**:
```sql
-- Create source table for quiz answers
CREATE TABLE quiz_answers (
  studentId STRING,
  questionId STRING,
  answer STRING,
  isCorrect BOOLEAN,
  timeSpent BIGINT,
  timestamp BIGINT,
  sessionId STRING,
  event_time AS TO_TIMESTAMP_LTZ(timestamp, 3),
  WATERMARK FOR event_time AS event_time - INTERVAL '5' SECOND
) WITH (
  'connector' = 'kafka',
  'topic' = 'quiz.answers',
  'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
  'scan.startup.mode' = 'latest-offset',
  'format' = 'avro-confluent',
  'avro-confluent.url' = '${SCHEMA_REGISTRY_URL}'
);

-- Create sink table for engagement scores
CREATE TABLE engagement_scores (
  studentId STRING,
  score DOUBLE,
  alertLevel STRING,
  pattern STRING,
  timestamp BIGINT,
  windowStart BIGINT,
  windowEnd BIGINT,
  PRIMARY KEY (studentId) NOT ENFORCED
) WITH (
  'connector' = 'kafka',
  'topic' = 'engagement.scores',
  'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
  'format' = 'avro-confluent',
  'avro-confluent.url' = '${SCHEMA_REGISTRY_URL}'
);

-- Compute engagement scores with 60-second tumbling windows
INSERT INTO engagement_scores
SELECT
  studentId,
  1.0 - (
    0.4 * (1.0 - CAST(SUM(CASE WHEN isCorrect THEN 1 ELSE 0 END) AS DOUBLE) / COUNT(*)) +
    0.3 * (AVG(timeSpent) / 30000.0) +
    0.3 * (COUNT(*) / 10.0)
  ) AS score,
  CASE
    WHEN score < 0.4 THEN 'RED'
    WHEN score < 0.6 THEN 'YELLOW'
    ELSE 'GREEN'
  END AS alertLevel,
  CASE
    WHEN COUNT(*) > 5 AND SUM(CASE WHEN isCorrect THEN 1 ELSE 0 END) = 0 THEN 'rapid_incorrect_submissions'
    WHEN AVG(timeSpent) > 30000 THEN 'prolonged_struggle'
    ELSE 'normal'
  END AS pattern,
  UNIX_TIMESTAMP() * 1000 AS timestamp,
  UNIX_TIMESTAMP(TUMBLE_START(event_time, INTERVAL '60' SECOND)) * 1000 AS windowStart,
  UNIX_TIMESTAMP(TUMBLE_END(event_time, INTERVAL '60' SECOND)) * 1000 AS windowEnd
FROM quiz_answers
GROUP BY TUMBLE(event_time, INTERVAL '60' SECOND), studentId;
```

**Key Features**:
- 60-second tumbling windows per student
- Engagement score formula weights:
  - 40% correctness rate
  - 30% average time spent
  - 30% submission rate
- Pattern detection:
  - Rapid incorrect submissions
  - Prolonged struggle (timeSpent > 30s)
- Outputs: `engagement.scores` topic

### Instructor Metrics Job

**Purpose**: Cohort-level aggregations and heatmap data

**Flink SQL Definition**:
```sql
-- Create sink table for cohort heatmap
CREATE TABLE cohort_heatmap (
  cohortId STRING,
  skillId STRING,
  difficulty INT,
  avgScore DOUBLE,
  studentCount BIGINT,
  timestamp BIGINT,
  PRIMARY KEY (cohortId, skillId, difficulty) NOT ENFORCED
) WITH (
  'connector' = 'kafka',
  'topic' = 'cohort.heatmap',
  'properties.bootstrap.servers' = '${KAFKA_BOOTSTRAP_SERVERS}',
  'format' = 'avro-confluent',
  'avro-confluent.url' = '${SCHEMA_REGISTRY_URL}'
);

-- Compute cohort heatmap with 5-minute sliding windows
INSERT INTO cohort_heatmap
SELECT
  cohortId,
  skillId,
  difficulty,
  AVG(score) AS avgScore,
  COUNT(DISTINCT studentId) AS studentCount,
  UNIX_TIMESTAMP() * 1000 AS timestamp
FROM engagement_scores_enriched -- joined with quiz metadata
GROUP BY HOP(event_time, INTERVAL '1' MINUTE, INTERVAL '5' MINUTE), cohortId, skillId, difficulty;
```

**Key Features**:
- 5-minute sliding windows (1-minute hop)
- Aggregates by cohort, skill, difficulty
- Produces heatmap data for instructor dashboard
- Outputs: `cohort.heatmap` topic

---

## Derived Topics

Flink jobs and microservices produce **derived topics** consumed by the Realtime Gateway:

| Topic Name | Produced By | Key | Schema | Purpose | Consumed By | UI Surface |
|------------|-------------|-----|--------|---------|-------------|------------|
| `engagement.scores` | Flink Engagement Analytics Job | `studentId` | `EngagementScore.avsc` | Real-time engagement metrics per student (score 0.0-1.0, alert level, detected patterns) | Realtime Gateway, Bandit Engine | Student UI (engagement indicator color) |
| `decision.context` | Flink Engagement Analytics Job | `sessionId` | `DecisionContext.avsc` | Enriched context for AI decision-making (student history, current state, performance trends, question difficulty) | Bandit Engine, Tip Service | N/A (internal only) |
| `adapt.actions` | Bandit Engine (Vertex AI) | `studentId` | `AdaptAction.avsc` | AI-driven adaptation actions (difficulty adjust, hint trigger, content change, encouragement) | Realtime Gateway, Content Adapter | Student UI (hints, new questions, difficulty changes) |
| `instructor.tips` | Flink Instructor Metrics Job | `cohortId` or `studentId` | `InstructorTip.avsc` | Coaching suggestions for instructors (struggling students, skill gaps, recommended interventions) | Realtime Gateway | Instructor Dashboard (alerts, recommendations) |
| `cohort.heatmap` | Flink Instructor Metrics Job | `cohortId` | `CohortHeatmap.avsc` | Aggregated cohort performance heatmap data (skill × difficulty matrix with average scores) | Realtime Gateway | Instructor Dashboard (heatmap visualization) |

**Raw Topics** (for reference):

| Topic Name | Produced By | Key | Schema | Purpose |
|------------|-------------|-----|--------|---------|
| `quiz.answers` | Quiz Service | `studentId` | `QuizAnswer.avsc` | Student quiz submissions (answer, correctness, time spent) |
| `session.events` | Quiz Service | `sessionId` | `SessionEvent.avsc` | Student behavioral events (navigation, focus, idle time) |

---

## SSE Service

### Architecture

**Spring Boot Service** (deployed on Cloud Run) with the following components:

1. **Kafka Consumer** (consumes derived topics)
   - `@KafkaListener` for each derived topic
   - Deserializes Avro with Schema Registry
   - Routes messages to SSE router

2. **SSE Router** (Redis-backed routing)
   - Uses Redis to store routing maps:
     - `studentId → {instanceId, emitterId}`
     - `cohortId → [{instanceId, emitterId}, ...]`
   - Thread-safe, stateless, horizontally scalable

3. **SSE Controller** (REST endpoints)
   - `GET /sse/student/{studentId}` - student stream
   - `GET /sse/instructor/{cohortId}` - instructor stream
   - Returns `SseEmitter` with configured timeout
   - Registers connection in Redis on connect
   - Removes connection from Redis on disconnect

### What it Does

✅ **Consumes** derived Kafka topics:
- `engagement.scores`
- `adapt.actions`
- `instructor.tips`
- `cohort.heatmap`

✅ **Routes** messages by routing keys:
- Messages with `studentId` → student SSE streams
- Messages with `cohortId` → instructor SSE streams

✅ **Maintains** persistent SSE connections:
- Heartbeat every 30 seconds
- Auto-reconnect on client disconnect
- Connection lifecycle management
- **Redis-backed routing** for stateless instances

✅ **Pushes** to Next.js clients via SSE:
- JSON payloads
- Event types: `engagement`, `adapt`, `tip`, `heatmap`

### What it Does NOT Do

❌ **NO** stream processing:
- No windowing
- No aggregations
- No joins

❌ **NO** business logic:
- No score calculations
- No decision-making
- No AI calls

❌ **NO** event transformation:
- Messages are passed through as-is
- Only routing, no enrichment

❌ **NO** stateful operations:
- Routing maps in Redis, not in-memory
- No database writes
- No caching beyond routing

### Code Structure (Redis-Backed)

```java
@RestController
public class RealtimeGatewayController {

  @Autowired
  private RedisTemplate<String, String> redisTemplate;

  private final Map<String, SseEmitter> localEmitters = new ConcurrentHashMap<>();
  private final String instanceId = UUID.randomUUID().toString();

  @GetMapping("/sse/student/{studentId}")
  public SseEmitter streamStudent(@PathVariable String studentId) {
    SseEmitter emitter = new SseEmitter(30 * 60 * 1000L); // 30 min timeout
    String emitterId = UUID.randomUUID().toString();

    // Store locally
    localEmitters.put(emitterId, emitter);

    // Register in Redis: studentId → {instanceId, emitterId}
    redisTemplate.opsForHash().put(
      "sse:student:" + studentId,
      "instanceId", instanceId
    );
    redisTemplate.opsForHash().put(
      "sse:student:" + studentId,
      "emitterId", emitterId
    );
    redisTemplate.expire("sse:student:" + studentId, 30, TimeUnit.MINUTES);

    emitter.onCompletion(() -> {
      localEmitters.remove(emitterId);
      redisTemplate.delete("sse:student:" + studentId);
    });

    emitter.onTimeout(() -> {
      localEmitters.remove(emitterId);
      redisTemplate.delete("sse:student:" + studentId);
    });

    return emitter;
  }

  @KafkaListener(topics = "engagement.scores", groupId = "sse-service")
  public void consumeEngagementScores(ConsumerRecord<String, EngagementScore> record) {
    String studentId = record.key();
    EngagementScore score = record.value();

    // Lookup in Redis
    Map<Object, Object> routing = redisTemplate.opsForHash().entries("sse:student:" + studentId);
    if (routing.isEmpty()) return;

    String targetInstanceId = (String) routing.get("instanceId");
    String emitterId = (String) routing.get("emitterId");

    // If this instance owns the connection, send directly
    if (instanceId.equals(targetInstanceId)) {
      SseEmitter emitter = localEmitters.get(emitterId);
      if (emitter != null) {
        try {
          emitter.send(SseEmitter.event()
            .name("engagement")
            .data(score));
        } catch (IOException e) {
          localEmitters.remove(emitterId);
          redisTemplate.delete("sse:student:" + studentId);
        }
      }
    } else {
      // Publish to Redis Pub/Sub for other instances to handle
      redisTemplate.convertAndSend("sse:events:" + targetInstanceId,
        new SseEvent("engagement", studentId, score));
    }
  }
}
```

### Scaling Considerations

**Redis-Backed Routing = Stateless Instances**:
- SSE connections can be on any instance
- Routing maps stored in Redis (shared state)
- Instances coordinate via Redis Pub/Sub
- Horizontally scalable, no session affinity required

**Cloud Run Configuration**:
```yaml
minInstances: 1  # Keep at least 1 warm instance
maxInstances: 10
cpu: 1
memory: 512Mi
```

**Redis (Memorystore) Configuration**:
- **Tier**: Basic (for dev), Standard (for prod, HA)
- **Memory**: 1 GB (supports ~10k concurrent SSE connections)
- **Region**: Same as Cloud Run (us-central1)

**Pub/Sub Pattern**:
- Kafka consumer delivers message to ANY instance
- Instance looks up routing in Redis
- If connection is on DIFFERENT instance:
  - Publish to Redis Pub/Sub channel for target instance
  - Target instance receives and sends to local SSE emitter

---

## Backend Services

### Service Responsibilities

| Service | Responsibility | Kafka Role | AI Integration |
|---------|----------------|------------|----------------|
| **Quiz Service** | HTTP API gateway, event validation, Kafka producer, quiz content management, question CRUD, session management | Producer (raw topics) | Google Gemini (question generation) |
| **Bandit Engine** | Multi-armed bandit difficulty adaptation | Consumer + Producer | Vertex AI (bandit model) |
| **Tip Service** | AI-powered hint generation | Consumer + Producer | Google Gemini (prompt-based) |
| **Content Adapter** | Dynamic content adjustment based on adapt actions | Consumer only | None |
| **Realtime Gateway** | Kafka → SSE fan-out | Consumer only (derived topics) | None |

### Quiz Service

**Purpose**: Unified service combining event ingestion, quiz content management, session handling, and question generation

**Endpoints**:
- `POST /api/quiz/answer/submit` - submit quiz answer and produce to Kafka
- `POST /api/quiz/sessions/start` - start a new quiz session
- `GET /api/quiz/sessions` - list sessions with search criteria
- `GET /api/quiz/sessions/{id}` - get session details
- `POST /api/quiz/questions/generate` - generate questions using Gemini AI
- `GET /api/quiz/questions` - list questions with filtering
- `POST /api/topics` - create topic
- `GET /api/topics` - list topics
- `POST /api/students` - create student
- `GET /api/students/{name}` - get student by name

**Core Capabilities**:
1. **Event Ingestion**: Validates quiz submissions and produces Avro messages to Kafka
2. **Content Management**: CRUD operations for topics, questions, and students (PostgreSQL)
3. **Session Management**: Creates and tracks quiz sessions
4. **Question Generation**: AI-powered question generation using Vertex AI Gemini

**Kafka Producer Config**:
```yaml
spring:
  kafka:
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: io.confluent.kafka.serializers.KafkaAvroSerializer
      properties:
        schema.registry.url: ${SCHEMA_REGISTRY_URL}
        basic.auth.credentials.source: USER_INFO
        basic.auth.user.info: ${SCHEMA_REGISTRY_API_KEY}:${SCHEMA_REGISTRY_API_SECRET}
      acks: all  # Wait for all replicas
      retries: 3
```

### Bandit Engine

**Purpose**: AI-driven difficulty adaptation using Vertex AI

**Kafka Consumer**:
- Consumes `decision.context` topic
- Deserializes Avro `DecisionContext` messages

**Vertex AI Integration**:
- Multi-armed bandit model trained on historical data
- Input features: engagement score, correctness rate, time spent, difficulty level
- Output: recommended difficulty adjustment (-2, -1, 0, +1, +2)

**Kafka Producer**:
- Produces `adapt.actions` topic
- Serializes Avro `AdaptAction` messages

**Fallback Strategy**:
- If Vertex AI times out (>500ms), use rule-based fallback
- Rule: If engagement < 0.4, reduce difficulty by 1

### Tip Service

**Purpose**: AI-powered hint generation using Google Gemini

**Kafka Consumer**:
- Consumes `decision.context` topic (same as Bandit Engine)

**Gemini Integration**:
- Uses Gemini 2.0 Flash for fast inference (<300ms)
- Prompt template includes: question text, student's incorrect answer, skill metadata
- Output: contextual hint (1-2 sentences)

**Kafka Producer**:
- Produces `adapt.actions` topic (actionType: `SHOW_HINT`)

---

## Schema Governance with Avro

### Schema Registry Strategy

**Compatibility Mode**: `BACKWARD` (default)
- New schemas can read old data
- Allows adding optional fields
- Prevents breaking existing consumers

**Schema Versioning**:
- Each schema change creates a new version
- Consumers auto-upgrade to latest schema
- Producers must use compatible schemas

### Example Avro Schema

**QuizAnswer.avsc**:
```json
{
  "type": "record",
  "name": "QuizAnswer",
  "namespace": "xyz.catuns.edupulse.avro",
  "fields": [
    {"name": "studentId", "type": "string"},
    {"name": "questionId", "type": "string"},
    {"name": "answer", "type": "string"},
    {"name": "isCorrect", "type": "boolean"},
    {"name": "timeSpent", "type": "long"},
    {"name": "timestamp", "type": "long"},
    {"name": "sessionId", "type": "string"},
    {"name": "metadata", "type": ["null", "string"], "default": null}
  ]
}
```

**EngagementScore.avsc**:
```json
{
  "type": "record",
  "name": "EngagementScore",
  "namespace": "xyz.catuns.edupulse.avro",
  "fields": [
    {"name": "studentId", "type": "string"},
    {"name": "score", "type": "double"},
    {"name": "alertLevel", "type": {"type": "enum", "name": "AlertLevel", "symbols": ["GREEN", "YELLOW", "RED"]}},
    {"name": "pattern", "type": ["null", "string"], "default": null},
    {"name": "timestamp", "type": "long"},
    {"name": "windowStart", "type": "long"},
    {"name": "windowEnd", "type": "long"}
  ]
}
```

### Schema Evolution Example

**Adding optional field to QuizAnswer**:
```json
{
  "fields": [
    // ... existing fields
    {"name": "difficulty", "type": ["null", "int"], "default": null}  // NEW optional field
  ]
}
```

**BACKWARD compatible**: Old consumers can still read new messages (ignore new field).

---

## AI/ML Integration

### Vertex AI Multi-Armed Bandit

**Model Type**: Contextual multi-armed bandit

**Arms**: 5 difficulty levels (1 = easiest, 5 = hardest)

**Context Features** (input to model):
- Student engagement score (0.0-1.0)
- Correctness rate (last 10 questions)
- Average time spent per question
- Current difficulty level
- Skill metadata (topic, subtopic)

**Reward Signal** (training):
- +1 if student answers correctly AND engagement stays high
- 0 if student answers correctly but engagement drops
- -1 if student answers incorrectly

**Inference**:
- Input: `DecisionContext` from Flink
- Output: Recommended difficulty adjustment
- Latency: ~187ms (p50), ~350ms (p99)

**Deployment**:
- Hosted on Vertex AI Endpoint
- Auto-scaling: 1-3 replicas
- Machine type: `n1-standard-4`

### Google Gemini Hint Generation

**Model**: `gemini-2.0-flash-exp` (fast, low-latency)

**Prompt Template**:
```
You are a helpful tutor. A student is struggling with this question:

Question: {questionText}
Student's incorrect answer: {studentAnswer}
Skill: {skillName}

Provide a brief hint (1-2 sentences) to guide the student without giving away the answer.
```

**Inference**:
- Latency: ~250ms (p50), ~500ms (p99)
- Temperature: 0.7 (balanced creativity)
- Max tokens: 100

**Fallback**:
- If Gemini times out, use pre-generated hints from database

---

## Scalability & Performance

### Kafka Topics Partitioning

| Topic | Partitions | Key Strategy | Rationale |
|-------|-----------|--------------|-----------|
| `quiz.answers` | 6 | `studentId` | Even distribution, student affinity |
| `session.events` | 6 | `sessionId` | Session affinity for ordering |
| `engagement.scores` | 6 | `studentId` | Student affinity, parallel processing |
| `adapt.actions` | 6 | `studentId` | Student affinity for ordering |
| `instructor.tips` | 3 | `cohortId` | Cohort affinity, lower volume |
| `cohort.heatmap` | 3 | `cohortId` | Cohort affinity, lower volume |

### Flink Parallelism

**Confluent Cloud Flink**:
- Compute Pool: 10 CFUs (Confluent Flink Units)
- Auto-scaling based on lag
- Parallelism: 6 (matches topic partitions)

### Cloud Run Auto-Scaling

| Service | Min | Max | Target CPU | Target Concurrency |
|---------|-----|-----|------------|-------------------|
| quiz-service | 0 | 10 | 70% | 100 |
| bandit-engine | 0 | 5 | 70% | 50 |
| tip-service | 0 | 5 | 70% | 50 |
| sse-service | 1 | 10 | 70% | 100 (SSE connections) |

### Performance Targets

| Metric | Target | Actual (Demo) |
|--------|--------|---------------|
| Event ingestion latency (HTTP → Kafka) | <50ms | ~35ms (p99) |
| Flink processing latency (Kafka → Kafka) | <500ms | ~280ms (p99) |
| SSE delivery latency (Kafka → Browser) | <100ms | ~65ms (p99) |
| **End-to-end latency (HTTP → Browser)** | **<1s** | **~450ms (p99)** |
| Vertex AI inference latency | <500ms | ~187ms (p50) |
| Gemini inference latency | <500ms | ~250ms (p50) |

### Redis Scaling

**Memorystore (Redis) Capacity**:
- **1 GB**: ~10,000 concurrent SSE connections
- **5 GB**: ~50,000 concurrent SSE connections
- **Standard tier**: Automatic failover, 99.9% SLA

**Connection Estimate**:
- SSE connection metadata: ~100 bytes/connection
- 10,000 connections = ~1 MB in Redis
- Plenty of headroom for routing data

---

## Deployment Architecture

### Confluent Cloud (Managed)

- **Kafka Cluster**: Standard tier, 3 availability zones
- **Schema Registry**: Managed, BACKWARD compatibility
- **Flink Compute Pool**: 10 CFUs, auto-scaling

### Google Cloud Platform

- **Cloud Run**: Serverless containers for all microservices
- **Artifact Registry**: Container image storage
- **Secret Manager**: Kafka credentials, API keys
- **Vertex AI**: Bandit model endpoint
- **Memorystore (Redis)**: SSE routing maps
- **Cloud SQL**: PostgreSQL for quiz service (optional)

### Networking

- **Cloud Run → Confluent Cloud**: HTTPS with TLS 1.2+, SASL/PLAIN authentication
- **Cloud Run → Vertex AI**: Private Google network
- **Cloud Run → Memorystore**: VPC connector (private IP)
- **Cloud Run → Frontend**: HTTPS with CORS

---

**Last Updated**: 2026-01-14
**Architecture Version**: 2.1 (Quiz Service consolidation)
