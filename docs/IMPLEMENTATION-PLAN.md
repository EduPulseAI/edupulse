# EduPulse: 48-Hour Hackathon Implementation Plan

**Team Size:** 2-4 developers  
**Timeline:** 48 hours (2 days)  
**Objective:** Working demo showcasing real-time AI-driven adaptive learning

---

## 1. Assumptions

### What Can Be Mocked

✅ **Student Authentication**
- Hardcoded JWT tokens or session IDs
- No OAuth/SSO integration
- Pre-seeded student data

✅ **Question Bank**
- 10-15 hardcoded questions per difficulty level
- Single skill tag: `algebra.linear-equations`
- Static question pool (no authoring UI)

✅ **Instructor Dashboard Data**
- Single instructor, single classroom
- 3-5 simulated students (Alice, Bob, Charlie)
- Pre-generated student profiles

✅ **Vertex AI Training Data**
- Use pre-trained mock model or random selection with logging
- No real model training during hackathon
- Fallback to rule-based policy acceptable for demo

✅ **Historical Analytics**
- No BigQuery integration for MVP
- Can add Kafka Connect sink if time permits (hour 36-48)

✅ **Complex UI Polish**
- Basic styling acceptable (Tailwind utility classes)
- No custom animations (use CSS transitions)
- Mobile responsiveness not required

### What Must Be Real

🔴 **Confluent Kafka + Schema Registry + Avro**
- Real Confluent Cloud cluster (or local with Docker)
- All 5 core topics created
- Avro schemas registered in Schema Registry
- Producer/consumer using Confluent serializers

🔴 **Event Flow: Quiz Answer → Engagement Score → Adaptation**
- Real Kafka events flowing through system
- Stateful processing in Engagement Service
- Bandit decision published back to Kafka

🔴 **Vertex AI Inference Call**
- Real API call to Vertex AI endpoint
- Even if using mock model, must demonstrate real inference
- Show latency in UI/logs

🔴 **Gemini Hint Generation**
- Real Gemini API call with prompt
- Display AI-generated hint in student UI
- Show model name/latency in metadata

🔴 **WebSocket Real-Time Updates**
- Working WebSocket connection student → gateway
- Real-time difficulty change visible in UI
- Instructor dashboard updates without refresh

🔴 **Schema Evolution Demo**
- Show adding optional field to schema
- Deploy new producer/consumer without breaking
- Mention in demo presentation

---

## 2. Must-Have vs Nice-to-Have Features

### Must-Have (Critical Path)

| Feature                                      | Justification         | Demo Impact |
|----------------------------------------------|-----------------------|-------------|
| Quiz answer submission                       | Core interaction      | High        |
| Kafka event flow (3 topics minimum)          | Architecture proof    | High        |
| Avro serialization with Schema Registry      | Technical requirement | High        |
| Engagement score computation                 | Decision trigger      | High        |
| Vertex AI bandit call                        | AI integration        | High        |
| Gemini hint generation                       | AI creativity         | High        |
| WebSocket push to student                    | Real-time demo        | Critical    |
| Difficulty adjustment visible                | Core value prop       | Critical    |
| Instructor dashboard with engagement heatmap | Teacher impact        | High        |
| Schema evolution example                     | Governance story      | Medium      |

### Nice-to-Have (Stretch Goals)

| Feature                     | Time Required | Priority |
|-----------------------------|---------------|----------|
| Multiple skill tags         | 2-3 hours     | Low      |
| Attention tracking (webcam) | 4-6 hours     | Low      |
| BigQuery analytics sink     | 1-2 hours     | Medium   |
| DLQ topic + monitoring      | 2 hours       | Low      |
| Instructor tip generation   | 3-4 hours     | Medium   |
| Content adapter service     | 2-3 hours     | Low      |
| Session history / replay    | 3-4 hours     | Low      |
| Polish UI animations        | 2-3 hours     | Low      |

### Minimum Viable Demo (36-hour fallback)

If running behind schedule at hour 24, pivot to:
- 2 services only: Quiz Service + Engagement Service
- 2 topics: quiz.answers, engagement.scores
- Rule-based adaptation (no Vertex AI)
- Gemini hints only (skip instructor tips)
- Basic HTML UI (no fancy React)

---

## 3. Time-Boxed Execution Plan

### Hours 0-6: Foundation & Setup

**Goal:** Kafka cluster running, schemas registered, basic Spring Boot scaffold

#### Infrastructure (1 person)
- [ ] **0:00-0:30** - Create Confluent Cloud account + cluster
    - Standard tier, single region
    - Generate API keys (Kafka + Schema Registry)
