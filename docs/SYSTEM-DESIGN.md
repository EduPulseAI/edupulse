# SYSTEM_DESIGN.md

## EduPulse: Adaptive Learning with Real-Time Engagement

**Version:** 1.0  
**Last Updated:** 2025-12-30  
**Authors:** Architecture Team

---

## 1. Goals and Non-Goals

### Goals

- **Real-time engagement detection:** Identify student disengagement within 5-10 seconds of behavior change
- **Adaptive intervention:** Adjust content difficulty and provide hints during active learning sessions
- **Instructor coaching:** Generate actionable recommendations for live classroom management
- **Event-driven architecture:** Use Kafka as the system of record for all learning signals and decisions
- **Schema governance:** Enforce Avro schema compatibility across all microservices via Confluent Schema Registry
- **Auditability:** Preserve complete event history for educational compliance and analytics
- **Sub-500ms intervention latency:** From event ingestion to student UI update

### Non-Goals

- **Batch analytics:** Offline dashboards and historical reports (deferred to BigQuery sink)
- **Video streaming:** Webcam attention tracking is optional/simulated for MVP
- **Multi-tenancy isolation:** Single educational institution for initial deployment
- **Mobile native apps:** Web-first approach; native apps not in scope
- **SCORM/LTI integration:** Standalone platform, no LMS interoperability required
- **Grading automation:** Focus on engagement, not assessment scoring

---

## 2. Personas and Core User Journeys

### Persona 1: Student (Alice)

**Context:** 10th grade student working through algebra unit

**Journey: Struggling with Linear Equations**

1. Alice receives a difficulty-4 linear equation question
2. She attempts the question, submits incorrect answer (attempt 1)
3. System detects pacing slowdown and incorrect response
4. Alice retries, submits second incorrect answer (attempt 2)
5. Engagement score drops from 0.72 → 0.51 (yellow threshold)
6. Alice attempts third time, still incorrect (attempt 3)
7. Engagement score drops to 0.38 (red threshold, alert triggered)
8. **System intervenes:**
   - AI bandit model selects "reduce difficulty" action
   - Gemini generates contextual hint
   - New difficulty-2 question presented
   - Hint displayed: "Isolate the variable by working backwards"
9. Alice reads hint, attempts new question, answers correctly
10. Engagement recovers to 0.68, session continues

**Key Requirements:**
- Intervention must happen before Alice gives up (< 30 second window)
- Hints must be non-obvious but helpful
- Difficulty changes must feel natural, not patronizing

### Persona 2: Instructor (Mr. Rodriguez)

**Context:** Teaching 25 students in live classroom

**Journey: Monitoring Class Engagement**

1. Mr. Rodriguez starts lesson, opens instructor dashboard
2. Dashboard shows real-time engagement heatmap (25 student tiles)
3. Most students green (0.7+), a few yellow (0.4-0.7)
4. Alice's tile turns red (0.38), alert badge appears
5. **System generates tip:**
   - "Alice struggling with multi-step equations (3 failed attempts)"
   - "Consider 1-on-1 review of substitution method"
   - Priority: HIGH
6. Mr. Rodriguez sees tip, approaches Alice's desk during independent work
7. Alice receives automated help from system, begins recovering
8. Mr. Rodriguez marks tip as "addressed," makes note for tomorrow's lesson plan
9. Dashboard shows Alice's tile returning to yellow, then green

**Key Requirements:**
- Heatmap must update in real-time (< 2 second latency)
- Tips must be specific and actionable, not generic
- Must handle 25-30 concurrent students without overwhelming instructor

---

## 3. High-Level Architecture Overview

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            Frontend Layer                               │
│  ┌──────────────────────────────┐  ┌─────────────────────────────────┐ │
│  │  Student Learning UI         │  │  Instructor Dashboard           │ │
│  │  (Next.js)                   │  │  (Next.js)                      │ │
│  │  - Question display          │  │  - Engagement heatmap           │ │
│  │  - Answer submission         │  │  - Real-time tips panel         │ │
│  │  - Hint rendering            │  │  - Student drill-down           │ │
│  └──────────────┬───────────────┘  └──────────────┬──────────────────┘ │
│                 │                                  │                     │
└─────────────────┼──────────────────────────────────┼─────────────────────┘
                  │ WebSocket                        │ WebSocket
                  ▼                                  ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         API Gateway Layer                               │
│  ┌─────────────────────────────────────────────────────────────────────┤
│  │  Realtime Gateway Service (Spring Boot)                             │
│  │  - WebSocket connection management                                  │
│  │  - Session → WebSocket mapping                                      │
│  │  - Consumes: adapt.actions, instructor.tips                         │
│  │  - Pushes events to connected clients                               │
│  └─────────────────────────────────────────────────────────────────────┘
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
                  ▲                                  ▲
                  │                                  │
                  │ consume                          │ consume
                  │                                  │
┌─────────────────┴──────────────────────────────────┴─────────────────────┐
│                        Kafka / Event Streaming Layer                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐│
│  │  session.    │  │    quiz.     │  │ engagement.  │  │    adapt.    ││
│  │   events     │  │   answers    │  │    scores    │  │   actions    ││
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘│
│  ┌──────────────┐                                                        │
│  │ instructor.  │        Confluent Kafka Cluster                        │
│  │     tips     │        + Schema Registry (Avro)                       │
│  └──────────────┘                                                        │
└─────────────────────────────────────────────────────────────────────────┘
    ▲    │    ▲    │    ▲    │    ▲    │    ▲    │
    │    │    │    │    │    │    │    │    │    │
    │    ▼    │    ▼    │    ▼    │    ▼    │    ▼
┌───┴────────┴────────┴────────┴────────┴────────────────────────────────┐
│                      Business Logic / Service Layer                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐│
│  │    Event     │  │   Feature/   │  │   Bandit/    │  │   Content   ││
│  │    Ingest    │  │ Engagement   │  │   Policy     │  │   Adapter   ││
│  │   Service    │  │   Service    │  │   Engine     │  │   Service   ││
│  └──────────────┘  └──────────────┘  └──────────────┘  └─────────────┘│
│  ┌──────────────┐  ┌──────────────┐                                    │
│  │     Tip      │  │     Quiz     │                                    │
│  │   Service    │  │   Service    │                                    │
│  └──────────────┘  └──────────────┘                                    │
│                                                                          │
│  All services: Spring Boot + Kafka Avro Serialization                  │
└─────────────────────────────────────────────────────────────────────────┘
                  │                                  │
                  ▼                                  ▼
┌─────────────────────────────────┐  ┌─────────────────────────────────┐
│   AI/ML Inference Layer         │  │   Data Storage Layer            │
│  ┌───────────────────────────┐  │  │  ┌───────────────────────────┐ │
│  │ Vertex AI                 │  │  │  │ PostgreSQL                │ │
│  │ - Engagement classifier   │  │  │  │ - Student profiles        │ │
│  │ - Multi-armed bandit      │  │  │  │ - Question bank           │ │
│  └───────────────────────────┘  │  │  │ - Session metadata        │ │
│  ┌───────────────────────────┐  │  │  └───────────────────────────┘ │
│  │ Gemini API                │  │  │  ┌───────────────────────────┐ │
│  │ - Hint generation         │  │  │  │ Redis                     │ │
│  │ - Instructor tips         │  │  │  │ - WebSocket sessions      │ │
│  └───────────────────────────┘  │  │  │ - Feature cache           │ │
│                                  │  │  └───────────────────────────┘ │
└──────────────────────────────────┘  │  ┌───────────────────────────┐ │
                                      │  │ BigQuery (via Kafka       │ │
                                      │  │ Connect Sink)             │ │
                                      │  │ - Event replay            │ │
                                      │  │ - Analytics               │ │
                                      │  └───────────────────────────┘ │
                                      └──────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────────┐
│   Schema Governance Layer                                               │
│  ┌─────────────────────────────────────────────────────────────────────┤
│  │  Confluent Schema Registry                                          │
│  │  - Avro schema storage & versioning                                 │
│  │  - BACKWARD compatibility enforcement                               │
│  │  - Subject naming: TopicNameStrategy                                │
│  └─────────────────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────────────────┘
```

### Data Flow: High-Level

```
Student Action (quiz answer)
    ↓
Event Ingest Service → quiz.answers (Avro)
    ↓
Engagement Service consumes, computes score
    ↓
Engagement Service → engagement.scores (Avro)
    ↓
┌───────────────────────────────┬────────────────────────────────┐
│                               │                                │
▼                               ▼                                ▼
Bandit Engine                   Tip Service              Realtime Gateway
  ↓ (calls Vertex AI)             ↓ (calls Gemini)          ↓ (forwards)
  ↓                               ↓                          ↓
adapt.actions (Avro)        instructor.tips (Avro)     WebSocket → Student
  ↓                               ↓                          ↓
Content Adapter                 Realtime Gateway         WebSocket → Instructor
  ↓                               ↓
Realtime Gateway              WebSocket → Instructor
  ↓
WebSocket → Student
```

---

## 4. Spring Boot Service Responsibilities

### 4.1 Event Ingest Service

**Responsibility:** Accept HTTP events from frontend, validate, enrich, publish to Kafka

**Technology:** Spring Boot, Spring Kafka, Spring Web

**Endpoints:**
- `POST /api/events/session` → session.events topic
- `POST /api/events/quiz-answer` → quiz.answers topic

**Logic:**
```
1. Receive HTTP POST with JSON payload
2. Validate request (studentId, sessionId, required fields)
3. Enrich with server timestamp, generate event ID
4. Build Avro EventEnvelope
5. Serialize to Avro using Schema Registry
6. Publish to Kafka topic
7. Return 202 Accepted with event ID
```

**Kafka Interaction:**
- **Produces to:** session.events, quiz.answers
- **Consumes from:** None

**Configuration:**
```yaml
edupulse:
  ingest:
    validation:
      max-answer-length: 500
      allowed-event-types: [STARTED, NAVIGATION, DWELL, PAUSED, RESUMED, COMPLETED]
    kafka:
      acks: all
      retries: 3
      idempotence: true
