# Backend Services

## Common Dependencies (All Services)

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

## 1. Event Ingest Service

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

## 2. Apache Flink Stream Processing

**Purpose:** Real-time streaming analytics for engagement scoring, pattern detection, and instructor metrics

**Deployment:** Flink cluster (Docker Compose locally, Confluent Cloud Flink for production)

### Engagement Analytics Job

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

### Instructor Metrics Job

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

**Local Setup:**

```bash
# Submit Instructor Metrics Job
docker exec -it jobmanager flink run \
  -c com.edupulse.flink.InstructorMetricsJob \
  /opt/flink/jobs/instructor-metrics.jar
```

---

## 3. Bandit Engine

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

## 4. Tip Service

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

## 5. Content Adapter Service

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

## 6. Realtime Gateway Service

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