- [ ] **0:30-1:00** - Create 5 topics in Confluent Cloud UI
    - `session.events` (6 partitions)
    - `quiz.answers` (6 partitions)
    - `engagement.scores` (6 partitions)
    - `adapt.actions` (6 partitions)
    - `instructor.tips` (3 partitions)
- [ ] **1:00-2:00** - Define 5 Avro schemas in `.avsc` files
    - EventEnvelope, QuizAnswer, EngagementScore, AdaptAction, InstructorTip
    - Use schemas from system design doc
- [ ] **2:00-2:30** - Register schemas in Schema Registry via curl/UI
    - Set BACKWARD compatibility
    - Test with sample payload
- [ ] **2:30-3:00** - Set up Google Cloud project
    - Enable Vertex AI API
    - Create service account with permissions
    - Download credentials JSON

#### Backend Team (2 people)
- [x] **0:00-1:00** - Spring Boot project scaffolding
    - Use Spring Initializr (Spring Boot 3.2, Java 17)
    - Dependencies: Spring Kafka, Spring Web, Spring WebSocket, PostgreSQL
    - Add Confluent Avro dependencies to `build.gradle`
- [x] **1:00-2:00** - Configure `application.yml` for Kafka
    - Bootstrap servers, Schema Registry URL
    - Avro serializer/deserializer configs
    - Test connection with simple producer/consumer
- [x] **2:00-3:00** - Generate Java classes from Avro schemas
    - Use `avro-maven-plugin` or manual `avro-tools`
    - Verify compilation
- [x] **3:00-4:00** - Build Quiz Service skeleton
    - REST endpoint: `POST /api/quiz/submit-answer`
    - Produce QuizAnswer to Kafka (hardcoded test data)
    - Manual test with curl
- [ ] **4:00-6:00** - Build Engagement Service skeleton
    - Kafka consumer for `quiz.answers`
    - Simple scoring logic (if incorrect, score = 0.4)
    - Produce EngagementScore to Kafka
    - Log consumed events

#### Frontend Team (1 person)
- [x] **0:00-1:00** - Next.js project setup
    - `npx create-next-app edupulse-ui`
    - Install dependencies: Tailwind CSS, WebSocket library
- [x] **1:00-3:00** - Basic student UI layout
    - Question display component
    - Multiple choice answer buttons
    - Submit button
    - Placeholder for hint panel
- [x] **3:00-4:00** - Wire submit button to backend
    - `POST /api/quiz/submit-answer`
    - Display "Correct!" or "Try again"
- [ ] **4:00-6:00** - Instructor dashboard skeleton
    - 3x3 grid of student tiles
    - Hardcoded engagement scores
    - Color coding (green/yellow/red)

**Milestone 1 (Hour 6):**
- ✅ Kafka cluster operational
- ✅ Schemas registered in Schema Registry
- ✅ Quiz Service produces Avro event
- ✅ Engagement Service consumes and produces Avro event
- ✅ Frontend can submit quiz answer

---

### Hours 6-12: End-to-End Event Flow

**Goal:** Quiz answer → engagement score → adaptation action, all via Kafka

#### Backend Team
- [ ] **6:00-7:00** - Refine engagement scoring logic
    - Track attempt count in Redis
    - Compute score based on accuracy + attempts
    - Set `alertThresholdCrossed = true` if score < 0.4
- [ ] **7:00-8:00** - Build Bandit Engine service
    - Consume `engagement.scores` (filter: alertThresholdCrossed)
    - Implement rule-based fallback policy:
        - If score < 0.3: reduce difficulty by 2
        - If score < 0.5: reduce difficulty by 1
    - Produce `AdaptAction` to Kafka
- [ ] **8:00-9:00** - Set up PostgreSQL (local or Cloud SQL)
    - Create `questions` table
    - Seed 10 questions per difficulty (1-5)
    - All skill_tag = `algebra.linear-equations`
- [ ] **9:00-10:00** - Build Content Adapter logic
    - Consume `adapt.actions`
    - Fetch new question from PostgreSQL by difficulty
    - Append question data to adapt.actions or call Realtime Gateway directly
- [ ] **10:00-12:00** - Build Realtime Gateway service
    - WebSocket server at `/ws`
    - Accept connections, store in `Map<studentId, WebSocketSession>`
    - Consume `adapt.actions` topic
    - Push JSON message to student's WebSocket

#### AI/Cloud Team
- [ ] **6:00-8:00** - Set up Vertex AI endpoint
    - Deploy pre-trained model OR create mock endpoint
    - Test inference with curl
    - Document expected input/output format
