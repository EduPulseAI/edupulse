# EduPulse Architecture - Flink Refactor

This document contains the updated architecture sections for README.md after replacing BigQuery with Apache Flink.

---

## 1. Refactor Summary

### What Was Removed

- **BigQuery** analytics sink and all related infrastructure
- BigQuery datasets, tables, and query logic for analytics/replay
- Kafka → BigQuery connector configurations
- BigQuery-specific GCP setup in Cloud & Infrastructure section
- **Kafka Streams** processing in Engagement Service (replaced with Flink)

### What Was Added

- **Apache Flink** as the primary stream processing engine
- **2 Flink Jobs** for real-time analytics:
  - Engagement Analytics Job (windowed metrics, pattern detection)
  - Instructor Metrics Job (cohort aggregates, heatmap data)
- Flink state management and checkpointing configuration
- Flink deployment guidance (Docker Compose for local, Confluent Cloud Flink option)

### What Changed in Dataflow

**Before (with BigQuery + Kafka Streams):**
```
Frontend → Event Ingest → Kafka → Kafka Streams Service → Kafka → Gateway → UI
                                 ↘ BigQuery (analytics sink)
```

**After (with Flink):**
```
Frontend → Event Ingest → Kafka → Flink Jobs → Kafka → Gateway → UI
                                 ↗ (enrichment from Kafka topics)
```

**Key Changes:**
- Engagement Service (Kafka Streams) → Engagement Analytics Flink Job
- All analytics now flow through Flink → back to Kafka (Kafka remains system of record)
- No external analytics warehouse; Kafka topic retention is the replay strategy
- Spring Boot services remain thin orchestrators (API, AI calls, event emission)

---

## 2. Updated Technology Stack

Replace the Technology Stack section in README.md:

**Technology Stack:**
- **Backend:** Spring Boot 3.2, Java 17
- **Stream Processing:** Apache Flink 1.18+
- **Frontend:** Next.js 14, React 18, TypeScript
- **Messaging:** Confluent Kafka, Schema Registry, Avro
- **AI/ML:** Vertex AI, Google Gemini
- **Data:** PostgreSQL, Redis
- **Deployment:** Docker, Google Cloud (GKE, Cloud SQL, Memorystore), Confluent Cloud

---

## 3. Updated Architecture Diagram

Replace the Architecture section in README.md (lines 42-67):

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

**Data Flow:**

1. **Student Interaction:**
   - Student submits answer → Event Ingest Service → `quiz.answers` topic
   - Session events (navigation, dwell) → `session.events` topic

2. **Flink Real-Time Processing:**
   - **Engagement Analytics Job** consumes `quiz.answers` + `session.events`
   - Computes windowed engagement scores, detects patterns
   - Produces to `engagement.scores` topic

3. **AI-Driven Adaptation:**
   - Bandit Engine consumes `engagement.scores` (filter: alertThresholdCrossed)
   - Calls Vertex AI for difficulty selection
   - Produces to `adapt.actions` topic

4. **Instructor Insights:**
   - **Instructor Metrics Job** consumes `engagement.scores` + `quiz.answers`
   - Computes cohort aggregates, skill struggle metrics
   - Produces to `cohort.metrics` and `instructor.tips` topics
   - Tip Service enriches tips with Gemini-generated coaching advice

5. **Real-Time Updates:**
   - Realtime Gateway consumes `adapt.actions`, `instructor.tips`, `cohort.metrics`
   - Pushes to connected WebSocket/SSE clients (students, instructors)

---

## 4. Flink Job Specifications

### Job 1: Engagement Analytics Job

| **Aspect** | **Details** |
|------------|-------------|
| **Job Name** | `engagement-analytics-job` |
| **Purpose** | Compute real-time engagement scores, detect disengagement patterns, trigger alerts |
| **Input Topics** | `quiz.answers`, `session.events` |
| **Output Topics** | `engagement.scores` |
| **Keying Strategy** | Keyed by `studentId` for stateful aggregation |
| **Windowing Strategy** | Tumbling window: 60 seconds (aligned with original design) |
| **State Kept** | Per-student aggregation state: <br>• Total attempts in window<br>• Correct/incorrect counts<br>• Dwell time accumulator<br>• Question IDs seen<br>• Last 3 answer timestamps (for pacing)<br>State TTL: 10 minutes |
| **Joins/Enrichment** | Left join with question metadata (from compacted `content.questions` topic) to get difficulty level, skill tags |
| **Pattern Detection** | CEP patterns:<br>• **Rapid Guessing:** 3+ answers in <15s with <40% accuracy<br>• **Engagement Collapse:** Score drops >0.3 within 2 consecutive windows<br>• **Idle Spike:** >120s gap between answers (session.events dwell timeout) |
| **Scoring Formula** | `score = 0.3 * dwellScore + 0.4 * accuracyScore + 0.3 * pacingScore`<br>Alert threshold: `score < 0.4 && trend == DECLINING` |
| **Delivery Guarantees** | Exactly-once (Flink checkpointing + Kafka transactional producer) |
| **Checkpoint Interval** | 60 seconds (aligned with window size) |

