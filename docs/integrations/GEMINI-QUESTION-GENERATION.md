# Gemini-Powered Question Generation for Quizzer Service

## Overview

This document describes the integration of Google Gemini (via Vertex AI or Gemini API) into the EduPulse Quizzer service to enable AI-powered batch generation of multiple-choice quiz questions. The integration allows instructors and content creators to rapidly generate pedagogically sound quiz questions by specifying a topic, difficulty level, and question count.

The Gemini integration produces JSON output that directly maps to the existing batch question creation endpoint, ensuring seamless compatibility with the current Quizzer service architecture.

## Feature Summary

**Capability:** Generate multiple-choice quiz questions using Gemini's language model based on specified topics and parameters.

**Integration Point:** New service layer component that produces output compatible with QuestionService#createQuestionsBatch.

**Key Benefits:**
- Rapid content creation for new courses and topics
- Consistent question quality and formatting
- Customizable difficulty levels and skill targeting
- Automatic duplicate detection and avoidance
- Full observability and error handling

## Architecture

### Component Overview

GeminiQuestionGenerationService
  - Constructs Gemini prompts from input parameters
  - Calls Gemini API with retry logic
  - Validates and parses JSON response
  - Integrates with QuestionService for persistence

QuestionController (new endpoint)
  - Exposes /api/questions/generate endpoint
  - Accepts generation parameters
  - Invokes GeminiQuestionGenerationService
  - Returns created question summary

### Service Dependencies

- Google Cloud Vertex AI SDK or Gemini API client
- Jackson ObjectMapper for JSON parsing
- QuestionService for batch persistence
- Spring Retry for fault tolerance
- Micrometer for metrics collection

## Sequence of Operations

### High-Level Flow

1. Client sends POST request to /api/questions/generate with parameters
2. Controller validates input parameters
3. GeminiQuestionGenerationService queries existing questions for duplicate detection
4. Service constructs Gemini prompt with templates and parameters
5. Service calls Gemini API with configured model and temperature
6. Gemini returns JSON response
7. Service validates JSON structure and parses into Map<String, List<BatchQuestionCreation>>
8. Service performs schema validation against BatchQuestionCreation DTO
9. If valid, service calls QuestionService#createQuestionsBatch
10. Controller returns summary of created questions

### Detailed Operation Sequence

Step 1: Parameter Validation
- Validate questionCount (1-50 range recommended)
- Validate difficultyLevel enum (beginner, intermediate, advanced, mixed)
- Validate topicOrCourse is non-empty
- Apply rate limiting if needed

Step 2: Duplicate Detection
- Query existing questions for the specified topic
- Extract question stems (first 50 characters)
- Include in prompt as exclusion list

Step 3: Prompt Construction
- Load prompt template from configuration
- Substitute placeholders with actual values
- Apply content safety guidelines
- Set temperature and max tokens

Step 4: Gemini API Call
- Send request to Gemini API with retry wrapper
- Log request metadata (requestId, timestamp, tokens)
- Monitor for timeout (30s default)
- Handle rate limiting with exponential backoff

Step 5: Response Processing
- Strip any non-JSON content if present
- Parse JSON into Map<String, List<Map<String, Object>>>
- Validate top-level structure

Step 6: DTO Validation
- Convert each question map to BatchQuestionCreation DTO
- Validate question field: non-null, max 500 chars
- Validate options array: size 3-5, all non-empty strings
- Validate answer field: integer, 0 <= answer < options.length
- Reject or repair invalid entries based on policy

Step 7: Persistence
- If validation passes, invoke QuestionService#createQuestionsBatch
- Log success metrics
- Return Map<String, Integer> with question counts

Step 8: Error Handling
- If any step fails, log error with context
- Return appropriate HTTP status and error message
- Increment failure metrics

## Request/Response Flow

### Generation Request Endpoint

Endpoint: POST /api/questions/generate

Request Body:
{
  "topicOrCourse": "Algebra",
  "questionCount": 10,
  "difficultyLevel": "intermediate",
  "skillTags": ["linear-equations", "quadratic-equations"],
  "courseContext": "High school mathematics, grade 10",
  "questionStyle": "computational"
}

Response: 201 CREATED
{
  "Algebra": 10
}

### Error Response

Response: 400 BAD REQUEST
{
  "error": "INVALID_GEMINI_OUTPUT",
  "message": "Gemini response did not match expected schema",
  "details": "Missing 'answer' field in question 3"
}

Response: 503 SERVICE UNAVAILABLE
{
  "error": "GEMINI_API_UNAVAILABLE",
  "message": "Failed to reach Gemini API after 3 retries",
  "details": "Connection timeout"
}

## Gemini Configuration Requirements

### Environment Variables

