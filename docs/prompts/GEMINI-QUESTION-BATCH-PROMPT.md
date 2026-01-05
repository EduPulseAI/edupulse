Read ./backend/quizzer/README.md and confirm when ready.

Then implement and document Gemini-powered question generation for the Quizzer service, specifically for:
- QuestionService#createQuestionsBatch

Goal:
Use **Gemini (via Vertex AI / Gemini API)** to generate quiz questions in batches, where Gemini’s output can be directly mapped into the existing request shape:
@RequestBody Map<String, List<BatchQuestionCreation>> questionCreation

Critical output constraint (NON-NEGOTIABLE):
- The Gemini prompt must instruct the model to output ONLY a JSON object that matches:
  Map<String, List<BatchQuestionCreation>>
- No surrounding text, no markdown, no explanations, no additional keys.
- JSON keys must be the map keys (e.g., skillTag/category/difficulty bucket—use what Quizzer README indicates).
- Values must be arrays of BatchQuestionCreation objects with fields exactly matching our DTO.
- If a field is unknown from README, infer minimally and clearly document assumptions in the docs (NOT in the model output).

What to produce (in this order):

1) Understanding Summary
- Summarize the current Quizzer service’s purpose and QuestionService#createQuestionsBatch behavior based on ./backend/quizzer/README.md
- List the existing DTO fields for BatchQuestionCreation and any validation rules mentioned

2) Gemini Integration Design (Quizzer service)
- Where the Gemini call occurs (service layer boundary)
- Inputs to the Gemini request (topic, skillTag, difficulty, count, constraints, course context)
- How to ensure deterministic, schema-compliant JSON output
- Error handling + retries
- Guardrails (content safety, duplicate avoidance, difficulty calibration)
- Observability logging (request id, latency, token usage, truncation safeguards)

3) Gemini Prompt Template (REQUIRED)
   Provide:
- A production-grade prompt that:
    - includes strict instructions to output ONLY the JSON object
    - includes explicit schema shape and example field names/types (derived from README)
    - includes constraints (question count, difficulty distribution, answer format, etc.)
    - includes validation rules (no empty strings, no nulls, max lengths, etc.)
- Provide a separate “system” instruction and “user” payload template (if using chat-style API)
- Include placeholders for variables (e.g., {{skillTag}}, {{count}}, {{difficulty}}, {{courseContext}})

IMPORTANT:
- Do NOT wrap prompt or JSON in fenced code blocks.
- The Gemini output must be valid JSON and parseable into Map<String, List<BatchQuestionCreation>>.

4) Implementation Guide Document
   Create a new documentation file:
- ./docs/integrations/GEMINI-QUESTION-GENERATION.md

This doc must include (Markdown only; no code fences):
- Overview of the feature
- Sequence of operations for createQuestionsBatch
- Request/response flow
- Gemini configuration requirements (env vars, secrets, IAM)
- Prompt strategy and why it enforces schema compliance
- Validation strategy:
    - JSON parsing and DTO validation
    - reject/repair flow if Gemini output is invalid
- Suggested testing approach:
    - unit tests for prompt builder
    - integration tests with mocked Gemini client
    - contract tests ensuring output maps to BatchQuestionCreation DTO
- Failure modes and mitigations (timeouts, partial responses, invalid JSON, hallucinated fields)
- Cost/latency considerations and caching suggestions (optional)

5) File Outputs
- Output the full contents of:
    - ./docs/integrations/GEMINI-QUESTION-GENERATION.md
- Also output any required updates to existing docs if needed:
    - ./backend/quizzer/README.md (only if you need to add a short “Gemini integration” note)

Constraints:
- Respect existing EduPulse architecture (Kafka/Avro/Flink are unrelated here; do not add them)
- Keep this scoped to Quizzer + Gemini question generation
- Documentation must be copy/paste friendly and must not include fenced code blocks

Proceed after reading ./backend/quizzer/README.md.
