# EduPulse: Real-Time Adaptive Learning Platform

> **AI-powered adaptive learning with Confluent Kafka, Avro, and real-time engagement detection**

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Repository Structure](#repository-structure)
- [Quick Start](#quick-start)
- [Backend Services](#backend-services)
- [Frontend Application](#frontend-application)
- [Cloud & Infrastructure](#cloud--infrastructure)
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
- **Backend:** Spring Boot 3.2, Java 17, Kafka Streams
- **Frontend:** Next.js 14, React 18, TypeScript
- **Messaging:** Confluent Kafka, Schema Registry, Avro
- **AI/ML:** Vertex AI, Google Gemini
- **Data:** PostgreSQL, Redis, BigQuery
- **Deployment:** Docker, Google Cloud (GKE, Cloud SQL, Memorystore)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Frontend (Next.js)                       │
│  Student UI              │          Instructor Dashboard    │
└────────────┬─────────────┴──────────────────┬──────────────┘
             │ WebSocket                       │
             ▼                                 ▼
┌────────────────────────────────────────────────────────────┐
│              Realtime Gateway Service                       │
└────────────┬───────────────────────────────────────────────┘
             │
             ▼
┌────────────────────────────────────────────────────────────┐
│               Confluent Kafka Cluster                       │
│  Topics: quiz.answers, engagement.scores, adapt.actions,   │
│          instructor.tips, session.events                    │
└─────┬──────────────────────────────────────────────────────┘
      │
      ├──> Event Ingest Service (produces quiz.answers)
      ├──> Engagement Service (consumes quiz.answers, produces engagement.scores)
      ├──> Bandit Engine (consumes engagement.scores, produces adapt.actions)
      ├──> Tip Service (consumes engagement.scores, produces instructor.tips)
      └──> Content Adapter (consumes adapt.actions, enriches with questions)
```

---

## Repository Structure

```
edupulse/
├── backend/
│   ├── event-ingest-service/
│   │   ├── src/
│   │   ├── build.gradle
│   │   └── README.md
│   ├── engagement-service/
│   │   ├── src/
│   │   ├── build.gradle
│   │   └── README.md
│   ├── bandit-engine/
│   │   ├── src/
│   │   ├── build.gradle
│   │   └── README.md
│   ├── tip-service/
│   │   ├── src/
│   │   ├── build.gradle
│   │   └── README.md
│   ├── content-adapter/
│   │   ├── src/
│   │   ├── build.gradle
│   │   └── README.md
│   ├── realtime-gateway/
│   │   ├── src/
│   │   ├── build.gradle
│   │   └── README.md
│   └── shared/
│       └── avro-schemas/
│           ├── event-envelope.avsc
│           ├── quiz-answer.avsc
│           ├── engagement-score.avsc
│           ├── adapt-action.avsc
│           └── instructor-tip.avsc
├── frontend/
│   ├── src/
│   │   ├── app/
│   │   ├── components/
│   │   └── lib/
│   ├── package.json
│   └── README.md
├── infrastructure/
│   ├── docker-compose.yml
│   ├── k8s/
│   │   ├── services/
│   │   └── deployments/
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

- Java 17+
- Node.js 18+
- Docker Desktop
- Confluent Cloud account (or local Kafka with Docker)
- Google Cloud account (for Vertex AI, Gemini)

### One-Command Local Setup

```bash
# Clone repository
git clone https://github.com/your-org/edupulse.git
cd edupulse

# Start infrastructure (Kafka, PostgreSQL, Redis)
docker-compose up -d

# Set environment variables
cp .env.example .env
# Edit .env with your Confluent Cloud and GCP credentials

# Register Avro schemas
./scripts/register-schemas.sh

# Seed database
psql -h localhost -U edupulse -d edupulse -f scripts/seed-data.sql

# Start all backend services (in separate terminals)
cd backend/event-ingest-service && ./gradlew bootRun
cd backend/engagement-service && ./gradlew bootRun
cd backend/bandit-engine && ./gradlew bootRun
cd backend/realtime-gateway && ./gradlew bootRun

# Start frontend
cd frontend && npm install && npm run dev

# Open browser
open http://localhost:3000
```

---

## Backend Services

### Common Dependencies (All Services)

**build.gradle:**
```gradle
plugins {
    id 'java'
    id 'org.springframework.boot' version '3.2.1'
    id 'io.spring.dependency-management' version '1.1.4'
}

dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.kafka:spring-kafka'
    implementation 'io.confluent:kafka-avro-serializer:7.5.1'
    implementation 'org.apache.avro:avro:1.11.3'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
    
    // Database
    implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
    implementation 'org.postgresql:postgresql'
    
    // Redis
    implementation 'org.springframework.boot:spring-boot-starter-data-redis'
    
    // Observability
    implementation 'io.micrometer:micrometer-registry-prometheus'
}

repositories {
    mavenCentral()
    maven {
        url "https://packages.confluent.io/maven/"
    }
}
```

**Common application.yml:**
```yaml
spring:
  application:
    name: ${SERVICE_NAME:edupulse-service}
  
  kafka:
    bootstrap-servers: ${KAFKA_BOOTSTRAP_SERVERS}
    properties:
      security.protocol: SASL_SSL
      sasl.mechanism: PLAIN
      sasl.jaas.config: org.apache.kafka.common.security.plain.PlainLoginModule required username='${KAFKA_API_KEY}' password='${KAFKA_API_SECRET}';
      schema.registry.url: ${SCHEMA_REGISTRY_URL}
      basic.auth.credentials.source: USER_INFO
      basic.auth.user.info: ${SCHEMA_REGISTRY_KEY}:${SCHEMA_REGISTRY_SECRET}
      
    producer:
      key-serializer: io.confluent.kafka.serializers.KafkaAvroSerializer
      value-serializer: io.confluent.kafka.serializers.KafkaAvroSerializer
      acks: all
      retries: 3
      properties:
        enable.idempotence: true
        
    consumer:
      key-deserializer: io.confluent.kafka.serializers.KafkaAvroDeserializer
      value-deserializer: io.confluent.kafka.serializers.KafkaAvroDeserializer
      auto-offset-reset: earliest
      enable-auto-commit: false
      properties:
        specific.avro.reader: true

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus
  endpoint:
    health:
      show-details: always
```

---

### 1. Event Ingest Service

**Purpose:** Accept HTTP events from frontend, validate, enrich, publish to Kafka

**Responsibilities:**
- Receive quiz answer submissions
- Receive session events (navigation, dwell time)
- Validate request payloads
- Build Avro EventEnvelope
- Produce to Kafka topics

**Kafka Topics:**
- **Produces to:** `quiz.answers`, `session.events`
- **Consumes from:** None

**Schema Registry Subjects:**
- `quiz.answers-key` (QuizAnswerKey)
- `quiz.answers-value` (QuizAnswer)
- `session.events-value` (SessionEvent)

**API Endpoints:**

```
POST /api/events/session
Content-Type: application/json

{
  "sessionId": "sess_abc123",
  "studentId": "s123",
  "eventType": "NAVIGATION",
  "pageId": "lesson-3",
  "timestamp": 1735568400000
}

Response: 202 Accepted
{
  "eventId": "evt_xyz789",
  "status": "published"
}

---

POST /api/quiz/submit-answer
Content-Type: application/json

{
  "sessionId": "sess_abc123",
  "studentId": "s123",
  "questionId": "q456",
  "answer": "x = 3",
  "timeSpentMs": 45000
}

Response: 200 OK
{
  "isCorrect": false,
  "attemptNumber": 2,
  "eventId": "evt_answer_123"
}
```

**Environment Variables:**

```bash
SERVICE_NAME=event-ingest-service
SERVER_PORT=8081
KAFKA_BOOTSTRAP_SERVERS=pkc-xxxxx.us-east-1.aws.confluent.cloud:9092
KAFKA_API_KEY=YOUR_KAFKA_KEY
KAFKA_API_SECRET=YOUR_KAFKA_SECRET
SCHEMA_REGISTRY_URL=https://psrc-xxxxx.us-east-1.aws.confluent.cloud
SCHEMA_REGISTRY_KEY=YOUR_SR_KEY
SCHEMA_REGISTRY_SECRET=YOUR_SR_SECRET
POSTGRES_URL=jdbc:postgresql://localhost:5432/edupulse
POSTGRES_USER=edupulse
POSTGRES_PASSWORD=edupulse
```

**Local Setup:**

```bash
cd backend/event-ingest-service

# Run with Gradle
./gradlew bootRun

# Or build JAR
./gradlew clean build
java -jar build/libs/event-ingest-service-1.0.0.jar
```

**Health Check:**

```bash
curl http://localhost:8081/actuator/health

# Expected:
{
  "status": "UP",
  "components": {
    "kafka": {"status": "UP"},
    "db": {"status": "UP"}
  }
}
```

**DLQ Behavior:**

Event Ingest Service does not consume topics, so no DLQ. Produces with idempotent producer to ensure exactly-once delivery to Kafka.

**Troubleshooting:**

```bash
# Check Kafka connection
curl http://localhost:8081/actuator/health | jq '.components.kafka'

# View producer metrics
curl http://localhost:8081/actuator/prometheus | grep kafka_producer

# Enable debug logging
# Add to application.yml:
logging:
  level:
    org.apache.kafka: DEBUG
    io.confluent: DEBUG
```

---

### 2. Engagement Service

**Purpose:** Compute real-time engagement scores from streaming behavioral signals

**Responsibilities:**
- Consume quiz answers and session events
- Aggregate signals in 60-second tumbling windows
- Compute weighted engagement score
- Detect declining trends
- Trigger alerts when score < 0.4
- Produce engagement scores to Kafka

**Kafka Topics:**
- **Consumes from:** `quiz.answers`, `session.events`
- **Produces to:** `engagement.scores`
- **Consumer Group:** `engagement-scorer-group`

**Schema Registry Subjects:**
- `quiz.answers-value` (reads)
- `session.events-value` (reads)
- `engagement.scores-value` (writes)

**Processing Model:**

Uses Kafka Streams for stateful aggregation:

```java
KStream<String, QuizAnswer> quizAnswers = builder.stream("quiz.answers");
KStream<String, SessionEvent> sessionEvents = builder.stream("session.events");

// Join streams by studentId
KTable<Windowed<String>, StudentEngagementState> aggregated = 
    quizAnswers
        .selectKey((k, v) -> v.getEnvelope().getStudentId())
        .groupByKey()
        .windowedBy(TimeWindows.ofSizeWithNoGrace(Duration.ofSeconds(60)))
        .aggregate(
            StudentEngagementState::new,
            (key, value, aggregate) -> aggregate.update(value),
            Materialized.as("student-engagement-state")
        );

// Compute scores
aggregated
    .toStream()
    .mapValues(EngagementScoringService::computeScore)
    .filter((k, v) -> v != null)
    .to("engagement.scores");
```

**Scoring Formula:**

```
score = 0.3 * dwellScore + 0.4 * accuracyScore + 0.3 * pacingScore

dwellScore = 1 - (actual_time - expected_time) / expected_time
accuracyScore = correct_answers / total_attempts
pacingScore = questions_per_minute / baseline_pace

alertThresholdCrossed = (score < 0.4 && trend == DECLINING)
```

**Environment Variables:**

```bash
SERVICE_NAME=engagement-service
SERVER_PORT=8082
# ... (same Kafka/DB vars as Event Ingest)
ENGAGEMENT_WINDOW_SECONDS=60
ENGAGEMENT_ALERT_THRESHOLD=0.4
REDIS_HOST=localhost
REDIS_PORT=6379
```

**Local Setup:**

```bash
cd backend/engagement-service
./gradlew bootRun
```

**Health Check:**

```bash
curl http://localhost:8082/actuator/health

# Check Kafka Streams state
curl http://localhost:8082/actuator/metrics/kafka.stream.state
```

**DLQ Behavior:**

Deserialization failures sent to `quiz.answers.dlq`:

```java
@Bean
public CommonErrorHandler errorHandler() {
    DefaultErrorHandler handler = new DefaultErrorHandler(
        (record, ex) -> dlqProducer.send("quiz.answers.dlq", record),
        new FixedBackOff(1000L, 3)
    );
    handler.addNotRetryableExceptions(SerializationException.class);
    return handler;
}
```

**Troubleshooting:**

```bash
# Check consumer lag
kafka-consumer-groups --bootstrap-server <broker> \
  --group engagement-scorer-group --describe

# View Kafka Streams state store
curl http://localhost:8082/actuator/kafkastreams

# Query state store directly
curl http://localhost:8082/state/student-engagement-state/s123
```

---

### 3. Bandit Engine

**Purpose:** Select optimal adaptation action using Vertex AI multi-armed bandit

**Responsibilities:**
- Consume engagement scores (filter: alertThresholdCrossed)
- Fetch student context from PostgreSQL
- Build feature vector for Vertex AI
- Call Vertex AI prediction endpoint
- Parse bandit arm selection (difficulty level)
- Produce adaptation action to Kafka
- Fallback to rule-based policy if AI fails

**Kafka Topics:**
- **Consumes from:** `engagement.scores`
- **Produces to:** `adapt.actions`
- **Consumer Group:** `bandit-policy-group`

**Schema Registry Subjects:**
- `engagement.scores-value` (reads)
- `adapt.actions-value` (writes)

**Vertex AI Integration:**

```java
@Service
public class VertexAIBanditService {
    
    private final PredictionServiceClient client;
    
    @Value("${vertex.ai.endpoint}")
    private String endpoint;
    
    @CircuitBreaker(name = "vertexAI", fallbackMethod = "ruleBasedFallback")
    @TimeLimiter(name = "vertexAI")
    public CompletableFuture<BanditDecision> selectArm(
            EngagementScore score, 
            StudentContext context) {
        
        // Build feature vector
        Map<String, Value> features = Map.of(
            "engagement_score", toValue(score.getScore()),
            "recent_accuracy", toValue(context.getRecentAccuracy()),
            "current_difficulty", toValue(context.getCurrentDifficulty())
        );
        
        // Call Vertex AI
        PredictRequest request = PredictRequest.newBuilder()
            .setEndpoint(endpoint)
            .addInstances(toValue(features))
            .build();
            
        PredictResponse response = client.predict(request);
        
        // Parse response
        int selectedArm = extractArm(response);
        double expectedReward = extractReward(response);
        
        return CompletableFuture.completedFuture(
            new BanditDecision(selectedArm, expectedReward)
        );
    }
    
    private BanditDecision ruleBasedFallback(
            EngagementScore score, 
            StudentContext context,
            Exception ex) {
        
        log.warn("Vertex AI unavailable, using fallback", ex);
        
        int newDifficulty = context.getCurrentDifficulty();
        if (score.getScore() < 0.3) {
            newDifficulty = Math.max(1, newDifficulty - 2);
        } else if (score.getScore() < 0.5) {
            newDifficulty = Math.max(1, newDifficulty - 1);
        }
        
        return new BanditDecision(newDifficulty, 0.5, true);
    }
}
```

**Environment Variables:**

```bash
SERVICE_NAME=bandit-engine
SERVER_PORT=8083
# ... (Kafka/DB vars)
VERTEX_AI_PROJECT_ID=edupulse-prod
VERTEX_AI_LOCATION=us-central1
VERTEX_AI_ENDPOINT=projects/123/locations/us-central1/endpoints/456
GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
VERTEX_AI_TIMEOUT_MS=500
```

**Local Setup:**

```bash
cd backend/bandit-engine

# Set GCP credentials
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json

./gradlew bootRun
```

**Health Check:**

```bash
curl http://localhost:8083/actuator/health

# Test Vertex AI connection
curl http://localhost:8083/api/health/vertex-ai
```

**DLQ Behavior:**

Same as Engagement Service. Deserialization failures → `engagement.scores.dlq`

**Troubleshooting:**

```bash
# Check Vertex AI metrics
curl http://localhost:8083/actuator/prometheus | grep vertex_ai

# View fallback usage
curl http://localhost:8083/actuator/metrics/bandit.fallback.count

# Test Vertex AI endpoint directly
gcloud ai endpoints predict $VERTEX_AI_ENDPOINT \
  --region=us-central1 \
  --json-request=test-input.json
```

---

### 4. Tip Service

**Purpose:** Generate instructor coaching tips using Google Gemini

**Responsibilities:**
- Consume engagement scores (filter: score < 0.5)
- Join with recent quiz answers
- Rate limit tip generation (1 per student per 5 min)
- Build Gemini prompt with student context
- Call Gemini API
- Parse AI-generated tip
- Produce instructor tip to Kafka

**Kafka Topics:**
- **Consumes from:** `engagement.scores`, `quiz.answers`
- **Produces to:** `instructor.tips`
- **Consumer Group:** `tip-generation-group`

**Schema Registry Subjects:**
- `engagement.scores-value` (reads)
- `quiz.answers-value` (reads)
- `instructor.tips-value` (writes)

**Gemini Integration:**

```java
@Service
public class GeminiTipService {
    
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

**Rate Limiting (Redis):**

```java
@Service
public class TipRateLimiter {
    
    private final RedisTemplate<String, String> redis;
    
    public boolean allowTip(String studentId) {
        String key = "tip:ratelimit:" + studentId;
        Boolean exists = redis.hasKey(key);
        
        if (Boolean.TRUE.equals(exists)) {
            return false; // Rate limited
        }
        
        redis.opsForValue().set(key, "1", Duration.ofMinutes(5));
        return true;
    }
}
```

**Environment Variables:**

```bash
SERVICE_NAME=tip-service
SERVER_PORT=8084
# ... (Kafka/DB/Redis vars)
GEMINI_API_KEY=YOUR_GEMINI_API_KEY
GEMINI_MODEL=gemini-1.5-pro
GEMINI_TIMEOUT_MS=2000
TIP_RATE_LIMIT_MINUTES=5
```

**Local Setup:**

```bash
cd backend/tip-service
./gradlew bootRun
```

**Health Check:**

```bash
curl http://localhost:8084/actuator/health

# Test Gemini connection
curl http://localhost:8084/api/health/gemini
```

**Troubleshooting:**

```bash
# View Gemini latency
curl http://localhost:8084/actuator/metrics/gemini.latency

# Check rate limit hits
curl http://localhost:8084/actuator/metrics/tip.ratelimit.hit

# Test Gemini directly
curl -X POST "https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=$GEMINI_API_KEY" \
  -H 'Content-Type: application/json' \
  -d '{"contents":[{"parts":[{"text":"Test prompt"}]}]}'
```

---

### 5. Content Adapter Service

**Purpose:** Fetch and deliver adapted content based on policy decisions

**Responsibilities:**
- Consume adaptation actions (filter: DIFFICULTY_ADJUST)
- Query PostgreSQL question bank by skill + difficulty
- Avoid recently-seen questions (Redis cache)
- Enrich adapt.actions with question data
- Forward to Realtime Gateway

**Kafka Topics:**
- **Consumes from:** `adapt.actions`
- **Produces to:** `adapt.actions` (enriched)
- **Consumer Group:** `content-adapter-group`

**Schema Registry Subjects:**
- `adapt.actions-value` (reads and writes)

**Database Schema:**

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

**Question Selection Logic:**

```java
@Repository
public interface QuestionRepository extends JpaRepository<Question, String> {
    
    @Query("""
        SELECT q FROM Question q
        WHERE q.skillTag = :skillTag
        AND q.difficultyLevel = :difficulty
        AND q.questionId NOT IN :recentIds
        ORDER BY FUNCTION('RANDOM')
        LIMIT 1
        """)
    Optional<Question> findNextQuestion(
        @Param("skillTag") String skillTag,
        @Param("difficulty") int difficulty,
        @Param("recentIds") List<String> recentIds
    );
}
```

**Environment Variables:**

```bash
SERVICE_NAME=content-adapter
SERVER_PORT=8085
# ... (Kafka/DB/Redis vars)
```

**Local Setup:**

```bash
cd backend/content-adapter
./gradlew bootRun
```

**Seed Questions:**

```bash
psql -h localhost -U edupulse -d edupulse -f scripts/seed-data.sql
```

---

### 6. Realtime Gateway Service

**Purpose:** Manage WebSocket connections and push events to clients

**Responsibilities:**
- Accept WebSocket connections at `/ws`
- Authenticate connections (JWT)
- Store active sessions (Map<userId, WebSocketSession>)
- Consume adapt.actions and instructor.tips
- Route events to appropriate WebSocket sessions
- Handle disconnections and reconnections

**Kafka Topics:**
- **Consumes from:** `adapt.actions`, `instructor.tips`
- **Produces to:** None
- **Consumer Group:** `realtime-gateway`

**Schema Registry Subjects:**
- `adapt.actions-value` (reads)
- `instructor.tips-value` (reads)

**WebSocket Configuration:**

```java
@Configuration
@EnableWebSocket
public class WebSocketConfig implements WebSocketConfigurer {
    
    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(realtimeHandler(), "/ws")
            .setAllowedOrigins("*")
            .addInterceptors(authInterceptor());
    }
    
    @Bean
    public WebSocketHandler realtimeHandler() {
        return new RealtimeWebSocketHandler();
    }
}
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
        String userType = extractUserType(session);
        
        if ("student".equals(userType)) {
            studentSessions.put(userId, session);
        } else {
            instructorSessions.put(userId, session);
        }
        
        log.info("WebSocket connected: {} ({})", userId, userType);
    }
    
    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        String userId = extractUserId(session);
        studentSessions.remove(userId);
        instructorSessions.remove(userId);
        log.info("WebSocket disconnected: {}", userId);
    }
    
    public void pushToStudent(String studentId, AdaptAction action) {
        WebSocketSession session = studentSessions.get(studentId);
        if (session != null && session.isOpen()) {
            try {
                String json = objectMapper.writeValueAsString(Map.of(
                    "type", "adapt.action",
                    "payload", action
                ));
                session.sendMessage(new TextMessage(json));
            } catch (IOException e) {
                log.error("Failed to send to student {}", studentId, e);
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
        String sessionId = tip.getEnvelope().getSessionId();
        String instructorId = sessionService.getInstructorForSession(sessionId);
        wsHandler.pushToInstructor(instructorId, tip);
    }
}
```

**Environment Variables:**

```bash
SERVICE_NAME=realtime-gateway
SERVER_PORT=8086
# ... (Kafka vars)
JWT_SECRET=your-jwt-secret
WEBSOCKET_MAX_CONNECTIONS=1000
```

**Local Setup:**

```bash
cd backend/realtime-gateway
./gradlew bootRun
```

**Health Check:**

```bash
curl http://localhost:8086/actuator/health

# Check active connections
curl http://localhost:8086/actuator/metrics/websocket.connections.active
```

**WebSocket Test:**

```bash
# Install wscat: npm install -g wscat
wscat -c "ws://localhost:8086/ws?token=test-jwt-token"

# Should see:
# Connected
# (messages will appear as they're pushed)
```

---

## Frontend Application

### Overview

Next.js 14 application with TypeScript providing:
- Student adaptive learning UI
- Instructor real-time dashboard
- WebSocket-based real-time updates

### Project Structure

```
frontend/
├── src/
│   ├── app/
│   │   ├── student/
│   │   │   └── [studentId]/
│   │   │       └── page.tsx
│   │   ├── instructor/
│   │   │   └── dashboard/
│   │   │       └── page.tsx
│   │   └── layout.tsx
│   ├── components/
│   │   ├── student/
│   │   │   ├── QuestionDisplay.tsx
│   │   │   ├── AnswerForm.tsx
│   │   │   └── HintPanel.tsx
│   │   ├── instructor/
│   │   │   ├── EngagementHeatmap.tsx
│   │   │   └── TipsPanel.tsx
│   │   └── shared/
│   │       └── ConnectionStatus.tsx
│   └── lib/
│       ├── websocket.ts
│       ├── api.ts
│       └── types.ts
├── public/
├── package.json
└── README.md
```

### Student UI

**Route:** `/student/[studentId]`

**Features:**
- Question display with multiple choice answers
- Submit answer button
- Real-time hint panel
- Difficulty indicator (1-5 stars)
- Attempt counter
- Loading states

**Key Component:**

```typescript
// src/app/student/[studentId]/page.tsx
'use client';

import { useState, useEffect } from 'react';
import { useWebSocket } from '@/lib/websocket';
import QuestionDisplay from '@/components/student/QuestionDisplay';
import HintPanel from '@/components/student/HintPanel';

export default function StudentPage({ params }: { params: { studentId: string } }) {
  const [question, setQuestion] = useState(null);
  const [hint, setHint] = useState(null);
  const { message, connected } = useWebSocket(params.studentId, 'student');

  useEffect(() => {
    if (message?.type === 'adapt.action') {
      if (message.payload.actionType === 'DIFFICULTY_ADJUST') {
        setQuestion(message.payload.newQuestion);
      }
      if (message.payload.actionType === 'HINT_PROVIDED') {
        setHint(message.payload.hintContent);
      }
    }
  }, [message]);

  const handleSubmit = async (answer: string) => {
    const response = await fetch('/api/quiz/submit-answer', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        studentId: params.studentId,
        questionId: question.id,
        answer,
        timeSpentMs: Date.now() - questionStartTime,
      }),
    });
    
    const result = await response.json();
    if (result.isCorrect) {
      // Load next question
      fetchNextQuestion();
    }
  };

  return (
    <div className="max-w-2xl mx-auto p-6">
      <ConnectionStatus connected={connected} />
      <QuestionDisplay question={question} onSubmit={handleSubmit} />
      {hint && <HintPanel hint={hint} onClose={() => setHint(null)} />}
    </div>
  );
}
```

### Instructor Dashboard

**Route:** `/instructor/dashboard`

**Features:**
- Real-time engagement heatmap (3x3 grid of students)
- Color-coded tiles (green/yellow/red)
- Tips panel with priority badges
- Student drill-down view

**Key Component:**

```typescript
// src/app/instructor/dashboard/page.tsx
'use client';