```

**Error Handling:**
- 400 Bad Request: Validation failure
- 503 Service Unavailable: Kafka unavailable (circuit breaker)
- Synchronous response to client, async Kafka publish

---

### 4.2 Feature / Engagement Service

**Responsibility:** Compute real-time engagement scores from streaming events

**Technology:** Spring Boot, Kafka Streams

**Logic:**
```
1. Consume quiz.answers and session.events
2. Maintain per-student stateful aggregation (tumbling window: 60s)
3. Compute engagement score components:
   - dwellScore: average time on questions vs expected
   - accuracyScore: correct answers / total attempts
   - pacingScore: questions per minute vs baseline
   - attentionScore: (optional) webcam data
4. Weighted sum: score = 0.3*dwell + 0.4*accuracy + 0.3*pacing
5. Detect trend (compare to previous 3 windows)
6. Publish EngagementScore to engagement.scores topic
7. Trigger alert if score < 0.4 and trend = DECLINING
```

**Kafka Interaction:**
- **Consumes from:** quiz.answers, session.events
- **Produces to:** engagement.scores
- **State Store:** student-engagement-state (RocksDB)

**Stateful Stream Processing:**
```java
KStream<String, QuizAnswer> quizAnswers = builder.stream("quiz.answers");
KStream<String, SessionEvent> sessionEvents = builder.stream("session.events");

KTable<String, StudentEngagementState> aggregated = quizAnswers
    .selectKey((k, v) -> v.getEnvelope().getStudentId())
    .groupByKey()
    .windowedBy(TimeWindows.ofSizeWithNoGrace(Duration.ofSeconds(60)))
    .aggregate(
        StudentEngagementState::new,
        (key, value, aggregate) -> aggregate.update(value),
        Materialized.as("student-engagement-state")
    );

aggregated
    .toStream()
    .mapValues(EngagementScoringService::computeScore)
    .to("engagement.scores");
```

**Configuration:**
```yaml
edupulse:
  engagement:
    scoring:
      weights:
        dwell: 0.3
        accuracy: 0.4
        pacing: 0.3
      thresholds:
        green: 0.7
        yellow: 0.4
        red: 0.4
    windowing:
      duration-seconds: 60
      grace-period-seconds: 5
```

---

### 4.3 Bandit / Policy Engine

**Responsibility:** Select optimal adaptation action using Vertex AI multi-armed bandit

**Technology:** Spring Boot, Spring Kafka, Google Cloud Vertex AI SDK

**Logic:**
```
1. Consume engagement.scores topic
2. Filter for alertThresholdCrossed = true
3. Fetch student context from PostgreSQL:
   - Recent accuracy history (last 10 questions)
   - Current difficulty level
   - Skill proficiency estimates
4. Build feature vector for Vertex AI
5. Call Vertex AI prediction endpoint (timeout: 500ms)
6. Parse response: selected arm (difficulty level) + expected reward
7. Build AdaptAction event with:
   - actionType: DIFFICULTY_ADJUST
   - difficultyAdjustment details
   - modelMetadata (latency, version)
8. Publish to adapt.actions topic
```

**Vertex AI Integration:**
```java
@Service
public class BanditPolicyService {
    
    private final PredictionServiceClient vertexClient;
    private final StudentContextRepository contextRepo;
    
    public AdaptAction selectAction(EngagementScore score) {
        // Fetch context
        StudentContext context = contextRepo.findByStudentId(
            score.getEnvelope().getStudentId()
        );
        
        // Build feature vector
        Map<String, Value> features = Map.of(
            "engagement_score", toValue(score.getScore()),
            "recent_accuracy", toValue(context.getRecentAccuracy()),
            "current_difficulty", toValue(context.getCurrentDifficulty()),
            "time_on_task_percentile", toValue(context.getTimePercentile())
        );
        
        // Call Vertex AI
        long start = System.currentTimeMillis();
        PredictResponse response = vertexClient.predict(
            endpoint, 
            List.of(features), 
            Map.of()
        );
        long latency = System.currentTimeMillis() - start;
        
        // Parse response
        int selectedArm = extractArm(response);
        double expectedReward = extractReward(response);
        
        // Build adaptation action
        return AdaptAction.newBuilder()
            .setActionType(AdaptActionType.DIFFICULTY_ADJUST)
            .setDifficultyAdjustment(
                DifficultyAdjustment.newBuilder()
                    .setFromLevel(context.getCurrentDifficulty())
                    .setToLevel(selectedArm)
                    .setReason("Engagement declining, optimizing for recovery")
                    .setBanditArmSelected(selectedArm)
                    .setExpectedReward(expectedReward)
                    .build()
            )
            .setModelMetadata(
                ModelMetadata.newBuilder()
                    .setModelName("edupulse-bandit-v1")
                    .setModelVersion("20250101")
                    .setInferenceLatencyMs(latency)
                    .build()
            )
            .build();
    }
}
```

**Kafka Interaction:**
- **Consumes from:** engagement.scores
- **Produces to:** adapt.actions
- **Consumer Group:** bandit-policy-group

**Fallback Strategy:**
```
If Vertex AI call fails or times out:
1. Log error with correlation ID
2. Apply rule-based fallback:
   - If score < 0.3: reduce difficulty by 2 levels
   - If 0.3 ≤ score < 0.5: reduce difficulty by 1 level
3. Set modelMetadata.modelName = "fallback-rule-based"
4. Still publish to adapt.actions (ensures student gets help)
```

**Configuration:**
```yaml
edupulse:
  vertex-ai:
    project-id: edupulse-prod
    location: us-central1
    endpoint: projects/123/locations/us-central1/endpoints/456
    timeout-ms: 500
  bandit:
    arms: [1, 2, 3, 4, 5]  # difficulty levels
    fallback-enabled: true
```

---

### 4.4 Content Adapter Service

**Responsibility:** Fetch and deliver adapted content based on policy decisions

**Technology:** Spring Boot, Spring Kafka, Spring Data JPA

**Logic:**
```
1. Consume adapt.actions topic
2. Extract toLevel from difficultyAdjustment
3. Extract skillTag from student's current question context (cached in Redis)
4. Query PostgreSQL question bank:
   WHERE skill_tag = :skillTag 
   AND difficulty_level = :toLevel
   AND question_id NOT IN (recent_seen_ids)
   ORDER BY RANDOM()
   LIMIT 1
5. Build adapted question payload
6. Publish to adapt.actions topic (append question data)
   OR send directly to Realtime Gateway via internal REST call
```

**Kafka Interaction:**
- **Consumes from:** adapt.actions (filter: actionType = DIFFICULTY_ADJUST)
- **Produces to:** adapt.actions (enriched with question content)
- **Consumer Group:** content-adapter-group

**Data Model (PostgreSQL):**
```sql
CREATE TABLE questions (
    question_id VARCHAR(50) PRIMARY KEY,
    skill_tag VARCHAR(100) NOT NULL,
    difficulty_level INT NOT NULL CHECK (difficulty_level BETWEEN 1 AND 5),
    question_text TEXT NOT NULL,
    answer_choices JSONB,
    correct_answer VARCHAR(10),
    explanation TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_questions_skill_difficulty 
ON questions(skill_tag, difficulty_level);
```

**Redis Cache:**
```
Key: student:{studentId}:context
Value: {
    currentSkillTag: "algebra.linear-equations",
    currentDifficulty: 4,
    recentQuestionIds: ["q123", "q456", "q789"],
    sessionId: "sess_abc"
}
TTL: 3600 seconds (1 hour)
```

---

### 4.5 Tip Service

**Responsibility:** Generate instructor coaching tips using Gemini

**Technology:** Spring Boot, Spring Kafka, Vertex AI Gemini SDK

**Logic:**
```
1. Consume engagement.scores topic
2. Filter for alertThresholdCrossed = true OR score < 0.5
3. Aggregate by sessionId to identify classroom patterns
4. For individual alerts:
   a. Fetch student context (recent quiz answers, skill gaps)
   b. Build Gemini prompt with:
      - Student ID (anonymized for FERPA)
      - Skill tag of struggling topic
      - Recent incorrect answers
      - Engagement trend
   c. Call Gemini API (timeout: 2s)
   d. Parse AI-generated tip
5. Build InstructorTip event
6. Publish to instructor.tips topic
```

**Gemini Integration:**
```java
@Service
public class TipGenerationService {
    
    private final GenerativeModel geminiModel;
    
    public String generateTip(EngagementScore score, List<QuizAnswer> recentAnswers) {
        String prompt = String.format("""
            You are an instructional coach for a math teacher.
            
            Student Context:
            - Current engagement score: %.2f (declining)
            - Struggling with skill: %s
            - Recent incorrect answers: %s
            - Number of failed attempts: %d
            
            Generate a 2-3 sentence coaching tip for the instructor that:
            1. Identifies the specific misconception or gap
            2. Suggests one concrete intervention
            3. Is actionable during the current class session
            
            Be concise and avoid jargon.
            """,
            score.getScore(),
            extractSkillTag(recentAnswers),
            formatAnswers(recentAnswers),
            recentAnswers.size()
        );
        
        GenerateContentResponse response = geminiModel.generateContent(prompt);
        return response.getText();
    }
}
```

**Kafka Interaction:**
- **Consumes from:** engagement.scores, quiz.answers (joined)
- **Produces to:** instructor.tips
- **Consumer Group:** tip-generation-group

**Rate Limiting:**
```
- Max 1 tip per student per 5 minutes (avoid tip spam)
- Max 5 tips per session per minute (classroom-wide limit)
- Implemented via Redis:
  Key: tip:ratelimit:{studentId}
  TTL: 300 seconds
```

---

### 4.6 Realtime Gateway Service

**Responsibility:** Manage WebSocket connections and push events to clients

**Technology:** Spring Boot, Spring WebSocket, Spring Kafka

**Logic:**
```
1. Accept WebSocket connections at /ws
2. Authenticate connection (JWT in initial handshake)
3. Extract studentId or instructorId from token
4. Store connection in concurrent map:
   studentConnections: Map<String, WebSocketSession>
   instructorConnections: Map<String, WebSocketSession>
5. Consume adapt.actions and instructor.tips topics
6. Route events to appropriate WebSocket sessions:
   - adapt.actions → student's WebSocketSession
   - instructor.tips → instructor's WebSocketSession
7. Handle disconnections (remove from map, commit Kafka offset)
```

**WebSocket Handler:**
```java
@Component
public class RealtimeWebSocketHandler extends TextWebSocketHandler {
    
    private final Map<String, WebSocketSession> studentSessions = new ConcurrentHashMap<>();
    private final Map<String, WebSocketSession> instructorSessions = new ConcurrentHashMap<>();
    
    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        String userId = extractUserId(session);
        String userType = extractUserType(session); // "student" or "instructor"
        
        if ("student".equals(userType)) {
            studentSessions.put(userId, session);
            log.info("Student {} connected, total connections: {}", 
                userId, studentSessions.size());
        } else {
            instructorSessions.put(userId, session);
            log.info("Instructor {} connected", userId);
        }
    }
    
    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        String userId = extractUserId(session);
        studentSessions.remove(userId);
        instructorSessions.remove(userId);
        log.info("User {} disconnected: {}", userId, status);
    }
    
    public void pushToStudent(String studentId, AdaptAction action) {
        WebSocketSession session = studentSessions.get(studentId);
        if (session != null && session.isOpen()) {
            try {
                String json = objectMapper.writeValueAsString(action);
                session.sendMessage(new TextMessage(json));
            } catch (IOException e) {
                log.error("Failed to send message to student {}", studentId, e);
            }
        }
    }
    
    public void pushToInstructor(String instructorId, InstructorTip tip) {
        WebSocketSession session = instructorSessions.get(instructorId);
        if (session != null && session.isOpen()) {
            try {
                String json = objectMapper.writeValueAsString(tip);
                session.sendMessage(new TextMessage(json));
            } catch (IOException e) {
                log.error("Failed to send message to instructor {}", instructorId, e);
            }
        }
    }
}
```

**Kafka Consumer:**
```java
@Service
public class RealtimeEventConsumer {
    