**Output Schema (`engagement.scores-value`):**
```json
{
  "studentId": "s123",
  "sessionId": "sess_abc",
  "score": 0.38,
  "trend": "DECLINING",
  "alertThresholdCrossed": true,
  "windowStart": 1704067200000,
  "windowEnd": 1704067260000,
  "metrics": {
    "dwellScore": 0.42,
    "accuracyScore": 0.31,
    "pacingScore": 0.41,
    "totalAttempts": 5,
    "correctCount": 2
  },
  "detectedPatterns": ["RAPID_GUESSING"]
}
```

---

### Job 2: Instructor Metrics Job

| **Aspect** | **Details** |
|------------|-------------|
| **Job Name** | `instructor-metrics-job` |
| **Purpose** | Aggregate cohort-level metrics, generate heatmap data, detect skill-level struggles |
| **Input Topics** | `engagement.scores`, `quiz.answers` |
| **Output Topics** | `cohort.metrics`, `instructor.tips` |
| **Keying Strategy** | Multi-key:<br>• `cohortId` for aggregate metrics<br>• `skillTag` for skill-level insights<br>• `sessionId` for session-scoped tips |
| **Windowing Strategy** | Sliding window: 5 minutes, slide 1 minute (for smooth updates) |
| **State Kept** | Per-cohort/skill aggregation state:<br>• Student count by engagement band (high/medium/low)<br>• Skill tag → struggle count map<br>• Recent tip emission timestamps (for rate limiting)<br>State TTL: 30 minutes |
| **Joins/Enrichment** | Join `engagement.scores` with `quiz.answers` on `studentId` + `timestamp` to correlate low scores with specific question difficulties and skill tags |
| **Pattern Detection** | Cohort patterns:<br>• **Mass Struggle:** >50% of cohort with score <0.5 on same skill<br>• **Skill Bottleneck:** >3 students failing same question in <2 minutes<br>Output triggers tip generation (consumed by Tip Service) |
| **Delivery Guarantees** | At-least-once (acceptable for dashboard metrics; idempotent consumption in Gateway) |
| **Checkpoint Interval** | 30 seconds |

**Output Schema (`cohort.metrics-value`):**
```json
{
  "cohortId": "cohort_101",
  "sessionId": "sess_abc",
  "windowStart": 1704067200000,
  "windowEnd": 1704067500000,
  "engagementDistribution": {
    "high": 8,
    "medium": 12,
    "low": 5
  },
  "skillStruggles": {
    "linear-equations": 7,
    "quadratic-formula": 3
  },
  "avgEngagementScore": 0.58,
  "alertingStudents": ["s123", "s456"]
}
```

**Output Schema (`instructor.tips-value`):**
```json
{
  "sessionId": "sess_abc",
  "instructorId": "instructor_1",
  "tipType": "SKILL_STRUGGLE",
  "priority": "HIGH",
  "context": {
    "skillTag": "linear-equations",
    "affectedStudents": ["s123", "s124"],
    "strugglingCount": 7
  },
  "generatedTip": null,  // Enriched by Tip Service (Gemini)
  "timestamp": 1704067260000
}
```

---

## 5. Updated End-to-End Dataflows

### Flow 1: Student Answer → Engagement Score → Adapt Action → UI Update

```
1. Student submits answer
   ↓
2. Frontend → POST /api/quiz/submit-answer
   ↓
3. Event Ingest Service validates, produces to Kafka
   → Topic: quiz.answers (Avro, key: studentId)
   ↓
4. Flink Engagement Analytics Job consumes quiz.answers
   • Aggregates in 60s tumbling window (keyed by studentId)
   • Joins with content.questions (difficulty, skill tags)
   • Detects patterns (rapid guessing, engagement collapse)
   • Computes engagement score
   ↓
5. Flink produces to engagement.scores (Avro)
   • score < 0.4 && trend = DECLINING → alertThresholdCrossed = true
   ↓
6. Bandit Engine consumes engagement.scores (filter: alertThresholdCrossed)
   • Fetches student context from PostgreSQL
   • Calls Vertex AI with feature vector
   • Receives difficulty recommendation (arm selection)
   ↓
7. Bandit Engine produces to adapt.actions (Avro)
   → actionType: DIFFICULTY_ADJUST, newDifficulty: 2
   ↓
8. Content Adapter consumes adapt.actions
   • Queries PostgreSQL for question at new difficulty
   • Enriches adapt.actions with question data
   • Produces enriched event back to adapt.actions
   ↓
9. Realtime Gateway consumes adapt.actions
   • Routes to student's WebSocket session
   ↓
10. Frontend receives real-time update
    • Displays new (easier) question
    • Updates UI engagement indicator
```