- [ ] **8:00-10:00** - Integrate Vertex AI into Bandit Engine
    - Add Google Cloud Vertex AI SDK dependency
    - Build feature vector from EngagementScore + context
    - Call endpoint, parse response
    - Log inference latency
- [ ] **10:00-12:00** - Set up Gemini API access
    - Enable Vertex AI Gemini API
    - Test with sample prompt via curl
    - Build hint generation prompt template

#### Frontend Team
- [ ] **6:00-8:00** - Implement WebSocket connection
    - Connect to `ws://localhost:8080/ws` on page load
    - Listen for messages
    - Log received events to console
- [ ] **8:00-10:00** - Display difficulty adjustment in UI
    - When `adapt.action` received with `DIFFICULTY_ADJUST`
    - Show toast notification: "Adjusting difficulty to help you..."
    - Fetch and display new question
- [ ] **10:00-12:00** - Polish student UI
    - Show current question difficulty (1-5 stars)
    - Display attempt count
    - Add loading state during submission

**Milestone 2 (Hour 12):**
- ✅ Complete event flow: answer → score → adapt action
- ✅ Bandit Engine selects new difficulty
- ✅ WebSocket pushes adaptation to student UI
- ✅ Student sees new question appear in real-time

---

### Hours 12-24: AI Integration & Real-Time Features

**Goal:** Vertex AI live, Gemini hints working, instructor dashboard updating

#### Backend Team
- [ ] **12:00-14:00** - Add Vertex AI to Bandit Engine (if not done)
    - Replace rule-based with real inference call
    - Add timeout + fallback (500ms timeout)
    - Log which path taken (AI vs fallback)
- [ ] **14:00-16:00** - Build Tip Service
    - Consume `engagement.scores`
    - Call Gemini API with prompt
    - Rate limit: max 1 tip per student per 5 min (Redis)
    - Produce `InstructorTip` to Kafka
- [ ] **16:00-18:00** - Enhance Realtime Gateway
    - Add instructor WebSocket connections
    - Consume `instructor.tips` topic
    - Push tips to instructor dashboard
    - Handle disconnections gracefully
- [ ] **18:00-20:00** - Add Redis caching
    - Student context cache
    - WebSocket session routing
    - Rate limiting for tips
- [ ] **20:00-22:00** - Implement hint generation in Bandit/separate service
    - Call Gemini API when difficulty adjusted
    - Include hint in `AdaptAction` payload
    - 2-second timeout with fallback template hints
- [ ] **22:00-24:00** - Error handling + logging
    - Add try-catch around AI calls
    - Log all Kafka events with correlation IDs
    - Add health check endpoints

#### AI/Cloud Team
- [ ] **12:00-14:00** - Tune Vertex AI inference
    - Optimize feature vector
    - Test latency (target < 200ms)
    - Add retries if needed
- [ ] **14:00-18:00** - Build Gemini hint generation
    - Create prompt template with student context
    - Test with various incorrect answers
    - Validate hint quality (not giving away answer)
- [ ] **18:00-20:00** - Integrate Gemini into Tip Service
    - Build instructor coaching prompt
    - Test with engagement score scenarios
    - Validate tip actionability
- [ ] **20:00-24:00** - Performance optimization
    - Cache Gemini responses for common patterns
    - Parallel AI calls where possible
    - Monitor latencies

#### Frontend Team
- [ ] **12:00-14:00** - Display hints in student UI
    - Hint panel with lightbulb icon
    - Animate slide-in when hint received
    - Clear hint on new question
- [ ] **14:00-16:00** - Build instructor dashboard heatmap
    - Real-time engagement scores via WebSocket
    - Update tile colors (green/yellow/red)
    - Show student names
- [ ] **16:00-18:00** - Add instructor tips panel
    - Scrollable list of tips
    - Priority badges (HIGH, MEDIUM, LOW)
    - "Mark as addressed" button
- [ ] **18:00-20:00** - Polish UI styling
    - Consistent color scheme
    - Tailwind utility classes
    - Responsive layout for demo screen
- [ ] **20:00-22:00** - Add loading states
    - Spinner during quiz submission
    - "Thinking..." while AI generates hint
    - Connection status indicator
- [ ] **22:00-24:00** - Error handling in UI
    - Show error toast if submission fails
    - WebSocket reconnection logic
    - Graceful degradation

**Milestone 3 (Hour 24):**
- ✅ Vertex AI inference live
- ✅ Gemini hints appearing in student UI
- ✅ Instructor dashboard showing real-time engagement
- ✅ Instructor tips being generated and displayed

---

### Hours 24-36: Schema Evolution, Testing, Demo Prep

**Goal:** Schema governance demo ready, end-to-end tests passing, demo script written