    private final RealtimeWebSocketHandler wsHandler;
    
    @KafkaListener(topics = "adapt.actions", groupId = "realtime-gateway")
    public void consumeAdaptActions(AdaptAction action) {
        String studentId = action.getEnvelope().getStudentId();
        wsHandler.pushToStudent(studentId, action);
    }
    
    @KafkaListener(topics = "instructor.tips", groupId = "realtime-gateway")
    public void consumeInstructorTips(InstructorTip tip) {
        // Tips have affectedStudents array, need to map to instructorId
        String sessionId = tip.getEnvelope().getSessionId();
        String instructorId = sessionService.getInstructorForSession(sessionId);
        wsHandler.pushToInstructor(instructorId, tip);
    }
}
```

**Kafka Interaction:**
- **Consumes from:** adapt.actions, instructor.tips
- **Produces to:** None
- **Consumer Group:** realtime-gateway

**Scaling Considerations:**
- Use sticky sessions (session affinity) for WebSocket connections
- Store active session → pod mapping in Redis for routing
- For 1000+ concurrent students, deploy 3-5 gateway pods

---

### 4.7 Quiz Service

**Responsibility:** Deliver questions, validate answers, publish quiz events

**Technology:** Spring Boot, Spring Data JPA, Spring Kafka

**Endpoints:**
- `GET /api/quiz/next-question?sessionId=X&studentId=Y`
- `POST /api/quiz/submit-answer`

**Logic:**
```
Submit Answer Flow:
1. Receive answer submission (POST request)
2. Validate answer format
3. Check against correct answer in database
4. Determine if correct (boolean)
5. Fetch attempt number from Redis cache
6. Build QuizAnswer Avro event:
   - questionId, studentId, answer, isCorrect
   - attemptNumber, timeSpentMs
   - skillTag, difficultyLevel
7. Publish to quiz.answers topic
8. Increment attempt counter in Redis
9. Return 200 OK with correctness result
```

**Kafka Interaction:**
- **Produces to:** quiz.answers
- **Consumes from:** None

**Redis State:**
```
Key: quiz:attempt:{studentId}:{questionId}
Value: attemptNumber (integer)
TTL: 3600 seconds
```

---

## 5. Kafka / Confluent Design

### 5.1 Topic Configuration

| Topic Name | Partitions | Replication Factor | Retention | Cleanup Policy | Key Type |
|------------|------------|-------------------|-----------|----------------|----------|
| session.events | 6 | 3 | 7 days | delete | SessionEventKey (sessionId) |
| quiz.answers | 6 | 3 | 30 days | delete | QuizAnswerKey (studentId, questionId) |
| engagement.scores | 6 | 3 | 7 days | delete | SessionEventKey (sessionId) |
| adapt.actions | 6 | 3 | 30 days | delete | SessionEventKey (sessionId) |
| instructor.tips | 3 | 3 | 7 days | delete | SessionEventKey (sessionId) |
| *.dlq | 3 | 3 | 30 days | delete | (same as source topic) |

**Partition Strategy:**
- **6 partitions** for high-throughput topics (session.events, quiz.answers, engagement.scores, adapt.actions)
  - Supports 6 concurrent consumers per group
  - Expected load: 100 events/sec per partition (600 events/sec total)
- **3 partitions** for lower-volume topics (instructor.tips)
- **Replication factor 3** for durability (tolerate 2 broker failures)

**Key Selection Rationale:**
- **sessionId as key:** Ensures all events for a session go to same partition
  - Enables stateful processing (Kafka Streams)
  - Maintains event ordering within session
- **Composite key (studentId, questionId)** for quiz.answers:
  - Enables per-student and per-question analytics
  - Avoids hotspots (distributes across partitions)

**Retention:**
- **7 days** for operational topics (sufficient for debugging, replay)
- **30 days** for audit topics (quiz.answers, adapt.actions for compliance)
- **Compacted topics** not used (events are immutable)

---

### 5.2 Producer/Consumer Mapping

**Producers:**

| Service | Produces To | Serializer | Acks | Idempotence |
|---------|-------------|------------|------|-------------|
| Event Ingest | session.events, quiz.answers | Avro | all | true |
| Quiz Service | quiz.answers | Avro | all | true |
| Engagement Service | engagement.scores | Avro | all | true |
| Bandit Engine | adapt.actions | Avro | all | true |
| Tip Service | instructor.tips | Avro | all | true |
| Content Adapter | adapt.actions | Avro | all | true |

**Consumers:**

| Service | Consumes From | Consumer Group | Offset Commit | Max Poll |
|---------|---------------|----------------|---------------|----------|
| Engagement Service | quiz.answers, session.events | engagement-scorer-group | manual | 500 |
| Bandit Engine | engagement.scores | bandit-policy-group | manual | 100 |
| Tip Service | engagement.scores, quiz.answers | tip-generation-group | manual | 100 |
| Content Adapter | adapt.actions | content-adapter-group | manual | 100 |
| Realtime Gateway | adapt.actions, instructor.tips | realtime-gateway | manual | 500 |
| BigQuery Sink (Kafka Connect) | all topics | bigquery-sink-group | auto | 1000 |

**Configuration Highlights:**
- **Manual offset commit:** Ensures at-least-once processing (commit after successful processing)
- **Idempotent producers:** Prevents duplicate events on retry
- **max.poll.records tuning:** Lower for AI services (slower processing), higher for streaming services

---

### 5.3 End-to-End Event Flows

#### Flow 1: Student Answers Question

```
┌────────────┐
│  Student   │
│    UI      │ 
└──────┬─────┘
       │ HTTP POST /api/quiz/submit-answer
       │ {studentId, questionId, answer, timeSpent}
       ▼
┌──────────────┐
│ Quiz Service │
└──────┬───────┘
       │ 1. Validate answer
       │ 2. Check correctness (query PostgreSQL)
       │ 3. Build QuizAnswer Avro event
       │ 4. Produce to Kafka
       ▼
┌─────────────────────────────────────────┐
│ Kafka Topic: quiz.answers               │
│ Key: QuizAnswerKey {                    │
│   studentId: "s123",                    │
│   questionId: "q456"                    │
│ }                                       │
│ Value: QuizAnswer (Avro) {              │
│   isCorrect: false,                     │
│   attemptNumber: 3,                     │
│   skillTag: "algebra.linear-equations", │
│   timeSpentMs: 87000                    │
│ }                                       │
│ Headers: correlation-id, source-service │
└─────────────────────────────────────────┘
       │
       │ consumed by (fan-out)
       ├─────────────────┬──────────────┐
       ▼                 ▼              ▼
┌────────────┐  ┌──────────────┐  ┌──────────┐
│ Engagement │  │ Tip Service  │  │ BigQuery │
│  Service   │  │              │  │   Sink   │
└────────────┘  └──────────────┘  └──────────┘
```

**Timing:**
- HTTP response to student: ~50ms (after Kafka ack)
- quiz.answers → engagement.scores: ~200ms (scoring + publish)
- Total intervention latency: ~500ms (see Flow 3)

---

#### Flow 2: Engagement Score Update

```
┌──────────────────┐
│  Engagement      │
│  Service         │
│  (Kafka Streams) │
└────────┬─────────┘
         │ 1. Consume quiz.answers + session.events
         │ 2. Aggregate in 60s tumbling window
         │ 3. Compute engagement score
         │ 4. Detect trend (compare to previous windows)
         │ 5. Check alert threshold (< 0.4)
         ▼