---

### Flow 2: Hint Request → Hint Response → UI Update

```
1. Student clicks "Need Help" button
   ↓
2. Frontend → POST /api/quiz/request-hint
   ↓
3. Event Ingest Service produces to session.events
   → Topic: session.events (eventType: HINT_REQUESTED)
   ↓
4. Tip Service consumes session.events (filter: HINT_REQUESTED)
   • Rate limit check (Redis: 1 hint per student per 2 min)
   • Fetches recent quiz.answers for context
   • Calls Gemini API with student context
   ↓
5. Tip Service produces to adapt.actions
   → actionType: HINT_PROVIDED, hintContent: "Try isolating x..."
   ↓
6. Realtime Gateway consumes adapt.actions
   • Routes to student's WebSocket session
   ↓
7. Frontend displays hint in modal
```

---

### Flow 3: Instructor Intervention → Adapt Action → UI Update

```
1. Instructor clicks "Send Encouragement" for struggling student in dashboard
   ↓
2. Frontend → POST /api/instructor/intervene
   ↓
3. Event Ingest Service produces to adapt.actions
   → actionType: INSTRUCTOR_MESSAGE, studentId: s123, message: "..."
   ↓
4. Realtime Gateway consumes adapt.actions
   • Routes to student's WebSocket session
   ↓
5. Student UI displays instructor message banner
```

---

### Flow 4: Cohort Metrics → Instructor Dashboard Heatmap

```
1. Flink Instructor Metrics Job processes engagement.scores stream
   • 5-minute sliding window, keyed by cohortId
   • Aggregates engagement distribution (high/medium/low counts)
   • Detects skill struggles (>50% cohort low on same skill)
   ↓
2. Flink produces to cohort.metrics (Avro)
   ↓
3. Realtime Gateway consumes cohort.metrics
   • Routes to instructor's WebSocket session (filtered by sessionId)
   ↓
4. Instructor Dashboard updates heatmap
   • Student tiles color-coded by engagement band
   • Skill struggle badges on affected tiles
```

---

## 6. Updated Backend Services Section

Replace the Engagement Service section (lines 388-506 in README.md) with:

### Apache Flink Stream Processing

**Purpose:** Real-time streaming analytics for engagement scoring, pattern detection, and instructor metrics

**Deployment:** Flink cluster (Docker Compose locally, Confluent Cloud Flink for production)

**Jobs:**

#### Engagement Analytics Job

**Responsibilities:**
- Consume quiz answers and session events from Kafka
- Compute windowed engagement scores (60-second tumbling windows)
- Detect disengagement patterns (rapid guessing, engagement collapse, idle spikes)
- Trigger alerts when engagement score < 0.4
- Produce engagement scores back to Kafka

**Kafka Topics:**
- **Consumes from:** `quiz.answers`, `session.events`, `content.questions` (compacted, for enrichment)
- **Produces to:** `engagement.scores`

**Processing Model:**

Uses Flink DataStream API with keyed state:

```java
DataStream<QuizAnswer> quizAnswers = env
    .addSource(new FlinkKafkaConsumer<>("quiz.answers", avroSchema, kafkaProps))
    .keyBy(QuizAnswer::getStudentId);

DataStream<SessionEvent> sessionEvents = env
    .addSource(new FlinkKafkaConsumer<>("session.events", avroSchema, kafkaProps))
    .keyBy(SessionEvent::getStudentId);

// Join streams
DataStream<StudentActivity> joined = quizAnswers
    .connect(sessionEvents)
    .flatMap(new StudentActivityJoiner());

// Window and aggregate
DataStream<EngagementScore> scores = joined
    .keyBy(activity -> activity.getStudentId())
    .window(TumblingEventTimeWindows.of(Time.seconds(60)))
    .aggregate(new EngagementAggregator());

// Pattern detection (CEP)
PatternStream<StudentActivity> patterns = CEP.pattern(
    joined.keyBy(StudentActivity::getStudentId),
    Pattern.<StudentActivity>begin("rapid")
        .where(a -> a.getTimeSpent() < 15000)
        .times(3).within(Time.seconds(15))
);

// Produce results
scores.addSink(new FlinkKafkaProducer<>("engagement.scores", avroSchema, kafkaProps));
```

**Scoring Formula:**

```
score = 0.3 * dwellScore + 0.4 * accuracyScore + 0.3 * pacingScore

dwellScore = 1 - min(|actual_time - expected_time| / expected_time, 1.0)
accuracyScore = correct_answers / total_attempts
pacingScore = min(questions_per_minute / baseline_pace, 1.0)

alertThresholdCrossed = (score < 0.4 && trend == DECLINING)
```