#### Backend Team
- [ ] **24:00-26:00** - Schema evolution demo preparation
    - Create v2 schema with optional field (e.g., `attentionScore`)
    - Register v2 in Schema Registry
    - Deploy consumer that handles v1 and v2
    - Deploy producer that writes v2
    - Document compatibility check
- [ ] **26:00-28:00** - Integration testing
    - Test full flow: answer → score → adapt → UI
    - Test with 3 students concurrently
    - Test schema incompatibility (breaking change)
    - Verify DLQ handling
- [ ] **28:00-30:00** - Add observability
    - Spring Boot Actuator endpoints
    - Log key metrics (latency, throughput)
    - Add correlation IDs to all events
- [ ] **30:00-32:00** - Prepare demo data
    - Seed 5 pre-configured questions
    - Create demo student accounts (Alice, Bob, Charlie)
    - Pre-populate some session history
- [ ] **32:00-34:00** - Bug fixes from testing
    - Fix any race conditions
    - Handle edge cases (no questions available)
    - Improve error messages
- [ ] **34:00-36:00** - Performance tuning
    - Optimize Kafka consumer config
    - Reduce unnecessary database queries
    - Enable Redis caching where applicable

#### AI/Cloud Team
- [ ] **24:00-26:00** - Test AI failure scenarios
    - Vertex AI timeout → fallback triggered
    - Gemini API error → template hint used
    - Verify fallback logic works
- [ ] **26:00-28:00** - Optimize AI prompts
    - Shorten Gemini prompts for lower latency
    - Add examples to prompts for better quality
    - Test with various student scenarios
- [ ] **28:00-30:00** - Monitor AI costs
    - Check Vertex AI billing
    - Estimate Gemini API costs for demo
    - Optimize if needed (use Gemini Flash)
- [ ] **30:00-32:00** - Document AI model details
    - Model names, versions
    - Input/output schemas
    - Latency benchmarks
- [ ] **32:00-36:00** - Prepare AI demo talking points
    - Explain bandit algorithm
    - Show Gemini prompt engineering
    - Highlight real-time inference

#### Frontend Team
- [ ] **24:00-26:00** - Add demo mode toggle
    - Speed up animations for demo
    - Keyboard shortcuts for demo flow
    - Auto-populate answers for quick testing
- [ ] **26:00-28:00** - UI testing
    - Test on Chrome, Firefox, Safari
    - Test WebSocket reconnection
    - Test with multiple students open simultaneously
- [ ] **28:00-30:00** - Record demo video (backup)
    - Screen recording of full flow
    - Voiceover explaining each step
    - Upload to YouTube (unlisted)
- [ ] **30:00-32:00** - Create demo script
    - Step-by-step walkthrough
    - Timing for each section (3 min total)
    - Contingency plans
- [ ] **32:00-34:00** - Polish final UI details
    - Fix any visual bugs
    - Improve button hover states
    - Add favicon and page title
- [ ] **34:00-36:00** - Prepare instructor dashboard demo
    - Pre-position windows for dual-screen demo
    - Practice switching between views
    - Set up simulated students

**Milestone 4 (Hour 36):**
- ✅ Schema evolution demo works
- ✅ End-to-end tests passing
- ✅ Demo script written and rehearsed
- ✅ Backup video recorded

---

### Hours 36-48: Final Polish, Rehearsal, Presentation

**Goal:** Demo-ready system, polished presentation, team prepared

#### All Team Members
- [ ] **36:00-38:00** - Full team demo rehearsal #1
    - Run through entire 3-minute demo
    - Time each section
    - Identify issues
- [ ] **38:00-40:00** - Fix critical issues from rehearsal
    - Any bugs discovered
    - Timing adjustments
    - UI tweaks
- [ ] **40:00-42:00** - Create presentation slides (5 slides max)
    - Slide 1: Problem statement
    - Slide 2: Architecture diagram
    - Slide 3: Kafka + Avro + Schema Registry
    - Slide 4: AI Integration (Vertex + Gemini)
    - Slide 5: Impact + Future work
- [ ] **42:00-44:00** - Full team demo rehearsal #2
    - Practice with slides
    - Assign speaker roles
    - Refine talking points
- [ ] **44:00-46:00** - Final polish
    - Fix any remaining visual issues
    - Optimize demo flow
    - Prepare Q&A responses
- [ ] **46:00-47:00** - Full team demo rehearsal #3
    - Final run-through
    - Backup plans for each failure mode
    - Confirm everyone knows their role
- [ ] **47:00-48:00** - Pre-demo checklist
    - Kafka cluster healthy
    - All services running
    - WebSocket connections stable
    - Demo data seeded
    - Backup video accessible
    - Laptop charged, HDMI adapter ready