┌─────────────────────────────────────────┐
│ Kafka Topic: engagement.scores          │
│ Key: SessionEventKey {                  │
│   sessionId: "sess_abc"                 │
│ }                                       │
│ Value: EngagementScore (Avro) {         │
│   score: 0.38,                          │
│   scoreComponents: {                    │
│     dwellScore: 0.42,                   │
│     accuracyScore: 0.33,                │
│     pacingScore: 0.41                   │
│   },                                    │
│   trend: "DECLINING",                   │
│   alertThresholdCrossed: true           │
│ }                                       │
│ Envelope: {                             │
│   timestamp: 1735568400000,             │
│   studentId: "s123",                    │
│   sessionId: "sess_abc"                 │
│ }                                       │
└─────────────────────────────────────────┘
         │
         │ consumed by (fan-out)
         ├──────────────────┬──────────────┐
         ▼                  ▼              ▼
┌──────────────┐  ┌──────────────┐  ┌──────────┐
│ Bandit Engine│  │ Tip Service  │  │ Realtime │
│              │  │              │  │ Gateway  │
└──────────────┘  └──────────────┘  └──────────┘
         │                  │              │
         │                  │              │
         └──────────────────┴──────────────┘
                      │
                      ▼
         (Triggers intervention flows)
```

**Stateful Processing Details:**
- **State Store:** RocksDB (local to Kafka Streams instance)
- **Window Type:** Tumbling, 60-second duration
- **Grace Period:** 5 seconds (for late-arriving events)
- **Changelog Topic:** engagement-scorer-group-student-engagement-state-changelog (auto-created)

---

#### Flow 3: Difficulty/Content Adaptation

```
┌──────────────────┐
│ Bandit Engine    │
└────────┬─────────┘
         │ 1. Consume engagement.scores
         │    (filter: alertThresholdCrossed = true)
         │ 2. Fetch student context (PostgreSQL)
         │ 3. Build feature vector
         ▼
┌─────────────────────────────────────────┐
│ Vertex AI Inference                     │
│ Endpoint: edupulse-bandit-v1            │
│                                         │
│ Input: {                                │
│   engagement_score: 0.38,               │
│   recent_accuracy: 0.42,                │
│   current_difficulty: 4,                │
│   time_on_task_percentile: 0.15         │
│ }                                       │
│                                         │
│ Output: {                               │
│   selected_arm: 2,                      │
│   expected_reward: 0.73,                │
│   arm_probabilities: [0.1, 0.6, ...]   │
│ }                                       │
└─────────────────────────────────────────┘
         │ Response time: ~200ms
         ▼
┌──────────────────┐
│ Bandit Engine    │
└────────┬─────────┘
         │ 4. Build AdaptAction Avro event
         │ 5. Produce to Kafka
         ▼
┌─────────────────────────────────────────┐
│ Kafka Topic: adapt.actions              │
│ Key: SessionEventKey {sessionId}        │
│ Value: AdaptAction (Avro) {             │
│   actionType: "DIFFICULTY_ADJUST",      │
│   difficultyAdjustment: {               │
│     fromLevel: 4,                       │
│     toLevel: 2,                         │
│     reason: "Engagement declining...",  │
│     banditArmSelected: 2,               │
│     expectedReward: 0.73                │
│   },                                    │
│   modelMetadata: {                      │
│     modelName: "edupulse-bandit-v1",    │
│     inferenceLatencyMs: 187             │
│   }                                     │
│ }                                       │
└─────────────────────────────────────────┘
         │
         │ consumed by (parallel)
         ├────────────────┬────────────────┐
         ▼                ▼                ▼
┌────────────┐  ┌──────────────┐  ┌──────────┐
│  Content   │  │  Realtime    │  │ BigQuery │
│  Adapter   │  │  Gateway     │  │   Sink   │
└──────┬─────┘  └──────┬───────┘  └──────────┘
       │                │
       │ 6. Fetch new   │ 7. Push via WebSocket
       │    question    │
       │    (diff=2)    │
       ▼                ▼
┌────────────┐  ┌──────────────┐
│ PostgreSQL │  │  Student UI  │
│ (question  │  │  - Shows new │
│  bank)     │  │    question  │
└────────────┘  │  - Shows hint│
                └──────────────┘
```

**Latency Breakdown:**
- Engagement score computation → adapt.actions: ~50ms
- Vertex AI inference: ~200ms
- Kafka round-trip (produce + consume): ~50ms
- WebSocket push to client: ~20ms
- **Total: ~320ms** (well under 500ms SLA)

---

#### Flow 4: Instructor Intervention

```
┌──────────────────┐
│  Tip Service     │
└────────┬─────────┘
         │ 1. Consume engagement.scores
         │    (filter: score < 0.5 OR alertThresholdCrossed)
         │ 2. Check rate limit (Redis: max 1 tip per student per 5 min)
         │ 3. Fetch recent quiz answers (join stream)
         │ 4. Build Gemini prompt
         ▼
┌─────────────────────────────────────────┐
│ Gemini API (Vertex AI)                  │
│                                         │
│ Prompt:                                 │
│ "Student struggling with                │
│  algebra.linear-equations.              │
│  3 failed attempts. Engagement 0.38.    │
│  Generate coaching tip..."              │
│                                         │
│ Response:                               │
│ "Student may have misconception about   │
│  order of operations. Suggest reviewing │
│  PEMDAS with concrete examples."        │
└─────────────────────────────────────────┘
         │ Response time: ~1500ms
         ▼
┌──────────────────┐
│  Tip Service     │
└────────┬─────────┘
         │ 5. Parse AI response
         │ 6. Build InstructorTip Avro event
         │ 7. Set rate limit in Redis
         │ 8. Produce to Kafka
         ▼
┌─────────────────────────────────────────┐
│ Kafka Topic: instructor.tips            │
│ Key: SessionEventKey {sessionId}        │
│ Value: InstructorTip (Avro) {           │
│   tipType: "INTERVENTION_NEEDED",       │
│   message: "Student may have            │
│             misconception...",          │
│   priority: "HIGH",                     │
│   affectedStudents: ["s123"],           │
│   suggestedAction: "Review PEMDAS"      │
│ }                                       │
│ Envelope: {                             │
│   timestamp: 1735568401500,             │
│   sessionId: "sess_abc"                 │
│ }                                       │
└─────────────────────────────────────────┘
         │
         │ consumed by
         ▼
┌──────────────────┐
│  Realtime        │
│  Gateway         │
└────────┬─────────┘
         │ 9. Lookup instructorId for sessionId
         │ 10. Push via WebSocket
         ▼
┌──────────────────────────────────────────┐
│ Instructor Dashboard                     │
│                                          │
│ ┌────────────────────────────────────┐  │
│ │ 🔴 HIGH PRIORITY                   │  │
│ │                                    │  │
│ │ Student Alice (s123)               │  │
│ │ Student may have misconception     │  │
│ │ about order of operations.         │  │
│ │ Suggest reviewing PEMDAS with      │  │
│ │ concrete examples.                 │  │
│ │                                    │  │
│ │ [Mark as Addressed] [Dismiss]      │  │
│ └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

**Rate Limiting (Redis):**
```
Key: tip:ratelimit:s123
Value: 1735568400
TTL: 300 seconds (5 minutes)

Logic:
IF EXISTS tip:ratelimit:{studentId}:
    SKIP tip generation (return early)
ELSE:
    GENERATE tip
    SET tip:ratelimit:{studentId} = current_timestamp
    EXPIRE tip:ratelimit:{studentId} 300
```

---

## 6. Schema Registry + Avro Governance

### 6.1 Subject Naming Strategy

**Strategy:** TopicNameStrategy (default)

**Format:** `{topic-name}-{key|value}`

**Examples:**
- `quiz.answers-key`
- `quiz.answers-value`
- `engagement.scores-value`

**Configuration:**
```yaml
spring:
  kafka:
    properties:
      value.subject.name.strategy: io.confluent.kafka.serializers.subject.TopicNameStrategy
      key.subject.name.strategy: io.confluent.kafka.serializers.subject.TopicNameStrategy
```

**Alternative Considered:** TopicRecordNameStrategy
- **Rejected because:** Multiple event types per topic would create subject proliferation
- **TopicNameStrategy is simpler** for single-schema-per-topic design

---

### 6.2 Compatibility Mode

**Default:** BACKWARD

**Enforcement:**
```bash
# Set compatibility globally (Confluent Cloud UI or CLI)
confluent schema-registry cluster update --compatibility BACKWARD

# Or per-subject
curl -X PUT \
  https://schema-registry.url/config/quiz.answers-value \
  -d '{"compatibility": "BACKWARD"}'
```

**Rationale:**
- **BACKWARD:** New schema can read data written by old schema
- **Use case:** Deploy new consumers first, then producers (common pattern)
- **Alternative (FORWARD):** Old schema can read data written by new schema
  - Not chosen because producer deployments are faster/simpler

**Compatibility Matrix:**

| Change Type                     | BACKWARD | FORWARD | FULL |
|---------------------------------|----------|---------|------|
| Add optional field              | ✅        | ✅       | ✅    |
| Remove optional field           | ❌        | ✅       | ❌    |
| Add required field with default | ✅        | ❌       | ❌    |
| Remove required field           | ❌        | ✅       | ❌    |
| Change field type               | ❌        | ❌       | ❌    |
| Rename field                    | ❌        | ❌       | ❌    |

