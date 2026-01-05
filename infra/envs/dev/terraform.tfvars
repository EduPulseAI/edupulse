# -----------------------------------------------------------------------------
# Project and Environment
# -----------------------------------------------------------------------------

project_id  = "edupulse-483220"
region      = "us-central1"
environment = "dev"

labels = {
  environment = "dev"
  project     = "edupulse"
  managed_by  = "terraform"
  team        = "platform"
}

# -----------------------------------------------------------------------------
# Artifact Registry
# -----------------------------------------------------------------------------

artifact_registry_repository_id = "edupulse"
artifact_registry_location      = "" # Defaults to var.region

# -----------------------------------------------------------------------------
# Cloud Run Services
# -----------------------------------------------------------------------------

services = {
  event-ingest-service = {
    image_name    = "event-ingest-service"
    image_tag     = "latest"
    port          = 8080
    cpu           = "1000m"
    memory        = "512Mi"
    min_instances = 0
    max_instances = 10
    concurrency   = 80
    timeout       = 60
    ingress       = "INGRESS_TRAFFIC_ALL"
    env_vars = {
      SPRING_PROFILES_ACTIVE = "dev"
      SERVER_PORT            = "8080"
      LOGGING_LEVEL_ROOT     = "INFO"
    }
    secret_env_vars = {
      KAFKA_BOOTSTRAP_SERVERS = {
        secret_name = "kafka-bootstrap-servers"
        version     = "latest"
      }
      KAFKA_API_KEY = {
        secret_name = "kafka-api-key"
        version     = "latest"
      }
      KAFKA_API_SECRET = {
        secret_name = "kafka-api-secret"
        version     = "latest"
      }
      SCHEMA_REGISTRY_URL = {
        secret_name = "schema-registry-url"
        version     = "latest"
      }
      SCHEMA_REGISTRY_API_KEY = {
        secret_name = "schema-registry-api-key"
        version     = "latest"
      }
      SCHEMA_REGISTRY_API_SECRET = {
        secret_name = "schema-registry-api-secret"
        version     = "latest"
      }
    }
  }

  quizzer = {
    image_name    = "quizzer"
    image_tag     = "latest"
    port          = 8080
    cpu           = "1000m"
    memory        = "512Mi"
    min_instances = 0
    max_instances = 10
    concurrency   = 80
    timeout       = 60
    ingress       = "INGRESS_TRAFFIC_ALL"
    env_vars = {
      SPRING_PROFILES_ACTIVE        = "dev"
      SERVER_PORT                   = "8080"
      LOGGING_LEVEL_ROOT            = "INFO"
    }
    secret_env_vars = {
      DATABASE_USER = {
        secret_name = "postgres-user"
        version     = "latest"
      }
      DATABASE_PASSWORD = {
        secret_name = "postgres-password"
        version     = "latest"
      }
      DATABASE_NAME = {
        secret_name = "postgres-database"
        version     = "latest"
      }
      DATABASE_HOST = {
        secret_name = "postgres-host"
        version     = "latest"
      }
    }
  }

  # bandit-engine = {
  #   image_name    = "bandit-engine"
  #   image_tag     = "latest"
  #   port          = 8080
  #   cpu           = "2000m"
  #   memory        = "1Gi"
  #   min_instances = 0
  #   max_instances = 5
  #   concurrency   = 40
  #   timeout       = 120
  #   ingress       = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  #   env_vars = {
  #     SPRING_PROFILES_ACTIVE = "dev"
  #     SERVER_PORT            = "8080"
  #     VERTEX_AI_PROJECT      = "edupulse-dev-REPLACEME"
  #     VERTEX_AI_REGION       = "us-central1"
  #   }
  #   secret_env_vars = {
  #     KAFKA_BOOTSTRAP_SERVERS = {
  #       secret_name = "kafka-bootstrap-servers"
  #       version     = "latest"
  #     }
  #     KAFKA_API_KEY = {
  #       secret_name = "kafka-api-key"
  #       version     = "latest"
  #     }
  #     KAFKA_API_SECRET = {
  #       secret_name = "kafka-api-secret"
  #       version     = "latest"
  #     }
  #     SCHEMA_REGISTRY_URL = {
  #       secret_name = "schema-registry-url"
  #       version     = "latest"
  #     }
  #     SCHEMA_REGISTRY_API_KEY = {
  #       secret_name = "schema-registry-api-key"
  #       version     = "latest"
  #     }
  #     SCHEMA_REGISTRY_API_SECRET = {
  #       secret_name = "schema-registry-api-secret"
  #       version     = "latest"
  #     }
  #   }
  # }
  #
  # tip-service = {
  #   image_name    = "tip-service"
  #   image_tag     = "latest"
  #   port          = 8080
  #   cpu           = "1000m"
  #   memory        = "512Mi"
  #   min_instances = 0
  #   max_instances = 5
  #   concurrency   = 40
  #   timeout       = 90
  #   ingress       = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  #   env_vars = {
  #     SPRING_PROFILES_ACTIVE = "dev"
  #     SERVER_PORT            = "8080"
  #     GEMINI_MODEL           = "gemini-2.0-flash-exp"
  #   }
  #   secret_env_vars = {
  #     KAFKA_BOOTSTRAP_SERVERS = {
  #       secret_name = "kafka-bootstrap-servers"
  #       version     = "latest"
  #     }
  #     KAFKA_API_KEY = {
  #       secret_name = "kafka-api-key"
  #       version     = "latest"
  #     }
  #     KAFKA_API_SECRET = {
  #       secret_name = "kafka-api-secret"
  #       version     = "latest"
  #     }
  #     SCHEMA_REGISTRY_URL = {
  #       secret_name = "schema-registry-url"
  #       version     = "latest"
  #     }
  #     SCHEMA_REGISTRY_API_KEY = {
  #       secret_name = "schema-registry-api-key"
  #       version     = "latest"
  #     }
  #     SCHEMA_REGISTRY_API_SECRET = {
  #       secret_name = "schema-registry-api-secret"
  #       version     = "latest"
  #     }
  #     GEMINI_API_KEY = {
  #       secret_name = "gemini-api-key"
  #       version     = "latest"
  #     }
  #   }
  # }
  #
  # content-adapter = {
  #   image_name    = "content-adapter"
  #   image_tag     = "latest"
  #   port          = 8080
  #   cpu           = "500m"
  #   memory        = "256Mi"
  #   min_instances = 0
  #   max_instances = 10
  #   concurrency   = 80
  #   timeout       = 60
  #   ingress       = "INGRESS_TRAFFIC_INTERNAL_ONLY"
  #   env_vars = {
  #     SPRING_PROFILES_ACTIVE = "dev"
  #     SERVER_PORT            = "8080"
  #   }
  #   secret_env_vars = {
  #     KAFKA_BOOTSTRAP_SERVERS = {
  #       secret_name = "kafka-bootstrap-servers"
  #       version     = "latest"
  #     }
  #     KAFKA_API_KEY = {
  #       secret_name = "kafka-api-key"
  #       version     = "latest"
  #     }
  #     KAFKA_API_SECRET = {
  #       secret_name = "kafka-api-secret"
  #       version     = "latest"
  #     }
  #     SCHEMA_REGISTRY_URL = {
  #       secret_name = "schema-registry-url"
  #       version     = "latest"
  #     }
  #     SCHEMA_REGISTRY_API_KEY = {
  #       secret_name = "schema-registry-api-key"
  #       version     = "latest"
  #     }
  #     SCHEMA_REGISTRY_API_SECRET = {
  #       secret_name = "schema-registry-api-secret"
  #       version     = "latest"
  #     }
  #   }
  # }
  #
  # realtime-gateway = {
  #   image_name    = "realtime-gateway"
  #   image_tag     = "latest"
  #   port          = 8080
  #   cpu           = "1000m"
  #   memory        = "512Mi"
  #   min_instances = 1
  #   max_instances = 20
  #   concurrency   = 100
  #   timeout       = 300
  #   ingress       = "INGRESS_TRAFFIC_ALL"
  #   env_vars = {
  #     SPRING_PROFILES_ACTIVE = "dev"
  #     SERVER_PORT            = "8080"
  #     WEBSOCKET_ENABLED      = "true"
  #   }
  #   secret_env_vars = {
  #     KAFKA_BOOTSTRAP_SERVERS = {
  #       secret_name = "kafka-bootstrap-servers"
  #       version     = "latest"
  #     }
  #     KAFKA_API_KEY = {
  #       secret_name = "kafka-api-key"
  #       version     = "latest"
  #     }
  #     KAFKA_API_SECRET = {
  #       secret_name = "kafka-api-secret"
  #       version     = "latest"
  #     }
  #     SCHEMA_REGISTRY_URL = {
  #       secret_name = "schema-registry-url"
  #       version     = "latest"
  #     }
  #     SCHEMA_REGISTRY_API_KEY = {
  #       secret_name = "schema-registry-api-key"
  #       version     = "latest"
  #     }
  #     SCHEMA_REGISTRY_API_SECRET = {
  #       secret_name = "schema-registry-api-secret"
  #       version     = "latest"
  #     }
  #   }
  # }
}