**Milestone 5 (Hour 48):**
- ✅ Polished, rehearsed demo
- ✅ Presentation slides ready
- ✅ Team confident and prepared
- ✅ Backup plans in place

---

## 4. Task Breakdown by Role

### Backend Developer #1 (Core Services)

**Total: 32 hours of focused work**

| Task | Hours | Critical? |
|------|-------|-----------|
| Spring Boot scaffolding | 1 | ✅ |
| Kafka producer/consumer setup | 2 | ✅ |
| Quiz Service (submit answer) | 2 | ✅ |
| Engagement Service (scoring) | 3 | ✅ |
| Bandit Engine (policy selection) | 4 | ✅ |
| Realtime Gateway (WebSocket) | 4 | ✅ |
| Redis integration | 2 | ✅ |
| PostgreSQL schema + seeding | 2 | ✅ |
| Error handling + logging | 3 | ✅ |
| Integration testing | 3 | ✅ |
| Bug fixes | 3 | ✅ |
| Demo preparation | 3 | ✅ |

### Backend Developer #2 (AI Services)

**Total: 32 hours of focused work**

| Task | Hours | Critical? |
|------|-------|-----------|
| Avro schema definitions | 2 | ✅ |
| Schema Registry setup | 1 | ✅ |
| Vertex AI integration | 4 | ✅ |
| Gemini hint generation | 4 | ✅ |
| Tip Service (instructor coaching) | 3 | ⚠️ |
| Content Adapter Service | 2 | ⚠️ |
| AI fallback logic | 2 | ✅ |
| Performance tuning | 3 | ✅ |
| Schema evolution demo | 3 | ✅ |
| Observability (metrics, logs) | 2 | ✅ |
| Testing AI failure modes | 3 | ✅ |
| Documentation | 3 | ✅ |

### Frontend Developer

**Total: 32 hours of focused work**

| Task | Hours | Critical? |
|------|-------|-----------|
| Next.js project setup | 1 | ✅ |
| Student UI layout | 3 | ✅ |
| Quiz submission flow | 2 | ✅ |
| WebSocket integration | 3 | ✅ |
| Display difficulty adjustment | 2 | ✅ |
| Hint panel | 2 | ✅ |
| Instructor dashboard heatmap | 4 | ✅ |
| Instructor tips panel | 3 | ✅ |
| UI styling (Tailwind) | 3 | ✅ |
| Loading states + error handling | 2 | ✅ |
| Demo mode features | 2 | ⚠️ |
| Testing | 2 | ✅ |
| Demo rehearsal + fixes | 3 | ✅ |

### DevOps/Infrastructure (Shared Responsibility)

**Total: 12 hours (distributed across team)**

| Task | Hours | Owner |
|------|-------|-------|
| Confluent Cloud setup | 1 | Backend #1 |
| Topic creation | 0.5 | Backend #1 |
| Schema Registry config | 0.5 | Backend #2 |
| Google Cloud project setup | 1 | Backend #2 |
| PostgreSQL deployment | 1 | Backend #1 |
| Redis deployment | 1 | Backend #1 |
| Local development environment | 2 | All |
| Deployment scripts | 1 | Backend #1 |
| Monitoring setup | 2 | Backend #2 |
| Pre-demo infrastructure check | 2 | All |

---

## 5. Key Milestones (Go/No-Go Decision Points)

### Milestone 1: Foundation (Hour 6)

**Criteria:**
- [ ] Kafka cluster accessible from local machines
- [ ] At least 3 topics created (quiz.answers, engagement.scores, adapt.actions)
- [ ] Schema Registry has at least 2 schemas registered
- [ ] One Spring Boot service produces Avro event
- [ ] One Spring Boot service consumes Avro event
- [ ] Frontend can make HTTP call to backend

**Go/No-Go:** If not achieved by hour 6, skip instructor features and focus on student flow only

---

### Milestone 2: Event Flow (Hour 12)

**Criteria:**
- [ ] Quiz answer flows through Kafka to engagement scorer
- [ ] Engagement score triggers adaptation decision
- [ ] Adaptation decision reaches Realtime Gateway
- [ ] WebSocket connection established
- [ ] Student UI receives at least one real-time message

**Go/No-Go:** If not achieved by hour 12, consider dropping Vertex AI and using only rule-based policy

---

### Milestone 3: AI Integration (Hour 24)

**Criteria:**
- [ ] Vertex AI inference call succeeds (even with mock model)
- [ ] Gemini hint generation working
- [ ] Hint appears in student UI within 2 seconds
- [ ] Instructor dashboard shows real-time engagement scores
- [ ] Fallback logic tested and working