---

### 6.3 Avro Schema Definitions

#### Schema 1: Event Envelope

**File:** `event-envelope.avsc`

```json
{
  "type": "record",
  "name": "EventEnvelope",
  "namespace": "com.edupulse.events",
  "doc": "CloudEvents-compatible envelope for all EduPulse events. Contains metadata common to all event types.",
  "fields": [
    {
      "name": "id",
      "type": "string",
      "doc": "Unique event identifier (UUID v4)"
    },
    {
      "name": "source",
      "type": "string",
      "doc": "Service that produced the event (e.g., 'quiz-service', 'engagement-service')"
    },
    {
      "name": "type",
      "type": "string",
      "doc": "Event type in format: domain.action (e.g., 'session.started', 'quiz.answered')"
    },
    {
      "name": "specversion",
      "type": "string",
      "default": "1.0",
      "doc": "CloudEvents specification version"
    },
    {
      "name": "timestamp",
      "type": {
        "type": "long",
        "logicalType": "timestamp-millis"
      },
      "doc": "Event occurrence time in milliseconds since Unix epoch (UTC)"
    },
    {
      "name": "studentId",
      "type": "string",
      "doc": "Student identifier (anonymized for FERPA compliance)"
    },
    {
      "name": "sessionId",
      "type": "string",
      "doc": "Learning session identifier"
    },
    {
      "name": "correlationId",
      "type": ["null", "string"],
      "default": null,
      "doc": "For tracing related events across services"
    }
  ]
}
```

**Usage:** Embedded in all value schemas as first field

---

#### Schema 2: Quiz Answer Event

**File:** `quiz-answer.avsc`

```json
{
  "type": "record",
  "name": "QuizAnswer",
  "namespace": "com.edupulse.events.quiz",
  "doc": "Represents a student's answer submission to a quiz question",
  "fields": [
    {
      "name": "envelope",
      "type": "com.edupulse.events.EventEnvelope"
    },
    {
      "name": "questionId",
      "type": "string",
      "doc": "Unique identifier for the question"
    },
    {
      "name": "skillTag",
      "type": "string",
      "doc": "Skill taxonomy tag (e.g., 'algebra.linear-equations', 'geometry.triangles')"
    },
    {
      "name": "difficultyLevel",
      "type": "int",
      "doc": "Question difficulty on 1-5 scale (1=easiest, 5=hardest)"
    },
    {
      "name": "answer",
      "type": "string",
      "doc": "Student's submitted answer (may be multiple choice letter or free text)"
    },
    {
      "name": "isCorrect",
      "type": "boolean",
      "doc": "Whether the submitted answer is correct"
    },
    {
      "name": "attemptNumber",
      "type": "int",
      "default": 1,
      "doc": "Which attempt this represents (1 for first try, 2 for retry, etc.)"
    },
    {
      "name": "timeSpentMs",
      "type": "long",
      "doc": "Time spent on question in milliseconds (from display to submission)"
    },
    {
      "name": "contextualData",
      "type": {
        "type": "record",
        "name": "QuizContext",
        "fields": [
          {
            "name": "hintsUsed",
            "type": "int",
            "default": 0,
            "doc": "Number of hints requested by student for this question"
          },
          {
            "name": "previousAnswers",
            "type": {
              "type": "array",
              "items": "string"
            },
            "default": [],
            "doc": "Array of previous incorrect answers for this question (for learning analytics)"
          }
        ]
      },
      "doc": "Additional contextual information about the quiz attempt"
    }
  ]
}
```

**Key Schema:** `quiz-answer-key.avsc`

```json
{
  "type": "record",
  "name": "QuizAnswerKey",
  "namespace": "com.edupulse.events.quiz",
  "fields": [
    {
      "name": "studentId",
      "type": "string"
    },
    {
      "name": "questionId",
      "type": "string"
    }
  ]
}
```

---

#### Schema 3: Engagement Score Event

**File:** `engagement-score.avsc`

```json
{
  "type": "record",
  "name": "EngagementScore",
  "namespace": "com.edupulse.events.engagement",
  "doc": "Real-time engagement score computed from streaming behavioral signals",
  "fields": [
    {
      "name": "envelope",
      "type": "com.edupulse.events.EventEnvelope"
    },
    {
      "name": "score",
      "type": "double",
      "doc": "Composite engagement score from 0.0 (completely disengaged) to 1.0 (fully engaged)"
    },
    {
      "name": "scoreComponents",
      "type": {
        "type": "record",
        "name": "ScoreComponents",
        "doc": "Individual components that contribute to overall engagement score",
        "fields": [
          {
            "name": "dwellScore",
            "type": "double",
            "doc": "Score based on time spent on questions vs. expected duration (0.0-1.0)"
          },
          {
            "name": "accuracyScore",
            "type": "double",
            "doc": "Score based on answer correctness (0.0-1.0)"
          },
          {
            "name": "pacingScore",
            "type": "double",
            "doc": "Score based on questions answered per minute vs. baseline (0.0-1.0)"
          },
          {
            "name": "attentionScore",
            "type": ["null", "double"],
            "default": null,
            "doc": "Optional score from webcam-based attention tracking (0.0-1.0). Null if not enabled."
          }
        ]
      }
    },
    {
      "name": "trend",
      "type": {
        "type": "enum",
        "name": "EngagementTrend",
        "symbols": ["RISING", "STABLE", "DECLINING", "CRITICAL"]
      },
      "doc": "Directional trend computed from recent score history"
    },
    {
      "name": "alertThresholdCrossed",
      "type": "boolean",
      "default": false,
      "doc": "Whether score has crossed alert threshold (< 0.4), triggering intervention"
    }
  ]
}
```

---

#### Schema 4: Adaptation Action Event

**File:** `adapt-action.avsc`

```json
{
  "type": "record",
  "name": "AdaptAction",
  "namespace": "com.edupulse.events.adapt",
  "doc": "AI-driven adaptation action to adjust learning experience",
  "fields": [
    {
      "name": "envelope",
      "type": "com.edupulse.events.EventEnvelope"
    },
    {
      "name": "actionType",
      "type": {
        "type": "enum",
        "name": "AdaptActionType",
        "symbols": ["DIFFICULTY_ADJUST", "HINT_PROVIDED", "CONTENT_SWITCH", "BREAK_SUGGESTED"]
      },
      "doc": "Type of adaptation action being taken"
    },
    {
      "name": "difficultyAdjustment",
      "type": [
        "null",
        {
          "type": "record",
          "name": "DifficultyAdjustment",
          "fields": [
            {
              "name": "fromLevel",
              "type": "int",
              "doc": "Previous difficulty level (1-5)"
            },
            {
              "name": "toLevel",
              "type": "int",
              "doc": "New difficulty level (1-5)"
            },
            {
              "name": "reason",
              "type": "string",
              "doc": "Human-readable explanation for adjustment"
            },
            {
              "name": "banditArmSelected",
              "type": "int",
              "doc": "Which bandit arm (difficulty level) was selected by policy"
            },
            {
              "name": "expectedReward",
              "type": "double",
              "doc": "Expected reward (learning gain) from bandit model (0.0-1.0)"
            }
          ]
        }
      ],
      "default": null,
      "doc": "Details of difficulty adjustment, if actionType = DIFFICULTY_ADJUST"
    },
    {
      "name": "hintContent",
      "type": ["null", "string"],
      "default": null,
      "doc": "AI-generated hint text, if actionType = HINT_PROVIDED"
    },
    {
      "name": "modelMetadata",
      "type": {
        "type": "record",
        "name": "ModelMetadata",
        "fields": [
          {
            "name": "modelName",
            "type": "string",
            "doc": "Name of AI model used (e.g., 'edupulse-bandit-v1', 'gemini-1.5-pro')"
          },
          {
            "name": "modelVersion",
            "type": "string",
            "doc": "Model version identifier (e.g., '20250101')"
          },
          {
            "name": "inferenceLatencyMs",
            "type": "long",
            "doc": "Time taken for AI inference in milliseconds"
          },
          {
            "name": "confidence",
            "type": ["null", "double"],
            "default": null,
            "doc": "Model confidence score (0.0-1.0), if applicable"
          }
        ]
      },
      "doc": "Metadata about AI model that generated this action"
    }
  ]
}
```

---

#### Schema 5: Instructor Tip Event

**File:** `instructor-tip.avsc`

```json
{
  "type": "record",
  "name": "InstructorTip",
  "namespace": "com.edupulse.events.instructor",
  "doc": "AI-generated coaching tip for instructor to improve classroom management",
  "fields": [
    {
      "name": "envelope",
      "type": "com.edupulse.events.EventEnvelope"
    },
    {
      "name": "tipType",
      "type": {
        "type": "enum",
        "name": "TipType",
        "symbols": ["INTERVENTION_NEEDED", "SKILL_GAP_DETECTED", "POSITIVE_MOMENTUM", "GROUP_PATTERN"]
      },
      "doc": "Category of coaching tip"
    },
    {
      "name": "message",
      "type": "string",
      "doc": "AI-generated coaching message for instructor (2-3 sentences)"
    },
    {
      "name": "priority",
      "type": {
        "type": "enum",
        "name": "Priority",
        "symbols": ["LOW", "MEDIUM", "HIGH", "URGENT"]
      },
      "doc": "Priority level for instructor attention"
    },
    {
      "name": "affectedStudents",
      "type": {
        "type": "array",
        "items": "string"
      },
      "doc": "List of student IDs this tip applies to (may be single student or group)"
    },
    {
      "name": "suggestedAction",
      "type": ["null", "string"],
      "default": null,
      "doc": "Optional concrete action instructor can take (e.g., 'Review PEMDAS with group')"
    }
  ]
}
```

---