GEMINI_API_KEY: API key for Gemini API access (if using direct API)
GOOGLE_APPLICATION_CREDENTIALS: Path to service account JSON (if using Vertex AI)
GEMINI_PROJECT_ID: GCP project ID for Vertex AI
GEMINI_LOCATION: GCP region for Vertex AI (e.g., us-central1)
GEMINI_MODEL_NAME: Model identifier (e.g., gemini-1.5-pro, gemini-1.5-flash)
GEMINI_TEMPERATURE: Temperature setting (0.0-1.0, recommend 0.3 for determinism)
GEMINI_MAX_TOKENS: Maximum output tokens (recommend 4000)
GEMINI_TIMEOUT_MS: Request timeout in milliseconds (default 30000)

### IAM Requirements (Vertex AI)

Service account must have:
- roles/aiplatform.user (to invoke Vertex AI endpoints)
- roles/ml.developer (if using model tuning)

### Secrets Management

Store GEMINI_API_KEY or service account credentials in:
- Google Secret Manager (production)
- Local .env file (development)
- Kubernetes secrets (GKE deployment)

Never commit credentials to version control.

## Prompt Strategy and Schema Compliance

### Why This Prompt Design Enforces Compliance

1. Explicit JSON-Only Instruction
The prompt explicitly states "output ONLY valid JSON" multiple times and warns that any deviation causes system failure. This primes the model to avoid conversational text.

2. Exact Schema Definition
The prompt provides the exact field names, types, and structure expected, removing ambiguity about the output format.

3. Validation Rules as Constraints
By listing validation rules (e.g., "0 <= answer < options.length"), the prompt teaches the model the contract it must satisfy.

4. Example-Driven Output
Including a concrete example in the exact format guides the model to replicate the structure precisely.

5. Terminating Instruction
The prompt ends with "OUTPUT ONLY THE JSON OBJECT NOW" to signal the model to begin generation immediately without preamble.

### Prompt Template Variables

- topicOrCourse: The subject area for question generation
- questionCount: Number of questions to generate
- difficultyLevel: Target difficulty (beginner, intermediate, advanced, mixed)
- skillTags: Specific skills or subtopics to focus on
- courseContext: Additional context like grade level or course type
- existingQuestions: Question stems to avoid for duplicate prevention

### Temperature and Sampling

- Temperature: 0.3 (balance between creativity and determinism)
- Top-P: 0.9 (nucleus sampling for quality)
- Top-K: 40 (limit candidate tokens)

These settings reduce randomness while maintaining question variety.

## Validation Strategy

### JSON Parsing Validation

Step 1: Strip Non-JSON Content
Use regex to extract JSON object if Gemini outputs extra text:
Pattern: \{.*\}
If no match found, reject response.

Step 2: Parse JSON
Use Jackson ObjectMapper with strict settings:
- Fail on unknown properties
- Require all specified fields
- Disallow null values

Catch JsonProcessingException and log details.

Step 3: Validate Top-Level Structure
Ensure result is Map<String, List<?>>.
Ensure at least one key-value pair exists.

### DTO Validation

For each question object in the map:

Field: question
- Type: String
- Non-null: required
- Non-empty: required
- Max length: 500 characters
- Pattern: No excessive whitespace, proper punctuation

Field: options
- Type: Array of String
- Size: 3-5 elements
- Each element: non-null, non-empty, max 200 chars
- Uniqueness: no duplicate options

Field: answer
- Type: Integer
- Range: 0 <= answer < options.length
- Non-null: required

### Reject/Repair Flow

Strict Mode (recommended for production):
- If any question fails validation, reject entire batch
- Return 400 BAD REQUEST with validation details
- Log full Gemini response for debugging
- Do not persist any questions

Lenient Mode (optional for development):
- Filter out invalid questions
- Log warnings for each rejected question
- Persist valid questions only
- Return partial success response with warning

Configuration:
GEMINI_VALIDATION_MODE=strict|lenient

## Testing Approach

### Unit Tests

Test: Prompt Builder
- Verify template substitution correctness
- Test escaping of special characters in parameters
- Validate placeholder replacement

Test: JSON Parser
- Test parsing valid Gemini response
- Test handling malformed JSON
- Test extraction of JSON from text-wrapped response

Test: DTO Validation
- Test valid BatchQuestionCreation objects pass
- Test invalid answer index rejected
- Test empty options array rejected
- Test null fields rejected
- Test oversized strings rejected

Test: Retry Logic
- Verify exponential backoff timing
- Test max retry count enforcement
- Test circuit breaker state transitions

### Integration Tests with Mocked Gemini Client

Mock Gemini responses using WireMock or MockServer.

Test Case: Successful Generation
- Mock Gemini returns valid JSON
- Verify QuestionService#createQuestionsBatch called
- Verify response contains correct question counts

Test Case: Invalid JSON Response
- Mock Gemini returns malformed JSON
- Verify error handling path invoked
- Verify no questions persisted