**Go/No-Go:** If not achieved by hour 24, focus remaining time on polish and rehearsal (no new features)

---

### Milestone 4: Demo Readiness (Hour 36)

**Criteria:**
- [ ] End-to-end demo flow works 3 times consecutively
- [ ] Schema evolution example prepared
- [ ] Backup video recorded
- [ ] Demo script written
- [ ] All critical bugs fixed

**Go/No-Go:** If not achieved by hour 36, simplify demo to 2-minute version with fewer features

---

### Milestone 5: Final Check (Hour 47)

**Criteria:**
- [ ] Demo rehearsed 3+ times
- [ ] All services healthy
- [ ] Presentation slides complete
- [ ] Q&A preparation done
- [ ] Backup plans documented

**Go/No-Go:** No turning back—present with what you have!

---

## 6. Testing Strategy (Within 48 Hours)

### Avro Schema Validation (Hours 2-3)

**Tests:**
```bash
# Test 1: Schema registration
curl -X POST \
  https://schema-registry.url/subjects/quiz.answers-value/versions \
  -d @quiz-answer.avsc

# Expected: {"id": 1}

# Test 2: Compatibility check (breaking change)
curl -X POST \
  https://schema-registry.url/compatibility/subjects/quiz.answers-value/versions/latest \
  -d @quiz-answer-v2-breaking.avsc

# Expected: {"is_compatible": false}

# Test 3: Compatibility check (safe addition)
curl -X POST \
  https://schema-registry.url/compatibility/subjects/quiz.answers-value/versions/latest \
  -d @quiz-answer-v2-safe.avsc

# Expected: {"is_compatible": true}
```

---

### Kafka Integration Smoke Tests (Hours 10-12)

**Test 1: Producer → Consumer**
```java
@Test
public void testQuizAnswerProducerConsumer() {
    // Produce
    QuizAnswer answer = QuizAnswer.newBuilder()
        .setEnvelope(buildEnvelope())
        .setQuestionId("q1")
        .setIsCorrect(false)
        .setAttemptNumber(1)
        .build();
    
    kafkaTemplate.send("quiz.answers", answer).get();
    
    // Consume (poll for 5 seconds)
    ConsumerRecords<String, QuizAnswer> records = 
        consumer.poll(Duration.ofSeconds(5));
    
    assertEquals(1, records.count());
    QuizAnswer consumed = records.iterator().next().value();
    assertEquals("q1", consumed.getQuestionId());
}
```

**Test 2: Schema Evolution**
```java
@Test
public void testBackwardCompatibility() {
    // Produce with v1 schema (no attentionScore)
    EngagementScore v1 = EngagementScore.newBuilder()
        .setScore(0.5)
        .setScoreComponents(
            ScoreComponents.newBuilder()
                .setDwellScore(0.5)
                .setAccuracyScore(0.5)
                .setPacingScore(0.5)
                .build()
        )
        .build();
    
    // Consumer with v2 schema (has attentionScore) should still work
    // attentionScore will be null
    kafkaTemplate.send("engagement.scores", v1).get();
    
    ConsumerRecords<String, EngagementScore> records = 
        consumerV2.poll(Duration.ofSeconds(5));
    
    EngagementScore consumed = records.iterator().next().value();
    assertNull(consumed.getScoreComponents().getAttentionScore());
}
```

---

### End-to-End Demo Flow Test (Hours 26-28)

**Manual Test Checklist:**

```
Student Flow:
1. [ ] Open student UI (http://localhost:3000/student/alice)
2. [ ] See question: "Solve for x: 3x + 6 = 15"
3. [ ] Select wrong answer: "x = 5"
4. [ ] Click Submit
5. [ ] See "Incorrect, try again"
6. [ ] Question remains (attempt 2)
7. [ ] Select wrong answer again: "x = 4"
8. [ ] Click Submit
9. [ ] See "Incorrect, try again"
10. [ ] Select wrong answer third time: "x = 2"
11. [ ] Click Submit
12. [ ] Within 2 seconds:
    - [ ] See hint appear: "Try working backwards..."
    - [ ] See new easier question: "Solve for x: 2x + 4 = 10"
    - [ ] See difficulty indicator change (4 → 2 stars)

Instructor Flow (parallel browser window):
1. [ ] Open instructor dashboard (http://localhost:3000/instructor/dashboard)
2. [ ] See 3 student tiles (Alice, Bob, Charlie)
3. [ ] Alice's tile is green (score 0.72)
4. [ ] Watch Alice's tile turn yellow (score 0.51) after attempt 2
5. [ ] Watch Alice's tile turn red (score 0.38) after attempt 3
6. [ ] Within 3 seconds:
    - [ ] See tip appear in tips panel
    - [ ] Tip mentions "Alice" and "linear equations"
    - [ ] Priority badge shows "HIGH"
7. [ ] Watch Alice's tile recover to yellow/green as she answers easier question

Backend Verification:
1. [ ] Check Confluent Cloud UI: see events in all 5 topics
2. [ ] Check logs: see Vertex AI inference latency (~200ms)
3. [ ] Check logs: see Gemini API call latency (~1500ms)
4. [ ] Check Redis: see student context cached
5. [ ] Check PostgreSQL: verify question fetched by difficulty
```