### 6.4 Schema Evolution Examples

#### Example 1: Safe Addition (BACKWARD Compatible)

**Scenario:** Add optional webcam attention tracking to EngagementScore

**Version 1 (Initial):**
```json
{
  "name": "scoreComponents",
  "type": {
    "type": "record",
    "name": "ScoreComponents",
    "fields": [
      {"name": "dwellScore", "type": "double"},
      {"name": "accuracyScore", "type": "double"},
      {"name": "pacingScore", "type": "double"}
    ]
  }
}
```

**Version 2 (Evolution):**
```json
{
  "name": "scoreComponents",
  "type": {
    "type": "record",
    "name": "ScoreComponents",
    "fields": [
      {"name": "dwellScore", "type": "double"},
      {"name": "accuracyScore", "type": "double"},
      {"name": "pacingScore", "type": "double"},
      {
        "name": "attentionScore",
        "type": ["null", "double"],
        "default": null,
        "doc": "ADDED in v2: Webcam-based attention (0.0-1.0)"
      }
    ]
  }
}
```

**Validation:**
- ✅ Old consumers can read new data (ignore attentionScore field)
- ✅ New consumers can read old data (attentionScore = null)
- ✅ BACKWARD compatible

**Deployment Order:**
1. Register new schema in Schema Registry
2. Deploy new consumers (can handle old data)
3. Deploy new producers (start writing new field)

---

#### Example 2: Safe Deprecation (BACKWARD Compatible)

**Scenario:** Deprecate attemptNumber in favor of contextualData

**Version 1:**
```json
{
  "name": "attemptNumber",
  "type": "int",
  "default": 1
}
```

**Version 2:**
```json
{
  "name": "attemptNumber",
  "type": "int",
  "default": 1,
  "doc": "DEPRECATED in v2: Use contextualData.previousAnswers.length + 1 instead. Will be removed in v3."
}
```

**Version 3 (Future):**
- Remove attemptNumber field entirely
- **Breaking change** → requires new topic or coordinated migration

---

#### Example 3: Breaking Change (NOT BACKWARD Compatible)

**Scenario:** Change score from double to int (bad idea, but illustrative)

**Version 1:**
```json
{
  "name": "score",
  "type": "double"
}
```

**Version 2 (BREAKS compatibility):**
```json
{
  "name": "score",
  "type": "int"
}
```

**Schema Registry Response:**
```
HTTP 409 Conflict
{
  "error_code": 409,
  "message": "Schema being registered is incompatible with an earlier schema for subject engagement.scores-value"
}
```

**Resolution:**
- Create new topic: engagement.scores.v2
- Dual-write period (both topics)
- Migrate all consumers
- Deprecate old topic after 30 days

---

#### Example 4: Safe Enum Extension (BACKWARD Compatible)

**Scenario:** Add new action type to AdaptActionType

**Version 1:**
```json
{
  "name": "actionType",
  "type": {
    "type": "enum",
    "name": "AdaptActionType",
    "symbols": ["DIFFICULTY_ADJUST", "HINT_PROVIDED", "CONTENT_SWITCH"]
  }
}
```

**Version 2:**
```json
{
  "name": "actionType",
  "type": {
    "type": "enum",
    "name": "AdaptActionType",
    "symbols": ["DIFFICULTY_ADJUST", "HINT_PROVIDED", "CONTENT_SWITCH", "BREAK_SUGGESTED"]
  }
}
```

**Validation:**
- ✅ Old consumers ignore unknown enum value (Avro default behavior)
- ✅ New consumers can read old data (no BREAK_SUGGESTED values exist)
- ⚠️ Requires consumer logic to handle unknown enums gracefully

---

### 6.5 Schema Registration Workflow

**Manual Registration (Pre-deployment):**

```bash
#!/bin/bash
# register-schemas.sh

SCHEMA_REGISTRY_URL="https://psrc-xxxxx.confluent.cloud"
AUTH="$SCHEMA_REGISTRY_KEY:$SCHEMA_REGISTRY_SECRET"

# Register EventEnvelope (referenced by others)
curl -X POST \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -u "$AUTH" \
  --data @event-envelope.avsc \
  "$SCHEMA_REGISTRY_URL/subjects/event-envelope/versions"

# Register quiz.answers-value
curl -X POST \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -u "$AUTH" \
  --data @quiz-answer.avsc \
  "$SCHEMA_REGISTRY_URL/subjects/quiz.answers-value/versions"

# Register quiz.answers-key
curl -X POST \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -u "$AUTH" \
  --data @quiz-answer-key.avsc \
  "$SCHEMA_REGISTRY_URL/subjects/quiz.answers-key/versions"

# Repeat for other schemas...
```

**Auto-Registration (Development Only):**

```yaml
spring:
  kafka:
    properties:
      auto.register.schemas: false  # MUST be false in production
```

**Production:** Always pre-register schemas manually or via CI/CD pipeline

---

## 7. AI Inference Workflows

### 7.1 Vertex AI: Engagement Classification

**Model Type:** Supervised classification (binary or multi-class)

**Training Data:**
- Historical engagement scores (labels: engaged/disengaged)
- Features: dwell time, accuracy, pacing, question difficulty
- Labels: manually labeled by instructional designers

**Input Features:**
```python
features = {
    'dwell_score': 0.42,
    'accuracy_score': 0.33,
    'pacing_score': 0.41,
    'current_difficulty': 4,
    'skill_proficiency_estimate': 0.5,
    'time_of_day': 14,  # 2 PM
    'questions_answered_today': 12
}
```

**Output:**
```python
{
    'prediction': 'disengaged',
    'confidence': 0.87,
    'feature_importance': {
        'accuracy_score': 0.42,
        'dwell_score': 0.31,
        'pacing_score': 0.18
    }
}
```

**Deployment:**
- Vertex AI Endpoint (online prediction)
- Model refresh: weekly (retrain on new labeled data)
- SLA: 95th percentile latency < 200ms

---

### 7.2 Vertex AI: Multi-Armed Bandit

**Model Type:** Contextual bandit (Thompson Sampling or LinUCB)

**Arms:** Difficulty levels [1, 2, 3, 4, 5]

**Context (State):**
- Current engagement score
- Recent accuracy (last 5 questions)
- Current difficulty level
- Estimated skill proficiency (from IRT model)

**Reward Function:**
```python
def compute_reward(next_question_result):
    # Reward = learning gain * 0.6 + engagement improvement * 0.4
    
    learning_gain = 1.0 if next_question_result['is_correct'] else 0.0
    
    engagement_improvement = (
        next_question_result['engagement_score_after'] - 
        next_question_result['engagement_score_before']
    )
    
    reward = 0.6 * learning_gain + 0.4 * engagement_improvement
    return reward
```

**Training:**
- Offline training on historical interaction data
- Online learning (update bandit parameters in real-time)
- Exploration rate: 10% (epsilon-greedy fallback)

**Inference Request:**
```java
PredictRequest request = PredictRequest.newBuilder()
    .setEndpoint(vertexEndpoint)
    .addInstances(Value.newBuilder()
        .setStructValue(Struct.newBuilder()
            .putFields("engagement_score", Value.newBuilder().setNumberValue(0.38).build())
            .putFields("recent_accuracy", Value.newBuilder().setNumberValue(0.42).build())
            .putFields("current_difficulty", Value.newBuilder().setNumberValue(4).build())
            .build())
        .build())
    .build();

PredictResponse response = predictionClient.predict(request);
```

**Inference Response:**
```json
{
  "predictions": [
    {
      "selected_arm": 2,
      "expected_reward": 0.73,
      "arm_probabilities": [0.05, 0.68, 0.15, 0.08, 0.04],
      "exploration": false
    }
  ]
}
```

**Fallback Logic (if Vertex AI fails):**
```java
if (vertexAICallFailed || latency > 500ms) {
    // Rule-based fallback
    int newDifficulty;
    if (engagementScore < 0.3) {
        newDifficulty = Math.max(1, currentDifficulty - 2);
    } else if (engagementScore < 0.5) {
        newDifficulty = Math.max(1, currentDifficulty - 1);
    } else {
        newDifficulty = currentDifficulty; // no change
    }
    
    return new BanditDecision(
        selectedArm: newDifficulty,
        expectedReward: 0.5,  // conservative estimate
        fallbackUsed: true
    );
}
```

---

### 7.3 Gemini: Hint Generation

**Model:** gemini-1.5-pro (or gemini-1.5-flash for lower latency)

**Prompt Template:**
```
You are a patient and encouraging math tutor.

Student Context:
- Skill: {skillTag}
- Question Difficulty: {difficultyLevel}/5
- Incorrect Answer: {studentAnswer}
- Correct Answer (for your reference only): {correctAnswer}
- Previous Attempts: {previousAnswers}
- Attempt Number: {attemptNumber}

Generate a helpful hint (2-3 sentences) that:
1. Does NOT give away the answer directly
2. Identifies the likely misconception or error
3. Guides the student toward the correct approach
4. Is encouraging and age-appropriate

Hint:
```

**Example Request:**
```java
String prompt = """
    You are a patient and encouraging math tutor.
    
    Student Context:
    - Skill: algebra.linear-equations
    - Question Difficulty: 4/5
    - Incorrect Answer: x = 8
    - Correct Answer (for your reference only): x = -2
    - Previous Attempts: ["x = 10", "x = 5"]
    - Attempt Number: 3
    
    Generate a helpful hint (2-3 sentences) that:
    1. Does NOT give away the answer directly
    2. Identifies the likely misconception or error
    3. Guides the student toward the correct approach
    4. Is encouraging and age-appropriate
    
    Hint:
    """;

GenerateContentResponse response = geminiModel.generateContent(prompt);
String hint = response.getText();
```