**State Management:**
- State backend: RocksDB (for large state, disk-spillable)
- Checkpoint interval: 60 seconds
- State TTL: 10 minutes (cleanup old student states)

**Environment Variables:**

```bash
# Flink
FLINK_PROPERTIES="
  jobmanager.rpc.address: jobmanager
  taskmanager.numberOfTaskSlots: 4
  state.backend: rocksdb
  state.checkpoints.dir: file:///opt/flink/checkpoints
  execution.checkpointing.interval: 60000
"

# Kafka
KAFKA_BOOTSTRAP_SERVERS=pkc-xxxxx.us-east-1.aws.confluent.cloud:9092
KAFKA_PROPERTIES="
  security.protocol=SASL_SSL
  sasl.mechanism=PLAIN
  sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username='${KAFKA_API_KEY}' password='${KAFKA_API_SECRET}';
"

# Schema Registry
SCHEMA_REGISTRY_URL=https://psrc-xxxxx.us-east-1.aws.confluent.cloud
SCHEMA_REGISTRY_PROPERTIES="
  basic.auth.credentials.source=USER_INFO
  basic.auth.user.info=${SCHEMA_REGISTRY_KEY}:${SCHEMA_REGISTRY_SECRET}
"
```

**Local Setup (Docker Compose):**

```bash
# Start Flink cluster
docker-compose up -d jobmanager taskmanager

# Submit Engagement Analytics Job
docker exec -it jobmanager flink run \
  -c com.edupulse.flink.EngagementAnalyticsJob \
  /opt/flink/jobs/engagement-analytics.jar

# Monitor job
docker exec -it jobmanager flink list
```

**Health Check:**

```bash
# Flink UI
open http://localhost:8081

# Check running jobs
curl http://localhost:8081/jobs

# Check checkpoint statistics
curl http://localhost:8081/jobs/<job-id>/checkpoints
```

**Monitoring:**

```bash
# Check backpressure
curl http://localhost:8081/jobs/<job-id>/vertices/<vertex-id>/backpressure

# View Kafka consumer lag
kafka-consumer-groups --bootstrap-server <broker> \
  --group engagement-analytics-job --describe
```

---

#### Instructor Metrics Job

**Responsibilities:**
- Aggregate cohort-level engagement metrics
- Generate heatmap data for instructor dashboard
- Detect skill-level struggles across cohorts
- Emit tip triggers for Gemini enrichment

**Kafka Topics:**
- **Consumes from:** `engagement.scores`, `quiz.answers`
- **Produces to:** `cohort.metrics`, `instructor.tips`

**Processing Model:**

```java
DataStream<EngagementScore> scores = env
    .addSource(new FlinkKafkaConsumer<>("engagement.scores", avroSchema, kafkaProps));

// Cohort aggregates (keyed by cohortId)
scores
    .keyBy(score -> getCohortId(score.getSessionId()))
    .window(SlidingEventTimeWindows.of(Time.minutes(5), Time.minutes(1)))
    .aggregate(new CohortMetricsAggregator())
    .addSink(new FlinkKafkaProducer<>("cohort.metrics", avroSchema, kafkaProps));

// Skill struggle detection (keyed by skillTag)
DataStream<QuizAnswer> answers = env
    .addSource(new FlinkKafkaConsumer<>("quiz.answers", avroSchema, kafkaProps));

scores
    .join(answers)
    .where(EngagementScore::getStudentId)
    .equalTo(QuizAnswer::getStudentId)
    .window(TumblingEventTimeWindows.of(Time.minutes(2)))
    .apply(new SkillStruggleDetector())
    .filter(tip -> tip.getPriority().equals("HIGH"))
    .addSink(new FlinkKafkaProducer<>("instructor.tips", avroSchema, kafkaProps));
```

**Environment Variables:** (Same as Engagement Analytics Job)

**Local Setup:**

```bash
# Submit Instructor Metrics Job
docker exec -it jobmanager flink run \
  -c com.edupulse.flink.InstructorMetricsJob \
  /opt/flink/jobs/instructor-metrics.jar
```

---

## 7. Updated Topic and Schema Plan

### Topic Inventory