---

### Demo Readiness Checklist (Hour 46)

**Infrastructure:**
- [ ] Confluent Cloud cluster healthy (no broker issues)
- [ ] All 5 topics have messages (verify in UI)
- [ ] Schema Registry shows 5+ schemas
- [ ] Google Cloud project has no billing alerts
- [ ] Vertex AI endpoint is warm (pre-call to avoid cold start)
- [ ] PostgreSQL has 50+ questions seeded
- [ ] Redis is reachable and empty (flush before demo)

**Services:**
- [ ] Quiz Service health check: `curl localhost:8080/actuator/health` → UP
- [ ] Engagement Service health check: UP
- [ ] Bandit Engine health check: UP
- [ ] Realtime Gateway health check: UP
- [ ] Tip Service health check: UP
- [ ] All services logging to console (visible during demo)

**Frontend:**
- [ ] Student UI loads without errors
- [ ] Instructor dashboard loads without errors
- [ ] WebSocket connection indicator shows "Connected"
- [ ] No console errors in browser DevTools
- [ ] Tested on Chrome (primary) and Firefox (backup)

**Demo Data:**
- [ ] 3 student accounts created (Alice, Bob, Charlie)
- [ ] Alice's session pre-configured for demo flow
- [ ] Questions q1-q5 are demo-friendly (clear correct answers)
- [ ] Hint templates loaded for fallback

**Presentation:**
- [ ] Slides exported as PDF (backup if PowerPoint fails)
- [ ] Demo script printed or on second monitor
- [ ] Talking points memorized
- [ ] Timer set for 3-minute demo
- [ ] Backup video accessible (YouTube link in clipboard)

**Team:**
- [ ] Primary presenter identified
- [ ] Backup presenter identified
- [ ] Roles assigned (who answers tech questions, who handles setup)
- [ ] Practiced Q&A for: schema evolution, why Kafka, why Avro, AI models

---

## 7. Risks and Mitigation Strategies

### Risk 1: Confluent Cloud Setup Takes Too Long

**Probability:** Medium  
**Impact:** High (blocks everything)

**Mitigation:**
- **Hour 0:** Start Confluent Cloud signup immediately
- **Backup:** Run local Kafka + Schema Registry with Docker
  ```bash
  docker-compose up -d  # Pre-configured docker-compose.yml
  ```
- **Decision Point:** If not working by hour 2, switch to local setup

---

### Risk 2: Avro Schema Serialization Issues

**Probability:** High  
**Impact:** High (core requirement)

**Mitigation:**
- **Prevention:** Use exact Confluent dependency versions from documentation
  ```gradle
  implementation 'io.confluent:kafka-avro-serializer:7.5.1'
  ```
- **Debugging:** Enable Kafka debug logging early
  ```yaml
  logging.level.org.apache.kafka: DEBUG
  ```
- **Backup:** Have sample working code from Confluent examples repo ready to copy

---

### Risk 3: Vertex AI Inference Too Slow or Fails

**Probability:** Medium  
**Impact:** Medium (can use fallback)

**Mitigation:**
- **Prevention:** Test Vertex AI endpoint in hour 6-8
- **Fallback:** Rule-based policy already implemented
- **Demo Strategy:** Show fallback as "resilience feature" if AI fails
- **Backup:** Use mock Vertex AI responses (pre-recorded JSON)

---

### Risk 4: Gemini API Rate Limits or Quota

**Probability:** Low  
**Impact:** Medium

**Mitigation:**
- **Prevention:** Request quota increase on day 1
- **Caching:** Cache Gemini responses for identical prompts (Redis)
- **Fallback:** Template hints (10-15 pre-written hints)
- **Demo Strategy:** Generate hints during setup, not live during demo

---

### Risk 5: WebSocket Connections Drop During Demo

**Probability:** Medium  
**Impact:** High (kills real-time demo)