**Example Response:**
```
It looks like you're adding when you should be subtracting. Remember, to isolate x, 
you need to do the opposite operation on both sides. Try working backwards from the 
right side of the equation first.
```

**Safety Filters:**
- Block harmful content (profanity, bias)
- Validate hint length (50-200 characters)
- Fallback to template hints if generation fails

**Latency Target:** 1-2 seconds (acceptable for hint generation)

---

### 7.4 Gemini: Instructor Tip Generation

**Prompt Template:**
```
You are an experienced instructional coach advising a classroom teacher.

Classroom Context:
- Class Size: {classSize}
- Current Topic: {currentTopic}
- Student Engagement Summary:
{engagementSummary}

Focus Student: {studentId} (anonymized)
- Current Engagement: {engagementScore} (declining)
- Struggling Skill: {skillTag}
- Recent Quiz Performance:
{recentQuizSummary}

Generate a coaching tip (3-4 sentences) for the instructor that:
1. Identifies the specific learning issue
2. Suggests ONE concrete, actionable intervention
3. Can be applied during the current class session or immediately after
4. Avoids educational jargon

Coaching Tip:
```

**Example Response:**
```
Student Alice appears to have a misconception about the order of operations in 
multi-step equations. She's consistently adding before multiplying, which leads 
to incorrect answers. Consider pausing the class for a quick 2-minute review of 
PEMDAS with a concrete example on the board. You might also pair Alice with a 
peer mentor who has mastered this concept for the next problem set.
```

**Rate Limiting:**
- Max 1 tip per student per 5 minutes
- Max 5 tips per classroom per minute (prevent tip spam)

---

## 8. Real-Time Delivery Mechanism

### 8.1 Technology Choice: WebSocket

**Selected:** WebSocket over SSE (Server-Sent Events)

**Rationale:**

| Feature | WebSocket | SSE | Decision |
|---------|-----------|-----|----------|
| Bidirectional | ✅ Yes | ❌ No | Needed for student answer submission |
| Browser Support | ✅ Universal | ⚠️ IE/Edge issues | WebSocket more compatible |
| Reconnection | Manual | Automatic | SSE advantage, but solvable |
| Message Format | Binary/Text | Text only | WebSocket more flexible |
| Firewall/Proxy | ⚠️ Some block | ✅ Standard HTTP | SSE advantage, but rare issue |

**Decision:** WebSocket for bidirectional communication and future extensibility

---

### 8.2 WebSocket Architecture

**Endpoint:** `wss://api.edupulse.com/ws`

**Authentication:**
```javascript
// Client-side connection
const token = getJWTToken(); // From OAuth flow
const ws = new WebSocket(
  `wss://api.edupulse.com/ws?token=${token}`
);

ws.onopen = () => {
  console.log('Connected to EduPulse');
  
  // Send initial subscription
  ws.send(JSON.stringify({
    type: 'subscribe',
    channels: ['adapt.actions', 'engagement.scores']
  }));
};
```

**Server-side validation:**
```java
@Component
public class WebSocketAuthInterceptor implements HandshakeInterceptor {
    
    @Override
    public boolean beforeHandshake(
            ServerHttpRequest request,
            ServerHttpResponse response,
            WebSocketHandler wsHandler,
            Map<String, Object> attributes) {
        
        String token = extractToken(request);
        
        if (token == null || !jwtValidator.validate(token)) {
            return false; // Reject connection
        }
        
        String userId = jwtValidator.extractUserId(token);
        String userRole = jwtValidator.extractRole(token); // "student" or "instructor"
        
        attributes.put("userId", userId);
        attributes.put("userRole", userRole);
        
        return true;
    }
}
```

---

### 8.3 Message Format

**Server → Client (Adaptation Action):**
```json
{
  "type": "adapt.action",
  "timestamp": 1735568400000,
  "payload": {
    "actionType": "DIFFICULTY_ADJUST",
    "difficultyAdjustment": {
      "fromLevel": 4,
      "toLevel": 2,
      "reason": "Engagement declining after 3 failed attempts"
    },
    "newQuestion": {
      "questionId": "q789",
      "text": "Solve for x: 2x + 4 = 10",
      "choices": ["x = 2", "x = 3", "x = 4", "x = 5"]
    }
  }
}
```

**Server → Client (Hint):**
```json
{
  "type": "adapt.action",
  "timestamp": 1735568401500,
  "payload": {
    "actionType": "HINT_PROVIDED",
    "hintContent": "Try isolating the variable by working backwards..."
  }
}
```

**Server → Client (Instructor Tip):**
```json
{
  "type": "instructor.tip",
  "timestamp": 1735568402000,
  "payload": {
    "tipType": "INTERVENTION_NEEDED",
    "priority": "HIGH",
    "message": "Student Alice may need 1-on-1 help with linear equations...",
    "affectedStudents": ["s123"],
    "suggestedAction": "Review substitution method"
  }
}
```

**Client → Server (Heartbeat):**
```json
{
  "type": "ping",
  "timestamp": 1735568405000
}
```

---

### 8.4 Reconnection Strategy

**Client-side reconnection logic:**
```typescript
class ResilientWebSocket {
  private ws: WebSocket | null = null;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 10;
  private reconnectDelay = 1000; // Start at 1 second
  
  connect(url: string) {
    this.ws = new WebSocket(url);
    
    this.ws.onopen = () => {
      console.log('WebSocket connected');
      this.reconnectAttempts = 0;
      this.reconnectDelay = 1000; // Reset delay
    };
    
    this.ws.onclose = (event) => {
      console.log('WebSocket closed', event.code, event.reason);
      this.attemptReconnect(url);
    };
    
    this.ws.onerror = (error) => {
      console.error('WebSocket error', error);
    };
  }
  
  private attemptReconnect(url: string) {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnection attempts reached');
      // Show user notification: "Connection lost. Please refresh."
      return;
    }
    
    this.reconnectAttempts++;
    
    console.log(
      `Reconnecting in ${this.reconnectDelay}ms (attempt ${this.reconnectAttempts})`
    );
    
    setTimeout(() => {
      this.connect(url);
    }, this.reconnectDelay);
    
    // Exponential backoff with jitter
    this.reconnectDelay = Math.min(
      this.reconnectDelay * 2 + Math.random() * 1000,
      30000 // Max 30 seconds
    );
  }
}
```

---

### 8.5 Scaling WebSocket Connections

**Challenge:** WebSocket connections are stateful and sticky to a specific pod

**Solution: Sticky Sessions + Redis Pub/Sub**

```
┌─────────────┐
│ Load        │
│ Balancer    │
│ (sticky     │
│  sessions)  │
└──────┬──────┘
       │
       ├──────────┬──────────┬──────────┐
       ▼          ▼          ▼          ▼
┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ Gateway  │ │ Gateway  │ │ Gateway  │ │ Gateway  │
│  Pod 1   │ │  Pod 2   │ │  Pod 3   │ │  Pod 4   │
└────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘
     │            │            │            │
     └────────────┴────────────┴────────────┘
                  │
                  ▼
         ┌────────────────┐
         │  Redis Pub/Sub │
         │  (session      │
         │   routing)     │
         └────────────────┘
```

**Implementation:**
```java
@Service
public class DistributedWebSocketRouter {
    
    private final RedisTemplate<String, String> redisTemplate;
    
    // When user connects
    public void registerConnection(String userId, String podId) {
        redisTemplate.opsForValue().set(
            "ws:route:" + userId,
            podId,
            Duration.ofHours(2)
        );
    }
    