| **Topic** | **Purpose** | **Partitions** | **Retention** | **Cleanup Policy** | **Key** | **Value Schema Subject** |
|-----------|-------------|----------------|---------------|-----------------------|---------|--------------------------|
| `session.events` | Student navigation, dwell time, UI events | 6 | 7 days | delete | studentId (String) | `session.events-value` |
| `quiz.answers` | Quiz answer submissions | 6 | 7 days | delete | studentId (String) | `quiz.answers-value` |
| `engagement.scores` | Windowed engagement metrics from Flink | 6 | 7 days | delete | studentId (String) | `engagement.scores-value` |
| `adapt.actions` | AI-driven adaptation actions (difficulty, hints) | 6 | 7 days | delete | studentId (String) | `adapt.actions-value` |
| `instructor.tips` | Coaching tips and alerts for instructors | 3 | 7 days | delete | sessionId (String) | `instructor.tips-value` |
| `cohort.metrics` | Cohort-level aggregates for dashboards | 3 | 2 days | delete | cohortId (String) | `cohort.metrics-value` |
| `content.questions` | Question metadata (difficulty, skills) - compacted | 3 | Infinite | compact | questionId (String) | `content.questions-value` |

**New Topics Added:**
- `cohort.metrics`: Aggregated metrics from Flink Instructor Metrics Job
- `content.questions`: Compacted topic for enrichment joins in Flink (side input)

---

### Schema Registry Subjects

| **Subject** | **Record Name** | **Namespace** | **Compatibility** | **Purpose** |
|-------------|-----------------|---------------|-------------------|-------------|
| `session.events-value` | SessionEvent | com.edupulse.events | BACKWARD | Student interaction events |
| `quiz.answers-value` | QuizAnswer | com.edupulse.events | BACKWARD | Answer submissions |
| `engagement.scores-value` | EngagementScore | com.edupulse.metrics | BACKWARD | Flink-computed scores |
| `adapt.actions-value` | AdaptAction | com.edupulse.actions | BACKWARD | Adaptation decisions |
| `instructor.tips-value` | InstructorTip | com.edupulse.tips | BACKWARD | Coaching suggestions |
| `cohort.metrics-value` | CohortMetrics | com.edupulse.metrics | BACKWARD | Dashboard aggregates |
| `content.questions-value` | QuestionMetadata | com.edupulse.content | BACKWARD | Question enrichment data |

---

### Schema Evolution Examples

#### Safe Field Addition (BACKWARD compatible)

**Original schema (engagement.scores-value v1):**
```json
{
  "namespace": "com.edupulse.metrics",
  "type": "record",
  "name": "EngagementScore",
  "fields": [
    {"name": "studentId", "type": "string"},
    {"name": "score", "type": "double"},
    {"name": "timestamp", "type": "long", "logicalType": "timestamp-millis"}
  ]
}
```

**Evolved schema (v2) - adding optional field with default:**
```json
{
  "namespace": "com.edupulse.metrics",
  "type": "record",
  "name": "EngagementScore",
  "fields": [
    {"name": "studentId", "type": "string"},
    {"name": "score", "type": "double"},
    {"name": "timestamp", "type": "long", "logicalType": "timestamp-millis"},
    {"name": "detectedPatterns", "type": {"type": "array", "items": "string"}, "default": []}
  ]
}
```

**Why it works:** Old consumers ignore the new field; new consumers get empty array for old messages.

---

#### Breaking Change Avoided

**Bad approach (BREAKS old consumers):**
```json
// Renaming field from "score" to "engagementScore"
{"name": "engagementScore", "type": "double"}  // Old consumers expect "score"
```

**Correct approach:**
```json
// Add new field, deprecate old one, but keep both for transition period
{"name": "score", "type": "double"},  // Keep for BACKWARD compatibility
{"name": "engagementScore", "type": "double", "default": 0.0}  // New field
```

**Migration path:**
1. Deploy producers writing both fields (v2 schema)
2. Update consumers to read `engagementScore` (still compatible with v1)
3. After all consumers updated, remove deprecated `score` field (v3 schema with FORWARD compatibility check)

---

### DLQ (Dead Letter Queue) Strategy

**Approach:** Separate DLQ topics for each primary topic with deserialization or processing failures.

| **Primary Topic** | **DLQ Topic** | **Retention** | **Purpose** |
|-------------------|---------------|---------------|-------------|
| `quiz.answers` | `quiz.answers.dlq` | 14 days | Schema violations, malformed events |
| `session.events` | `session.events.dlq` | 14 days | Schema violations, malformed events |
| `engagement.scores` | `engagement.scores.dlq` | 7 days | Flink processing errors (rare with exactly-once) |

**DLQ Message Schema:**
```json
{
  "namespace": "com.edupulse.dlq",
  "type": "record",
  "name": "DLQMessage",
  "fields": [
    {"name": "topic", "type": "string"},
    {"name": "partition", "type": "int"},
    {"name": "offset", "type": "long"},
    {"name": "key", "type": ["null", "bytes"]},
    {"name": "value", "type": "bytes"},
    {"name": "errorType", "type": "string"},
    {"name": "errorMessage", "type": "string"},
    {"name": "timestamp", "type": "long", "logicalType": "timestamp-millis"}
  ]
}
```

