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
  quiz-service = {
    image_name    = "quiz-service"
    image_tag     = "latest"
    port          = 8080
    cpu           = "1000m"
    memory        = "1Gi"
    min_instances = 0
    max_instances = 10
    concurrency   = 80
    timeout       = 60
    ingress       = "INGRESS_TRAFFIC_ALL"
    env_vars = {
      SPRING_PROFILES_ACTIVE = "prod"
      SERVER_PORT            = "8080"
      LOGGING_LEVEL_ROOT     = "INFO"
      GCP_REGION             = "us-central1"
      GCP_PROJECT_ID         = "edupulse-483220"
      GEMINI_MODEL           = "gemini-2.5-flash"
      REDIS_SSL_ENABLED      = "true"
    }
    secret_env_vars = {
      BOOTSTRAP_SERVERS = {
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
      JWT_SECRET = {
        secret_name = "jwt-signing-key"
        version     = "latest"
      }
      # Redis credentials (set manually via set-secrets.sh)
      REDIS_HOST = {
        secret_name = "redis-host"
        version     = "latest"
      }
      REDIS_PORT = {
        secret_name = "redis-port"
        version     = "latest"
      }
      REDIS_PASSWORD = {
        secret_name = "redis-password"
        version     = "latest"
      }
    }
  }

  engagement-service = {
    image_name    = "engagement-service"
    image_tag     = "latest"
    port          = 8080
    cpu           = "1000m"
    memory        = "1Gi"
    min_instances = 0
    max_instances = 10
    concurrency   = 80
    timeout       = 60
    ingress       = "INGRESS_TRAFFIC_ALL"
    env_vars = {
      SPRING_PROFILES_ACTIVE = "prod"
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

  sse-service = {
    image_name    = "sse-service"
    image_tag     = "latest"
    port          = 8080
    cpu           = "1000m"
    memory        = "1Gi"
    min_instances = 0
    max_instances = 10
    concurrency   = 80
    timeout       = 60
    ingress       = "INGRESS_TRAFFIC_ALL"
    env_vars = {
      SPRING_PROFILES_ACTIVE = "prod"
      SERVER_PORT            = "8080"
      LOGGING_LEVEL_ROOT     = "INFO"
      REDIS_SSL_ENABLED      = "true"
    }
    secret_env_vars = {
      BOOTSTRAP_SERVERS = {
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
      # Redis credentials (set manually via set-secrets.sh)
      REDIS_HOST = {
        secret_name = "redis-host"
        version     = "latest"
      }
      REDIS_PORT = {
        secret_name = "redis-port"
        version     = "latest"
      }
      REDIS_PASSWORD = {
        secret_name = "redis-password"
        version     = "latest"
      }
    }
  }

  profile-service = {
    image_name    = "profile-service"
    image_tag     = "latest"
    port          = 8080
    cpu           = "1000m"
    memory        = "1Gi"
    min_instances = 0
    max_instances = 10
    concurrency   = 80
    timeout       = 60
    ingress       = "INGRESS_TRAFFIC_ALL"
    env_vars = {
      SPRING_PROFILES_ACTIVE = "prod"
      SERVER_PORT            = "8080"
      LOGGING_LEVEL_ROOT     = "INFO"
      GCP_PROJECT_ID         = "edupulse-483220"
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
        secret_name = "profile-postgres-database"
        version     = "latest"
      }
      DATABASE_HOST = {
        secret_name = "postgres-host"
        version     = "latest"
      }
      JWT_SECRET = {
        secret_name = "jwt-signing-key"
        version     = "latest"
      }
    }
  }

  auth-service = {
    image_name    = "auth-service"
    image_tag     = "latest"
    port          = 8080
    cpu           = "1000m"
    memory        = "1Gi"
    min_instances = 0
    max_instances = 10
    concurrency   = 80
    timeout       = 60
    ingress       = "INGRESS_TRAFFIC_ALL"
    env_vars = {
      SPRING_PROFILES_ACTIVE = "prod"
      SERVER_PORT            = "8080"
      LOGGING_LEVEL_ROOT     = "INFO"
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
        secret_name = "auth-postgres-database"
        version     = "latest"
      }
      DATABASE_HOST = {
        secret_name = "postgres-host"
        version     = "latest"
      }
      JWT_SECRET = {
        secret_name = "jwt-signing-key"
        version     = "latest"
      }
    }
  }

  eureka-server = {
    image_name    = "eureka-server"
    image_tag     = "latest"
    port          = 8080
    cpu           = "1000m"
    memory        = "1Gi"
    min_instances = 0
    max_instances = 10
    concurrency   = 80
    timeout       = 60
    ingress       = "INGRESS_TRAFFIC_ALL"
    env_vars = {
      SPRING_PROFILES_ACTIVE = "prod"
      SERVER_PORT            = "8080"
      LOGGING_LEVEL_ROOT     = "INFO"
    }
    secret_env_vars = {
      # No secrets needed for Eureka server in this setup
    }
  }

  api-gateway = {
    image_name    = "api-gateway"
    image_tag     = "latest"
    port          = 8080
    cpu           = "1000m"
    memory        = "1Gi"
    min_instances = 0
    max_instances = 10
    concurrency   = 80
    timeout       = 60
    ingress       = "INGRESS_TRAFFIC_ALL"
    env_vars = {
      SPRING_PROFILES_ACTIVE = "prod"
      SERVER_PORT            = "8080"
      LOGGING_LEVEL_ROOT     = "INFO"      
    }
    secret_env_vars = {}
  }

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
    name        = "profile-postgres-user"
    description = "PostgreSQL database username for profile service"
  },
  {
    name        = "profile-postgres-password"
    description = "PostgreSQL database password for profile service"
  },
  {
    name        = "profile-postgres-host"
    description = "PostgreSQL database host for profile service"
  },
  {
    name        = "profile-postgres-database"
    description = "PostgreSQL database name for profile service"
  },
  {
    name        = "auth-postgres-database"
    description = "PostgreSQL database name for auth service"
  },
  {
    name        = "postgres-user"
    description = "PostgreSQL database username for quiz service"
  },
  {
    name        = "postgres-password"
    description = "PostgreSQL database password for quiz service"
  },
  {
    name        = "postgres-host"
    description = "PostgreSQL database host for quiz service"
  },
  {
    name        = "postgres-database"
    description = "PostgreSQL database name for quiz service"
  },
  {
    name        = "redis-host"
    description = "Redis host for caching"
  },
  {
    name        = "redis-port"
    description = "Redis port"
  },
  {
    name        = "redis-password"
    description = "Redis AUTH password for authentication"
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

network_name               = "default"
enable_vpc_connector       = false # Not needed with public external services (Upstash, Neon)
vpc_connector_name         = "edupulse-dev-vpc"
vpc_connector_cidr         = "10.8.0.0/28"
vpc_connector_machine_type = "e2-micro"
vpc_connector_min_instances = 2
vpc_connector_max_instances = 3
vpc_egress_setting         = "PRIVATE_RANGES_ONLY"