**Mitigation:**
- **Prevention:** Test WebSocket stability with 5-minute connection
- **Reconnection:** Implement exponential backoff (already in plan)
- **Demo Strategy:** Pre-connect 2 minutes before demo starts
- **Backup:** Use polling (SSE) if WebSocket fails
- **Nuclear Option:** Fake the WebSocket push (manual button to trigger)

---

### Risk 6: Team Member Gets Sick or Can't Attend

**Probability:** Low  
**Impact:** High

**Mitigation:**
- **Prevention:** Cross-train on critical components
- **Documentation:** Keep README updated hourly
- **Backup:** Each role has designated backup person
- **Nuclear Option:** 2-person minimum viable team:
    - Person 1: Backend (all services)
    - Person 2: Frontend + demo presentation

---

### Risk 7: Demo Environment Fails Minutes Before Presentation

**Probability:** Medium  
**Impact:** Critical

**Mitigation:**
- **Prevention:** Run full demo 3 times in hour 42-46
- **Backup Video:** Record perfect run in hour 32
- **Backup Environment:** Second laptop with full setup
- **Nuclear Option:** Present architecture slides + video only

---

### Risk 8: Judges Ask Hard Technical Questions

**Probability:** High  
**Impact:** Medium (can hurt score)

**Mitigation:**
- **Preparation:** Prepare answers to common questions:
    - "Why Avro instead of JSON?" → Schema enforcement, smaller payloads, compatibility
    - "Why Kafka instead of Pub/Sub?" → Explicit requirement, plus event sourcing
    - "How do you handle data privacy?" → Anonymized student IDs, FERPA compliance
    - "What's the bandit algorithm?" → Thompson Sampling / LinUCB (mention paper)
    - "Why real-time instead of batch?" → 30-second intervention window
- **Strategy:** If stumped, be honest: "Great question, we'd explore that in production"

---

### Risk 9: Schema Evolution Demo Doesn't Work

**Probability:** Medium  
**Impact:** Low (not critical for demo)

**Mitigation:**
- **Simplification:** Just show schema in UI, don't deploy live
- **Backup:** Show compatibility check in Confluent Cloud UI
- **Talking Points:** "We tested this offline and it works with BACKWARD compatibility"

---

### Risk 10: Team Burnout After Hour 36

**Probability:** High  
**Impact:** Medium

**Mitigation:**
- **Breaks:** Mandatory 15-minute break every 4 hours
- **Sleep:** Encourage 6 hours sleep between days
- **Food:** Order meals, don't skip
- **Morale:** Celebrate milestones (hour 12, 24, 36)
- **Simplification:** Cut nice-to-have features aggressively to reduce pressure

---

## 8. Success Metrics

**Minimum Viable Demo (Pass):**
- [ ] Quiz answer → engagement score → difficulty adjustment
- [ ] Kafka + Avro visibly working
- [ ] At least 1 AI call (Vertex or Gemini)
- [ ] WebSocket real-time update visible
- [ ] Schema Registry shown in UI

**Strong Demo (Top 25%):**
- [ ] All of above, plus:
- [ ] Vertex AI + Gemini both working
- [ ] Instructor dashboard with live updates
- [ ] Schema evolution demonstrated
- [ ] Sub-500ms intervention latency

**Exceptional Demo (Top 10%):**
- [ ] All of above, plus:
- [ ] Instructor tips generated by Gemini
- [ ] DLQ handling shown
- [ ] Multiple students simulated concurrently
- [ ] Polished UI with smooth animations
- [ ] Compelling narrative about educational impact

---

## 9. Final Pre-Demo Checklist (Hour 47:30)

**30 Minutes Before Demo:**

- [ ] **Infrastructure**
    - [ ] Restart all services (fresh state)
    - [ ] Flush Redis (clear cache)
    - [ ] Verify Kafka cluster (no lag)
    - [ ] Pre-warm Vertex AI endpoint (make test call)
    - [ ] Check internet connection speed

- [ ] **Demo Setup**
    - [ ] Open student UI (http://localhost:3000/student/alice)
    - [ ] Open instructor dashboard (http://localhost:3000/instructor/dashboard)
    - [ ] Open Confluent Cloud UI (show live topics)
    - [ ] Position windows for screen sharing
    - [ ] Close unnecessary applications (free RAM)

- [ ] **Presentation**
    - [ ] Load slides (first slide visible)
    - [ ] Start screen recording (backup)
    - [ ] Test microphone
    - [ ] Test screen sharing
    - [ ] Have backup video link ready

- [ ] **Team**
    - [ ] Bathroom break
    - [ ] Water bottles filled
    - [ ] Phones on silent
    - [ ] Roles confirmed (who presents what)
    - [ ] Deep breath, we got this! 🚀

---

**END OF 48-HOUR IMPLEMENTATION PLAN**