    // When pushing message
    public void pushMessage(String userId, String message) {
        String podId = redisTemplate.opsForValue().get("ws:route:" + userId);
        
        if (podId == null) {
            log.warn("No active WebSocket session for user {}", userId);
            return;
        }
        
        // Publish to Redis channel for specific pod
        redisTemplate.convertAndSend("ws:pod:" + podId, new RoutedMessage(userId, message));
    }
}
```

---

## 9. Data Stores and Responsibilities

### 9.1 PostgreSQL

**Responsibility:** Persistent storage for structured data

**Schema:**

```sql
-- Student profiles
CREATE TABLE students (
    student_id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    grade_level INT,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Question bank
CREATE TABLE questions (
    question_id VARCHAR(50) PRIMARY KEY,
    skill_tag VARCHAR(100) NOT NULL,
    difficulty_level INT NOT NULL CHECK (difficulty_level BETWEEN 1 AND 5),
    question_text TEXT NOT NULL,
    answer_choices JSONB,
    correct_answer VARCHAR(10),
    explanation TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_questions_skill_difficulty ON questions(skill_tag, difficulty_level);

-- Session metadata
CREATE TABLE sessions (
    session_id VARCHAR(50) PRIMARY KEY,
    student_id VARCHAR(50) REFERENCES students(student_id),
    instructor_id VARCHAR(50),
    started_at TIMESTAMP NOT NULL,
    ended_at TIMESTAMP,
    topic VARCHAR(100)
);

-- Student skill proficiency (IRT model estimates)
CREATE TABLE skill_proficiency (
    student_id VARCHAR(50) REFERENCES students(student_id),
    skill_tag VARCHAR(100),
    proficiency_estimate DOUBLE PRECISION,
    last_updated TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (student_id, skill_tag)
);
```

**Access Patterns:**
- Quiz Service: Read questions by skill + difficulty
- Bandit Engine: Read skill proficiency for context
- Content Adapter: Read questions for adaptation
- Writes: Infrequent (question authoring, student enrollment)

**Scaling:**
- Read replicas for query load distribution
- Connection pooling (HikariCP)
- Query caching for frequently-accessed questions

---

### 9.2 Redis

**Responsibility:** High-speed caching and session state

**Data Structures:**

```
# WebSocket session routing
Key: ws:route:{userId}
Value: {podId}
TTL: 7200 seconds (2 hours)

# Student context cache (avoids frequent PostgreSQL lookups)
Key: student:{studentId}:context
Value: {
  currentSkillTag: "algebra.linear-equations",
  currentDifficulty: 4,
  recentQuestionIds: ["q123", "q456"],
  sessionId: "sess_abc",
  recentAccuracy: 0.42
}
TTL: 3600 seconds (1 hour)

# Quiz attempt counter
Key: quiz:attempt:{studentId}:{questionId}
Value: 3
TTL: 3600 seconds

# Rate limiting (tip generation)
Key: tip:ratelimit:{studentId}
Value: 1735568400
TTL: 300 seconds (5 minutes)

# Feature cache (engagement scores)
Key: feature:{studentId}:engagement
Value: {
  score: 0.38,
  trend: "DECLINING",
  lastUpdated: 1735568400000
}
TTL: 120 seconds (2 minutes)
```

**Access Patterns:**
- Realtime Gateway: WebSocket routing lookup
- Engagement Service: Feature caching
- Tip Service: Rate limiting
- Content Adapter: Student context lookup

---

### 9.3 BigQuery

**Responsibility:** Analytics, compliance, and event replay

**Tables:**

```sql
-- All Kafka topics replicated via Kafka Connect Sink
CREATE TABLE session_events (
    event_id STRING,
    session_id STRING,
    student_id STRING,
    event_type STRING,
    timestamp TIMESTAMP,
    payload JSON
) PARTITION BY DATE(timestamp);

CREATE TABLE quiz_answers (
    event_id STRING,
    session_id STRING,
    student_id STRING,
    question_id STRING,
    is_correct BOOL,
    attempt_number INT64,
    skill_tag STRING,
    timestamp TIMESTAMP,
    payload JSON
) PARTITION BY DATE(timestamp);

CREATE TABLE engagement_scores (
    event_id STRING,
    session_id STRING,
    student_id STRING,
    score FLOAT64,
    trend STRING,
    alert_threshold_crossed BOOL,
    timestamp TIMESTAMP,
    payload JSON
) PARTITION BY DATE(timestamp);

CREATE TABLE adapt_actions (
    event_id STRING,
    session_id STRING,
    student_id STRING,
    action_type STRING,
    model_name STRING,
    inference_latency_ms INT64,
    timestamp TIMESTAMP,
    payload JSON
) PARTITION BY DATE(timestamp);

CREATE TABLE instructor_tips (
    event_id STRING,
    session_id STRING,
    tip_type STRING,
    priority STRING,
    affected_students ARRAY<STRING>,
    timestamp TIMESTAMP,
    payload JSON
) PARTITION BY DATE(timestamp);
```

**Use Cases:**
- **Analytics:** Daily engagement reports, skill gap analysis
- **Compliance:** FERPA audit logs (all student interactions preserved)
- **Debugging:** Replay specific session events
- **A/B testing:** Compare bandit model versions

**Kafka Connect Configuration:**
```json
{
  "name": "bigquery-sink-connector",
  "config": {
    "connector.class": "com.wepay.kafka.connect.bigquery.BigQuerySinkConnector",
    "topics": "session.events,quiz.answers,engagement.scores,adapt.actions,instructor.tips",
    "project": "edupulse-prod",
    "defaultDataset": "kafka_events",
    "autoCreateTables": true,
    "sanitizeTopics": true,
    "key.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "key.converter.schema.registry.url": "${SCHEMA_REGISTRY_URL}",
    "value.converter.schema.registry.url": "${SCHEMA_REGISTRY_URL}"
  }
}
```

---

## 10. Failure Modes and Resiliency

### 10.1 AI Service Failure

**Failure:** Vertex AI endpoint returns 503 or times out

**Impact:**
- Bandit Engine cannot select difficulty adjustment
- Students stuck at current difficulty (no adaptation)

**Mitigation:**
```java
@Service
public class ResilientBanditService {
    
    @CircuitBreaker(name = "vertexAI", fallbackMethod = "fallbackPolicy")
    @Retry(name = "vertexAI", fallbackMethod = "fallbackPolicy")
    @TimeLimiter(name = "vertexAI", fallbackMethod = "fallbackPolicy")
    public BanditDecision selectAction(EngagementScore score, StudentContext context) {
        return vertexAIClient.predict(score, context);
    }
    
    private BanditDecision fallbackPolicy(
            EngagementScore score, 
            StudentContext context, 
            Exception ex) {
        
        log.warn("Vertex AI failed, using rule-based fallback", ex);
        
        // Simple rule-based policy
        int newDifficulty;
        if (score.getScore() < 0.3) {
            newDifficulty = Math.max(1, context.getCurrentDifficulty() - 2);
        } else if (score.getScore() < 0.5) {
            newDifficulty = Math.max(1, context.getCurrentDifficulty() - 1);
        } else {
            newDifficulty = context.getCurrentDifficulty();
        }
        
        return new BanditDecision(
            selectedArm: newDifficulty,
            expectedReward: 0.5,
            fallbackUsed: true,
            fallbackReason: ex.getMessage()
        );
    }
}
```

**Circuit Breaker Configuration:**
```yaml
resilience4j:
  circuitbreaker:
    instances:
      vertexAI:
        sliding-window-size: 10
        failure-rate-threshold: 50
        wait-duration-in-open-state: 30s
        permitted-number-of-calls-in-half-open-state: 3
  retry:
    instances:
      vertexAI:
        max-attempts: 2
        wait-duration: 500ms
  timelimiter:
    instances:
      vertexAI:
        timeout-duration: 1s
```

**Monitoring:**
- Alert if fallback usage > 10% (indicates Vertex AI issues)
- Track fallback decisions vs. AI decisions in separate metrics

---

### 10.2 Kafka Consumer Lag

**Failure:** Consumer falls behind producer (lag increasing)

**Causes:**
- Slow AI inference (Gemini taking 5+ seconds)
- Downstream service outage (PostgreSQL timeout)
- Underprovisioned consumers

**Detection:**
```yaml
spring:
  kafka:
    consumer:
      properties:
        max.poll.interval.ms: 300000  # 5 minutes
        session.timeout.ms: 30000     # 30 seconds
```

**Monitoring (Confluent Cloud UI):**
- Consumer lag per partition
- Alert if lag > 1000 messages or 5 minutes

**Mitigation:**

1. **Scale consumers horizontally:**
```bash
# Increase replica count in Kubernetes
kubectl scale deployment engagement-service --replicas=6
```

2. **Increase max.poll.records for faster throughput:**
```yaml
spring:
  kafka:
    consumer:
      max-poll-records: 500  # Default is 500, increase to 1000 for high throughput
```

3. **Pause processing during overload:**
```java
@Service
public class BackpressureAwareConsumer {
    
    @Autowired
    private KafkaListenerEndpointRegistry registry;
    
    @Scheduled(fixedRate = 10000)
    public void checkLag() {
        ConsumerGroupMetadata metadata = fetchConsumerGroupMetadata();
        
        if (metadata.getLag() > 5000) {
            log.warn("High lag detected, pausing consumer");
            registry.getListenerContainer("engagement-scorer-group").pause();
            
            // Resume after 30 seconds
            Executors.newSingleThreadScheduledExecutor().schedule(
                () -> registry.getListenerContainer("engagement-scorer-group").resume(),
                30,
                TimeUnit.SECONDS
            );
        }
    }
}
```

---

### 10.3 Schema Incompatibility

**Failure:** Consumer cannot deserialize message due to schema mismatch

**Example Error:**
```
org.apache.kafka.common.errors.SerializationException: 
Error deserializing Avro message for id 123
Caused by: org.apache.avro.AvroTypeException: 
Found int, expecting double
```

**Root Cause:** Producer deployed with incompatible schema (breaking change)

**Prevention:**
1. **CI/CD schema validation:**
```bash
# In CI pipeline, before deployment
curl -X POST \
  https://schema-registry.url/compatibility/subjects/quiz.answers-value/versions/latest \
  -d @new-schema.avsc

# Response:
# {"is_compatible": false}
# → Block deployment
```

2. **Schema Registry compatibility enforcement:**
```bash
# Set BACKWARD compatibility (rejects breaking changes)
confluent schema-registry cluster update --compatibility BACKWARD
```

**Mitigation (if already deployed):**

1. **Route to DLQ:**
```java
@KafkaListener(topics = "quiz.answers", groupId = "engagement-scorer", 
               errorHandler = "schemaErrorHandler")
public void consume(QuizAnswer answer) {
    // Process message
}

@Bean
public CommonErrorHandler schemaErrorHandler() {
    DefaultErrorHandler handler = new DefaultErrorHandler(
        (record, ex) -> {
            log.error("Schema deserialization failed, sending to DLQ", ex);
            dlqProducer.send(DLQ_TOPIC, record.key(), record.value());
        },
        new FixedBackOff(0, 0)  // No retries for schema errors
    );
    
    handler.addNotRetryableExceptions(SerializationException.class);
    return handler;
}
```

2. **Rollback producer deployment:**
```bash
# Rollback to previous version
kubectl rollout undo deployment/quiz-service
```

3. **Fix schema and redeploy:**
```bash
# Register compatible schema
curl -X POST \
  https://schema-registry.url/subjects/quiz.answers-value/versions \
  -d @fixed-schema.avsc

# Redeploy producer
kubectl apply -f quiz-service-deployment.yaml
```

---

### 10.4 DLQ Handling

**Purpose:** Capture messages that cannot be processed after retries

**DLQ Topics:**
- `session.events.dlq`
- `quiz.answers.dlq`
- `engagement.scores.dlq`
- `adapt.actions.dlq`
- `instructor.tips.dlq`

**DLQ Message Format:**
```json
{
  "original_topic": "quiz.answers",
  "original