allow_unauthenticated = true # Dev environment allows public access for testing

# -----------------------------------------------------------------------------
# Secret Manager
# -----------------------------------------------------------------------------

secrets = [
  {
    name        = "kafka-bootstrap-servers"
    description = "Confluent Kafka bootstrap servers endpoint"
  },
  {
    name        = "kafka-api-key"
    description = "Confluent Kafka API key for authentication"
  },
  {
    name        = "kafka-api-secret"
    description = "Confluent Kafka API secret for authentication"
  },
  {
    name        = "schema-registry-url"
    description = "Confluent Schema Registry URL"
  },
  {
    name        = "schema-registry-api-key"
    description = "Confluent Schema Registry API key"
  },
  {
    name        = "schema-registry-api-secret"
    description = "Confluent Schema Registry API secret"
  },
  {
    name        = "gemini-api-key"
    description = "Google Gemini API key for AI-powered hint generation"
  },
  {
    name        = "jwt-signing-key"
    description = "JWT signing key for session tokens"
  },
  {
    name        = "postgres-user"
    description = "PostgreSQL database username for quizzer service"
  },
  {
    name        = "postgres-password"
    description = "PostgreSQL database password for quizzer service"
  },
  {
    name        = "postgres-database"
    description = "PostgreSQL database name for quizzer service"
  },
  {
    name        = "postgres-host"
    description = "PostgreSQL database host for quizzer service"
  }
]

# -----------------------------------------------------------------------------
# Vertex AI
# -----------------------------------------------------------------------------

enable_vertex_ai      = true
vertex_ai_endpoint_id = "" # Leave empty if not yet deployed

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

enable_vpc_connector       = false # Not needed for Confluent Cloud (public endpoints)
vpc_connector_name         = "edupulse-dev-connector"
vpc_connector_cidr         = "10.8.0.0/28"
vpc_connector_machine_type = "e2-micro"
vpc_egress_setting         = "private-ranges-only"