import { useState, useEffect } from 'react';
import { useWebSocket } from '@/lib/websocket';
import EngagementHeatmap from '@/components/instructor/EngagementHeatmap';
import TipsPanel from '@/components/instructor/TipsPanel';

export default function InstructorDashboard() {
  const [engagementMap, setEngagementMap] = useState(new Map());
  const [tips, setTips] = useState([]);
  const { message } = useWebSocket('instructor_1', 'instructor');

  useEffect(() => {
    if (message?.type === 'engagement.update') {
      setEngagementMap(prev => new Map(prev).set(
        message.payload.studentId,
        message.payload.score
      ));
    }
    
    if (message?.type === 'instructor.tip') {
      setTips(prev => [message.payload, ...prev].slice(0, 10));
    }
  }, [message]);

  return (
    <div className="grid grid-cols-12 gap-4 p-6">
      <div className="col-span-8">
        <EngagementHeatmap data={engagementMap} />
      </div>
      <div className="col-span-4">
        <TipsPanel tips={tips} />
      </div>
    </div>
  );
}
```

### WebSocket Hook

```typescript
// src/lib/websocket.ts
import { useEffect, useState } from 'react';

interface WebSocketMessage {
  type: string;
  payload: any;
}

export function useWebSocket(userId: string, userType: 'student' | 'instructor') {
  const [message, setMessage] = useState<WebSocketMessage | null>(null);
  const [connected, setConnected] = useState(false);
  const [ws, setWs] = useState<WebSocket | null>(null);

  useEffect(() => {
    const token = getAuthToken(); // From localStorage or session
    const socket = new WebSocket(
      `ws://localhost:8086/ws?token=${token}&userId=${userId}&userType=${userType}`
    );

    socket.onopen = () => {
      console.log('WebSocket connected');
      setConnected(true);
    };

    socket.onmessage = (event) => {
      const data = JSON.parse(event.data);
      setMessage(data);
    };

    socket.onclose = () => {
      console.log('WebSocket disconnected');
      setConnected(false);
      
      // Reconnect after 2 seconds
      setTimeout(() => {
        setWs(null); // Trigger reconnection
      }, 2000);
    };

    socket.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    setWs(socket);

    return () => {
      socket.close();
    };
  }, [userId, userType]);

  return { message, connected, ws };
}
```

### Local Development Setup

```bash
cd frontend