**Flink DLQ Handling:**
```java
// In Flink deserializer
public void deserialize(ConsumerRecord<byte[], byte[]> record) {
    try {
        return avroDeserializer.deserialize(record.value());
    } catch (SerializationException e) {
        dlqProducer.send(new ProducerRecord<>(
            record.topic() + ".dlq",
            createDLQMessage(record, e)
        ));
        return null; // Filter out
    }
}
```

---

## 8. Operational Plan

### Deployment Choice: Docker Compose (Local) + Confluent Cloud Flink (Production)

**Rationale:**
- **Hackathon demo:** Docker Compose provides reliable local Flink cluster (no network dependencies during demo)
- **Production readiness:** Confluent Cloud Flink offers managed service (no ops burden for state/checkpoints)
- **Fallback:** If Confluent Cloud Flink unavailable, can deploy to GKE with Flink Kubernetes Operator

---

### Local Development (Docker Compose)

**docker-compose.yml additions:**

```yaml
services:
  jobmanager:
    image: flink:1.18-scala_2.12-java11
    ports:
      - "8081:8081"
    command: jobmanager
    environment:
      - |
        FLINK_PROPERTIES=
        jobmanager.rpc.address: jobmanager
        state.backend: rocksdb
        state.checkpoints.dir: file:///opt/flink/checkpoints
        state.savepoints.dir: file:///opt/flink/savepoints
        execution.checkpointing.interval: 60000
        execution.checkpointing.mode: EXACTLY_ONCE
    volumes:
      - flink-checkpoints:/opt/flink/checkpoints
      - flink-savepoints:/opt/flink/savepoints
      - ./backend/flink-jobs/target:/opt/flink/jobs
    networks:
      - kafka-net

  taskmanager:
    image: flink:1.18-scala_2.12-java11
    depends_on:
      - jobmanager
    command: taskmanager
    scale: 2
    environment:
      - |
        FLINK_PROPERTIES=
        jobmanager.rpc.address: jobmanager
        taskmanager.numberOfTaskSlots: 4
        state.backend: rocksdb
    volumes:
      - flink-checkpoints:/opt/flink/checkpoints
    networks:
      - kafka-net

volumes:
  flink-checkpoints:
  flink-savepoints:
```

**Start local Flink cluster:**
```bash
cd infra
docker-compose up -d jobmanager taskmanager

# Wait for cluster to be ready
sleep 10

# Submit jobs
docker exec jobmanager flink run \
  /opt/flink/jobs/engagement-analytics-job.jar

docker exec jobmanager flink run \
  /opt/flink/jobs/instructor-metrics-job.jar
```

---

### Checkpoint and State Strategy

**Configuration:**

| **Setting** | **Value** | **Rationale** |
|-------------|-----------|---------------|
| **Checkpoint Interval** | 60 seconds | Aligns with engagement window; balances latency vs overhead |
| **Checkpointing Mode** | EXACTLY_ONCE | Critical for accurate engagement scoring (no duplicate scores) |
| **State Backend** | RocksDB | Handles large keyed state (thousands of students); disk-spillable |
| **Checkpoint Storage** | Local filesystem (demo)<br>GCS (production) | Demo: `/opt/flink/checkpoints`<br>Prod: `gs://edupulse-flink-state/` |
| **State TTL** | Engagement: 10 min<br>Instructor: 30 min | Cleanup inactive students; prevent unbounded state growth |
| **Min Pause Between Checkpoints** | 30 seconds | Prevent checkpoint storms during high load |
| **Checkpoint Timeout** | 5 minutes | Fail checkpoint if taking too long (indicates backpressure) |

**RocksDB Tuning (production):**
```yaml
state.backend.rocksdb.predefined-options: SPINNING_DISK_OPTIMIZED
state.backend.rocksdb.block.cache-size: 512mb
state.backend.rocksdb.thread.num: 4
```

---

### Monitoring Signals

**Key Metrics to Watch:**

| **Metric** | **Threshold** | **Action** |
|------------|---------------|------------|
| **Checkpoint Duration** | >30 seconds | Investigate state size growth; consider scaling |
| **Checkpoint Failures** | >2 in 10 min | Check Kafka connectivity, state backend health |
| **Backpressure** | >50% busy time | Scale taskmanagers, increase parallelism |
| **Kafka Consumer Lag** | >5000 records | Check if Flink is keeping up; may need more task slots |
| **State Size Growth** | >10 GB per operator | Review TTL settings, check for state leak |
| **Records Out** | <10/sec for >2 min | Check if source topics have data; windowing issues |

**Monitoring Tools:**