Test Case: Timeout
- Mock Gemini with delayed response exceeding timeout
- Verify timeout exception caught
- Verify retry attempted

Test Case: Rate Limiting
- Mock Gemini returns 429 status
- Verify exponential backoff triggered
- Verify eventual success after retry

### Contract Tests

Use Spring Cloud Contract or Pact to ensure output maps to BatchQuestionCreation DTO.

Contract Definition:
Given: Request for 5 Algebra questions at intermediate difficulty
When: Gemini returns valid JSON
Then: Output must deserialize to Map<String, List<BatchQuestionCreation>>
And: Each BatchQuestionCreation must pass Bean Validation

### End-to-End Tests

Prerequisites:
- Test Gemini API key or service account
- Test PostgreSQL database
- Quizzer service running

Test Flow:
1. Send POST /api/questions/generate
2. Verify 201 CREATED response
3. Query GET /api/questions?topic=Algebra
4. Verify generated questions present
5. Verify question count matches request
6. Verify questions are valid and answerable

## Failure Modes and Mitigations

### Failure Mode: Gemini API Timeout

Symptom: Request exceeds GEMINI_TIMEOUT_MS without response.

Cause: Network latency, high Gemini load, large token request.

Mitigation:
- Increase timeout for large question counts
- Implement retry with exponential backoff
- Reduce questionCount in retry attempt
- Fall back to manual question creation if retries exhausted

### Failure Mode: Invalid JSON Output

Symptom: Gemini returns non-JSON text or malformed JSON.

Cause: Prompt misinterpretation, model hallucination, truncation.

Mitigation:
- Attempt to extract JSON from text using regex
- Log full response for prompt tuning
- Return descriptive error to user
- Consider prompt refinement if frequent

### Failure Mode: Schema Mismatch

Symptom: JSON parses but fields don't match BatchQuestionCreation.

Cause: Model adds extra fields, omits required fields, uses wrong types.

Mitigation:
- Reject response and return validation error
- Log discrepancy for prompt improvement
- Provide clear error message indicating expected vs. actual schema
- Consider repair logic for minor issues (e.g., converting string answer to int)

### Failure Mode: Hallucinated Fields

Symptom: JSON contains unexpected top-level keys or nested fields.

Cause: Model creativity exceeds constraints.

Mitigation:
- Configure Jackson to fail on unknown properties
- Strip extra fields during parsing if lenient mode enabled
- Log warning for monitoring
- Refine prompt to emphasize "ONLY these fields"

### Failure Mode: Content Quality Issues

Symptom: Questions are factually incorrect, ambiguous, or poorly worded.

Cause: Model knowledge gaps, prompt ambiguity, difficulty calibration failure.

Mitigation:
- Implement post-generation review workflow
- Add content quality scoring heuristics
- Flag low-confidence questions for manual review
- Provide feedback loop to improve prompt over time

### Failure Mode: Duplicate Questions

Symptom: Generated questions match existing questions in database.

Cause: Insufficient duplicate detection, model repetition.

Mitigation:
- Query existing questions before generation
- Include question stems in prompt exclusion list
- Implement fuzzy matching (Levenshtein distance) post-generation
- Reject duplicates and regenerate

### Failure Mode: Rate Limiting (429)

Symptom: Gemini API returns 429 Too Many Requests.

Cause: Exceeded quota or requests per minute limit.

Mitigation:
- Implement exponential backoff with jitter
- Use token bucket algorithm for request throttling
- Queue requests during high load
- Monitor quota usage and alert before limits

### Failure Mode: Partial Response Truncation

Symptom: JSON is incomplete due to max token limit.

Cause: questionCount too high, verbose questions exceed output token budget.

Mitigation:
- Reduce questionCount and retry
- Increase GEMINI_MAX_TOKENS if within API limits
- Detect truncation by checking JSON validity
- Return partial results if some questions are valid

### Failure Mode: Cost Overrun

Symptom: Token usage exceeds budget limits.

Cause: Frequent generation requests, high questionCount, verbose prompts.

Mitigation:
- Implement request rate limiting per user/org
- Monitor token usage metrics
- Set monthly budget alerts in GCP
- Use caching for repeated topics
- Consider using gemini-1.5-flash for cost efficiency

## Cost and Latency Considerations

### Cost Analysis

Gemini Pricing (as of 2024, verify current rates):
- gemini-1.5-pro: $0.00025/1K input tokens, $0.00075/1K output tokens
- gemini-1.5-flash: $0.0000625/1K input tokens, $0.0001875/1K output tokens

Estimated Token Usage per Request:
- Input prompt: ~500-800 tokens (including system instruction and parameters)
- Output: ~100 tokens per question × questionCount
- Example: 10 questions = ~1000-1500 total tokens