# Install dependencies
npm install

# Set environment variables
cat > .env.local << EOF
NEXT_PUBLIC_API_URL=http://localhost:8081
NEXT_PUBLIC_WS_URL=ws://localhost:8086
EOF

# Run development server
npm run dev

# Open browser
open http://localhost:3000
```

### Demo / Simulation Mode

Add demo mode toggle for rapid testing:

```typescript
// src/lib/demo-mode.ts
export const DEMO_MODE = process.env.NEXT_PUBLIC_DEMO_MODE === 'true';

export const DEMO_CONFIG = {
  autoSubmitDelay: 2000, // Auto-submit answers after 2s
  skipAnimations: true,
  mockWebSocket: false,
};

// In components:
if (DEMO_MODE) {
  setTimeout(() => {
    handleSubmit(demoAnswers[currentIndex]);
  }, DEMO_CONFIG.autoSubmitDelay);
}
```

**Enable demo mode:**

```bash
NEXT_PUBLIC_DEMO_MODE=true npm run dev
```

### Build for Production

```bash
npm run build
npm run start
```

---

## Cloud & Infrastructure

### Required GCP Resources

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

#### 3. BigQuery (Optional Analytics)

```bash
# Create dataset
bq mk --dataset PROJECT_ID:kafka_events

# Create tables (via Kafka Connect or manual)
bq mk --table kafka_events.quiz_answers \
  event_id:STRING,student_id:STRING,question_id:STRING,is_correct:BOOL,timestamp:TIMESTAMP
```

#### 4. Cloud SQL (PostgreSQL)

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

#### 5. Memorystore (Redis)

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

**docker-compose.yml:**

```yaml
version: '3.8'

services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.1
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    ports:
      - "2181:2181"

  kafka:
    image: confluentinc/cp-kafka:7.5.1
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1

  schema-registry:
    image: confluentinc/cp-schema-registry:7.5.1
    depends_on:
      - kafka
    ports:
      - "8081:8081"
    environment:
      SCHEMA_REGISTRY_HOST_NAME: schema-registry
      SCHEMA_REGISTRY_KAFKASTORE_BOOTSTRAP_SERVERS: kafka:9092

  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: edupulse
      POSTGRES_USER: edupulse
      POSTGRES_PASSWORD: edupulse
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./scripts/seed-data.sql:/docker-entrypoint-initdb.d/seed.sql

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

volumes:
  postgres-data:
```

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

**Location:** `backend/shared/avro-schemas/`

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