1. **Flink Web UI (http://localhost:8081):**
   - Running jobs, task status
   - Checkpoint history and failures
   - Backpressure visualization

2. **Prometheus + Grafana (optional for production):**
   ```bash
   # Flink exposes metrics at :9249/metrics
   # Add Prometheus scrape config:
   - job_name: 'flink'
     static_configs:
       - targets: ['jobmanager:9249', 'taskmanager:9249']
   ```

3. **Kafka Consumer Group Monitoring:**
   ```bash
   kafka-consumer-groups --bootstrap-server localhost:9092 \
     --group engagement-analytics-job \
     --describe
   ```

4. **Confluent Cloud Metrics (if using Confluent Cloud Flink):**
   - Built-in job monitoring
   - Checkpoint metrics
   - Connector health

---

### Confluent Cloud Flink Deployment (Production Path)

**Prerequisites:**
- Confluent Cloud account with Flink enabled
- Kafka cluster in Confluent Cloud
- Schema Registry configured

**Deployment Steps:**

```bash
# 1. Package Flink job JAR
cd backend/flink-jobs
mvn clean package

# 2. Upload to Confluent Cloud Flink (via UI or API)
# Navigate to: Confluent Cloud → Flink → Create Compute Pool

# 3. Submit job via Confluent Cloud UI:
# - Upload JAR: engagement-analytics-job.jar
# - Set parallelism: 4
# - Configure Kafka credentials (auto-injected from Cloud environment)

# 4. Monitor via Confluent Cloud console
# - Job status, checkpoint metrics
# - Integrated with Kafka topic monitoring
```

**Advantages:**
- Managed checkpoints/savepoints (no GCS setup needed)
- Auto-scaling based on load
- Integrated with Confluent Kafka (no credential management)
- Built-in monitoring and alerting

---

### Savepoints for Schema Upgrades

**Strategy:** Create savepoint before deploying new Flink job version with schema changes.

```bash
# 1. Trigger savepoint
docker exec jobmanager flink savepoint <job-id> file:///opt/flink/savepoints

# 2. Cancel job
docker exec jobmanager flink cancel <job-id>

# 3. Deploy new job version from savepoint
docker exec jobmanager flink run \
  -s file:///opt/flink/savepoints/<savepoint-id> \
  /opt/flink/jobs/engagement-analytics-job-v2.jar
```

---

### Disaster Recovery

**Scenario: Flink cluster fails during demo**

1. **Immediate:** Ensure Kafka topics retain data (7-day retention)
2. **Restart:** Docker Compose restarts Flink containers automatically
3. **Recover:** Flink resumes from last successful checkpoint
4. **Lag:** Jobs may have 1-2 minutes of lag (time to restart + reprocess from checkpoint)

**Mitigation for critical demos:**
- Pre-warm Flink cluster 10 minutes before demo
- Test checkpoint recovery before demo starts
- Have backup video of working demo

---

## 9. Storage and Replay Strategy (Without BigQuery)

### Kafka as System of Record

**Retention Strategy:**

| **Topic** | **Retention** | **Reason** |
|-----------|---------------|------------|
| `quiz.answers` | 7 days | Source of truth for student interactions; replay for debugging |
| `session.events` | 7 days | Behavioral signals; same as quiz.answers |
| `engagement.scores` | 7 days | Derived metrics; can be recomputed from quiz.answers if needed |
| `adapt.actions` | 7 days | Adaptation history; audit trail for AI decisions |
| `instructor.tips` | 7 days | Tips history; not replayed in normal operation |
| `cohort.metrics` | 2 days | Dashboard data; short-lived, recomputed continuously |
| `content.questions` | Infinite (compacted) | Reference data; log compaction keeps latest version per questionId |

**Compacted Topic Usage:**
- `content.questions` uses `cleanup.policy=compact`
- Flink reads as side input (broadcast or temporal join)
- Ensures Flink always has latest question metadata without external DB lookups

---

### Demo Reset Strategy

**Goal:** Reset system to clean state between demos without BigQuery.

**Approach:**

```bash
#!/bin/bash
# scripts/demo-reset.sh

# 1. Stop Flink jobs
docker exec jobmanager flink list | grep -oP 'Job ID: \K\w+' | xargs -I {} docker exec jobmanager flink cancel {}

# 2. Delete Kafka topics (recreate with fresh data)
kafka-topics --bootstrap-server localhost:9092 --delete --topic quiz.answers
kafka-topics --bootstrap-server localhost:9092 --delete --topic session.events
kafka-topics --bootstrap-server localhost:9092 --delete --topic engagement.scores
kafka-topics --bootstrap-server localhost:9092 --delete --topic adapt.actions

# 3. Recreate topics
kafka-topics --bootstrap-server localhost:9092 --create --topic quiz.answers --partitions 6
kafka-topics --bootstrap-server localhost:9092 --create --topic session.events --partitions 6
kafka-topics --bootstrap-server localhost:9092 --create --topic engagement.scores --partitions 6
kafka-topics --bootstrap-server localhost:9092 --create --topic adapt.actions --partitions 6

# 4. Clear Flink checkpoints
rm -rf /opt/flink/checkpoints/*

# 5. Seed demo data to Kafka
cd scripts && ./seed-demo-events.sh

# 6. Restart Flink jobs
docker exec jobmanager flink run /opt/flink/jobs/engagement-analytics-job.jar
docker exec jobmanager flink run /opt/flink/jobs/instructor-metrics-job.jar

# 7. Reset PostgreSQL session state (if needed)
psql -h localhost -U edupulse -d edupulse -c "TRUNCATE sessions, quiz_attempts CASCADE;"

echo "Demo reset complete. System ready."
```

---

### Optional PostgreSQL for Session State

**When to use PostgreSQL:**
- Store active session metadata (sessionId → cohortId, instructorId mapping)
- User authentication state (not in Kafka for security)
- Question bank (used by Content Adapter for enrichment)

**What NOT to use PostgreSQL for:**
- Event history (use Kafka retention)
- Analytics queries (use Flink-produced topics)
- Aggregated metrics (use Flink, output to Kafka)

**Tables (minimal):**
```sql
-- Session orchestration only
CREATE TABLE sessions (
    session_id VARCHAR(50) PRIMARY KEY,
    instructor_id VARCHAR(50),
    cohort_id VARCHAR(50),
    created_at TIMESTAMP,
    status VARCHAR(20)
);

-- Question bank for Content Adapter
CREATE TABLE questions (
    question_id VARCHAR(50) PRIMARY KEY,
    skill_tag VARCHAR(100),
    difficulty_level INT,
    question_text TEXT,
    correct_answer VARCHAR(10)
);
```

---

## 10. Instructor Dashboard Metric Contract

| **Metric Name** | **Definition** | **Key** | **Window Type/Duration** | **Output Topic** | **UI Usage** |
|-----------------|----------------|---------|--------------------------|------------------|--------------|
| **Engagement Distribution** | Count of students in high/medium/low engagement bands | cohortId | Sliding, 5 min / 1 min slide | `cohort.metrics` | Heatmap grid color coding |
| **Average Engagement Score** | Mean engagement score across cohort | cohortId | Sliding, 5 min / 1 min slide | `cohort.metrics` | Cohort health gauge |
| **Skill Struggle Count** | Number of students with score <0.5 per skill tag | skillTag | Tumbling, 2 min | `cohort.metrics` | Skill bottleneck badges |
| **Alerting Students** | List of studentIds with alertThresholdCrossed=true | cohortId | Sliding, 5 min / 1 min slide | `cohort.metrics` | Highlighted tiles in heatmap |
| **High-Priority Tips** | Generated tips with priority=HIGH for instructor action | sessionId | Event-driven (no window) | `instructor.tips` | Tips panel sidebar |
| **Cohort Trends** | Time series of avg engagement score over last 30 min | cohortId | Sliding, 5 min / 1 min slide, emitted as array | `cohort.metrics` | Line chart in dashboard header |

**UI Consumption Pattern:**

```typescript
// Instructor Dashboard (Next.js)
const { data: cohortMetrics } = useWebSocket<CohortMetrics>('cohort.metrics', {
  filter: { cohortId: currentCohortId }
});

// Update heatmap
<HeatmapGrid
  students={cohortMetrics.alertingStudents}
  distribution={cohortMetrics.engagementDistribution}
/>

// Show skill struggles
<SkillBadges struggles={cohortMetrics.skillStruggles} />
```

---

## Summary of Changes for README.md

Replace the following sections in README.md:

1. **Lines 32-38 (Technology Stack):** Replace with updated stack (remove BigQuery, add Flink)
2. **Lines 42-67 (Architecture Diagram):** Replace with Flink-centric diagram
3. **Lines 388-506 (Engagement Service):** Replace with Flink Engagement Analytics Job section
4. **Add new section after line 506:** Flink Instructor Metrics Job
5. **Lines 1343-1351 (BigQuery setup):** Remove entirely
6. **Add new section in Cloud & Infrastructure:** Flink deployment guidance
7. **Update Quick Start section (lines 133-174):** Include Flink cluster startup

**Files to Create:**
- `backend/flink-jobs/` - New Maven module for Flink job code
- `scripts/demo-reset.sh` - Demo reset script
- `infra/docker-compose.yml` - Add Flink jobmanager and taskmanager services

**Files to Update:**
- `README.md` - Apply all architecture sections from this document
- `CLAUDE.md` - Add Flink development commands and patterns

---

**End of Architecture Refactor Document**
