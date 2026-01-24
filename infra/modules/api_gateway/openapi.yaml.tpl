swagger: "2.0"
info:
  title: "${api_title}"
  description: "${api_description}"
  version: "1.0.0"

schemes:
  - https

produces:
  - application/json

consumes:
  - application/json

# Security definitions
%{ if enable_api_key ~}
securityDefinitions:
  api_key:
    type: apiKey
    name: x-api-key
    in: header

security:
  - api_key: []
%{ endif ~}

# Default backend configuration
x-google-backend:
  address: "${default_backend_url}"
  deadline: ${deadline}
  jwt_audience: "${default_backend_url}"

# CORS configuration
x-google-endpoints:
  - name: "${default_backend_url}"
    allowCors: true

paths:
  # ==========================================================================
  # Health Check Endpoints
  # ==========================================================================
  /actuator/health:
    get:
      summary: Health check endpoint
      operationId: healthCheck
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      responses:
        200:
          description: Service is healthy
    options:
      summary: CORS preflight for health check
      operationId: healthCheckOptions
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      responses:
        200:
          description: CORS preflight response

  /actuator/health/readiness:
    get:
      summary: Readiness probe endpoint
      operationId: readinessCheck
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      responses:
        200:
          description: Service is ready

  /actuator/health/liveness:
    get:
      summary: Liveness probe endpoint
      operationId: livenessCheck
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      responses:
        200:
          description: Service is alive

  # ==========================================================================
  # Quiz API - Answer Submission
  # ==========================================================================
  /api/quiz/answer/submit:
    post:
      summary: Submit a quiz answer
      operationId: submitQuizAnswer
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: body
          in: body
          required: true
          schema:
            type: object
      responses:
        200:
          description: Answer submitted successfully
        400:
          description: Invalid request
    options:
      summary: CORS preflight for submit answer
      operationId: submitQuizAnswerOptions
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      responses:
        200:
          description: CORS preflight response

  # ==========================================================================
  # Quiz API - Sessions
  # ==========================================================================
  /api/quiz/sessions/start:
    post:
      summary: Start a new quiz session
      operationId: startSession
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: body
          in: body
          required: true
          schema:
            type: object
      responses:
        201:
          description: Session started successfully
        400:
          description: Invalid request
    options:
      summary: CORS preflight for start session
      operationId: startSessionOptions
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      responses:
        200:
          description: CORS preflight response

  /api/quiz/sessions:
    get:
      summary: List quiz sessions
      operationId: listSessions
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: studentId
          in: query
          type: string
          required: false
        - name: topicId
          in: query
          type: string
          required: false
      responses:
        200:
          description: List of sessions
    options:
      summary: CORS preflight for list sessions
      operationId: listSessionsOptions
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      responses:
        200:
          description: CORS preflight response

  /api/quiz/sessions/{sessionId}:
    get:
      summary: Get session by ID
      operationId: getSession
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: sessionId
          in: path
          type: string
          required: true
      responses:
        200:
          description: Session details
        404:
          description: Session not found
    options:
      summary: CORS preflight for get session
      operationId: getSessionOptions
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: sessionId
          in: path
          type: string
          required: true
      responses:
        200:
          description: CORS preflight response

  # ==========================================================================
  # Quiz API - Questions
  # ==========================================================================
  /api/quiz/questions/generate:
    post:
      summary: Generate quiz questions using AI
      operationId: generateQuestions
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
        deadline: 120
      parameters:
        - name: body
          in: body
          required: true
          schema:
            type: object
      responses:
        201:
          description: Questions generated successfully
        400:
          description: Invalid request
    options:
      summary: CORS preflight for generate questions
      operationId: generateQuestionsOptions
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      responses:
        200:
          description: CORS preflight response

  /api/quiz/questions/next:
    get:
      summary: Get next question for session
      operationId: getNextQuestion
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: sessionId
          in: query
          type: string
          required: true
        - name: difficulty
          in: query
          type: string
          required: true
      responses:
        200:
          description: Next question
        404:
          description: No questions available
    options:
      summary: CORS preflight for get next question
      operationId: getNextQuestionOptions
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      responses:
        200:
          description: CORS preflight response

  # ==========================================================================
  # Quiz API - Topics
  # ==========================================================================
  /api/quiz/topics:
    get:
      summary: List topics
      operationId: listTopics
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: page
          in: query
          type: integer
          required: false
        - name: size
          in: query
          type: integer
          required: false
      responses:
        200:
          description: List of topics
    post:
      summary: Create a new topic
      operationId: createTopic
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: body
          in: body
          required: true
          schema:
            type: object
      responses:
        201:
          description: Topic created successfully
        400:
          description: Invalid request
    options:
      summary: CORS preflight for topics
      operationId: topicsOptions
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      responses:
        200:
          description: CORS preflight response

  # ==========================================================================
  # Student API
  # ==========================================================================
  /api/students:
    post:
      summary: Create a new student
      operationId: createStudent
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: body
          in: body
          required: true
          schema:
            type: object
      responses:
        202:
          description: Student created successfully
        400:
          description: Invalid request
    options:
      summary: CORS preflight for create student
      operationId: createStudentOptions
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      responses:
        200:
          description: CORS preflight response

  /api/students/{studentName}:
    get:
      summary: Get student by name
      operationId: getStudentByName
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: studentName
          in: path
          type: string
          required: true
      responses:
        200:
          description: Student details
        404:
          description: Student not found
    options:
      summary: CORS preflight for get student
      operationId: getStudentOptions
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: studentName
          in: path
          type: string
          required: true
      responses:
        200:
          description: CORS preflight response

  # ==========================================================================
  # Catch-all for other paths (proxied to default backend)
  # ==========================================================================
  /api/{path}:
    get:
      summary: Proxy GET requests
      operationId: proxyGet
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: path
          in: path
          type: string
          required: true
      responses:
        200:
          description: Proxied response
    post:
      summary: Proxy POST requests
      operationId: proxyPost
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: path
          in: path
          type: string
          required: true
        - name: body
          in: body
          required: false
          schema:
            type: object
      responses:
        200:
          description: Proxied response
    put:
      summary: Proxy PUT requests
      operationId: proxyPut
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: path
          in: path
          type: string
          required: true
        - name: body
          in: body
          required: false
          schema:
            type: object
      responses:
        200:
          description: Proxied response
    delete:
      summary: Proxy DELETE requests
      operationId: proxyDelete
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: path
          in: path
          type: string
          required: true
      responses:
        200:
          description: Proxied response
    patch:
      summary: Proxy PATCH requests
      operationId: proxyPatch
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: path
          in: path
          type: string
          required: true
        - name: body
          in: body
          required: false
          schema:
            type: object
      responses:
        200:
          description: Proxied response
    options:
      summary: CORS preflight for proxy
      operationId: proxyOptions
      x-google-backend:
        address: "${default_backend_url}"
        path_translation: APPEND_PATH_TO_ADDRESS
      parameters:
        - name: path
          in: path
          type: string
          required: true
      responses:
        200:
          description: CORS preflight response