Cost per 10-Question Batch (gemini-1.5-pro):
- Input: 700 tokens × $0.00025/1K = $0.000175
- Output: 1000 tokens × $0.00075/1K = $0.00075
- Total: ~$0.001 per request

Monthly Cost Estimate:
- 1000 requests/month × $0.001 = $1
- 10,000 requests/month × $0.001 = $10

Recommendation: Use gemini-1.5-flash for cost efficiency unless quality requires pro model.

### Latency Characteristics

Expected Latency:
- gemini-1.5-flash: 1-3 seconds for 10 questions
- gemini-1.5-pro: 3-6 seconds for 10 questions
- Network overhead: 100-500ms depending on region

Latency Factors:
- Question count (linear relationship)
- Model selection (flash vs. pro)
- GCP region proximity
- Current API load

Latency Optimization:
- Use gemini-1.5-flash for interactive use cases
- Batch large requests asynchronously
- Deploy Quizzer service in same GCP region as Vertex AI
- Implement caching for repeated topics

### Caching Strategy

Cache Layer 1: Generated Questions
- Key: Hash of (topicOrCourse, difficultyLevel, skillTags, questionCount)
- TTL: 7 days
- Storage: Redis or in-memory cache
- Benefit: Avoid Gemini call for identical requests

Cache Layer 2: Prompt Templates
- Key: Prompt template version
- TTL: Indefinite (invalidate on template change)
- Storage: Application memory
- Benefit: Avoid repeated file reads

Cache Layer 3: Existing Question Stems
- Key: topicOrCourse
- TTL: 1 hour
- Storage: Redis
- Benefit: Reduce database queries for duplicate detection

Invalidation Strategy:
- Invalidate topic cache when new questions are created manually
- Invalidate on successful Gemini generation
- Use cache versioning for prompt template updates

### Performance Recommendations

1. Use Asynchronous Processing
For large batches (>20 questions), use async endpoint:
- Return 202 ACCEPTED immediately
- Process generation in background
- Notify via webhook or polling endpoint when complete

2. Implement Request Queuing
Use message queue (Kafka, RabbitMQ) for high-volume scenarios:
- Decouple API request from Gemini call
- Enable rate limiting and backpressure
- Allow retry without client timeout

3. Monitor and Alert
Set up monitoring for:
- Average response time (target: <5s p95)
- Success rate (target: >99%)
- Token usage trends
- Cost per request
- Cache hit rate

4. Scale Considerations
Gemini API is managed service, but consider:
- Rate limits per project (check GCP quotas)
- Concurrent request limits
- Implementing client-side throttling
- Using multiple service accounts for higher throughput

## Integration Checklist

Prerequisites:
- Gemini API key or Vertex AI service account configured
- Environment variables set in application.yaml or .env
- Google Cloud SDK installed (if using Vertex AI)
- Jackson JSON library available (included in Spring Boot)

Implementation Steps:
1. Add Vertex AI or Gemini API client dependency to pom.xml
2. Create GeminiQuestionGenerationService in service package
3. Implement prompt template loading and variable substitution
4. Add Gemini API client wrapper with retry logic
5. Implement JSON parsing and DTO validation
6. Create /api/questions/generate controller endpoint
7. Add integration tests with mocked Gemini client
8. Configure observability (logging, metrics, tracing)
9. Deploy to staging environment for testing
10. Validate cost and latency in staging
11. Conduct load testing
12. Deploy to production with feature flag

Validation:
- Test with various topics and difficulty levels
- Verify questions are factually correct
- Confirm no duplicate questions generated
- Validate JSON parsing never fails on valid responses
- Ensure error messages are actionable
- Verify metrics are collected correctly

## Related Documentation

- Quizzer Service README: ./backend/quizzer/README.md
- Vertex AI Documentation: https://cloud.google.com/vertex-ai/docs
- Gemini API Reference: https://ai.google.dev/docs
- EduPulse System Design: ../SYSTEM-DESIGN.md
- Terraform Deployment Guide: ../../infra/terraform/README.md

## Future Enhancements

Potential improvements for future iterations:

1. Fine-Tuning
Train a custom Gemini model on high-quality question datasets to improve output quality and reduce prompt engineering.

2. Multi-Language Support
Extend prompt templates to support question generation in multiple languages for international courses.

3. Adaptive Difficulty
Use student performance data to dynamically adjust difficulty distributions based on cohort skill levels.

4. Question Review Workflow
Implement instructor review and approval process before questions go live in quizzes.

5. A/B Testing
Generate multiple question variants and use student performance to select highest-quality questions.

6. Image and Diagram Support
Extend to support questions with embedded images, diagrams, or code snippets using Gemini's multimodal capabilities.

7. Explanations Generation
Generate detailed explanations for correct answers to enhance learning outcomes.

8. Taxonomy Integration
Automatically tag questions with Bloom's Taxonomy levels and learning objectives.
