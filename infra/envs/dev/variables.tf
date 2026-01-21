# -----------------------------------------------------------------------------
# Project and Environment Configuration
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID for EduPulse deployment"
  type        = string
}

variable "region" {
  description = "GCP region for resources (e.g., us-central1, us-east1)"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "labels" {
  description = "Common labels to apply to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Artifact Registry Configuration
# -----------------------------------------------------------------------------

variable "artifact_registry_repository_id" {
  description = "Artifact Registry repository ID for container images"
  type        = string
  default     = "edupulse"
}

variable "artifact_registry_location" {
  description = "Location for Artifact Registry (defaults to var.region if not specified)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Cloud Run Services Configuration
# -----------------------------------------------------------------------------

variable "services" {
  description = "Map of Cloud Run services to deploy with their configurations"
  type = map(object({
    image_name    = string
    image_tag     = string
    port          = number
    cpu           = string
    memory        = string
    min_instances = number
    max_instances = number
    concurrency   = number
    timeout       = number
    ingress       = string
    env_vars      = map(string)
    secret_env_vars = map(object({
      secret_name = string
      version     = string
    }))
  }))
}

variable "allow_unauthenticated" {
  description = "Allow unauthenticated access to Cloud Run services (set to false for production)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# Secret Manager Configuration
# -----------------------------------------------------------------------------

variable "secrets" {
  description = "List of Secret Manager secret names to create (values must be set manually or via CI/CD)"
  type = list(object({
    name        = string
    description = string
  }))
}

# -----------------------------------------------------------------------------
# Vertex AI Configuration
# -----------------------------------------------------------------------------

variable "enable_vertex_ai" {
  description = "Enable Vertex AI APIs and IAM bindings for AI-powered features"
  type        = bool
  default     = true
}

variable "vertex_ai_endpoint_id" {
  description = "Vertex AI endpoint ID for bandit model (if pre-deployed)"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Networking Configuration
# -----------------------------------------------------------------------------

variable "network_name" {
  description = "Name of the VPC network (use 'default' for default VPC)"
  type        = string
  default     = "default"
}

variable "enable_vpc_connector" {
  description = "Enable VPC Serverless Connector for Cloud Run egress (required for Redis/private resources)"
  type        = bool
  default     = false
}

variable "vpc_connector_name" {
  description = "Name of the VPC Serverless Connector"
  type        = string
  default     = "edupulse-connector"
}

variable "vpc_connector_cidr" {
  description = "CIDR range for VPC Serverless Connector subnet (e.g., 10.8.0.0/28)"
  type        = string
  default     = "10.8.0.0/28"
}

variable "vpc_connector_machine_type" {
  description = "Machine type for VPC Serverless Connector instances"
  type        = string
  default     = "e2-micro"
}

variable "vpc_connector_min_instances" {
  description = "Minimum number of VPC connector instances"
  type        = number
  default     = 2
}

variable "vpc_connector_max_instances" {
  description = "Maximum number of VPC connector instances"
  type        = number
  default     = 10
}

variable "vpc_egress_setting" {
  description = "VPC egress setting for Cloud Run (ALL_TRAFFIC or PRIVATE_RANGES_ONLY)"
  type        = string
  default     = "PRIVATE_RANGES_ONLY"

  validation {
    condition     = contains(["ALL_TRAFFIC", "PRIVATE_RANGES_ONLY"], var.vpc_egress_setting)
    error_message = "VPC egress setting must be one of: ALL_TRAFFIC, PRIVATE_RANGES_ONLY."
  }
}

# -----------------------------------------------------------------------------
# Redis Memorystore Configuration
# -----------------------------------------------------------------------------

variable "enable_redis" {
  description = "Enable Redis Memorystore for caching"
  type        = bool
  default     = false
}

variable "redis_instance_name" {
  description = "Name of the Redis Memorystore instance"
  type        = string
  default     = "edupulse-redis"
}

variable "redis_tier" {
  description = "Redis tier: BASIC (no HA) or STANDARD_HA (high availability)"
  type        = string
  default     = "BASIC"

  validation {
    condition     = contains(["BASIC", "STANDARD_HA"], var.redis_tier)
    error_message = "Redis tier must be BASIC or STANDARD_HA."
  }
}

variable "redis_memory_size_gb" {
  description = "Redis memory size in GB (1-300)"
  type        = number
  default     = 1
}

variable "redis_version" {
  description = "Redis version"
  type        = string
  default     = "REDIS_7_0"
}

variable "redis_auth_enabled" {
  description = "Enable Redis AUTH for password protection"
  type        = bool
  default     = true
}

variable "redis_transit_encryption_mode" {
  description = "Transit encryption: DISABLED or SERVER_AUTHENTICATION"
  type        = string
  default     = "SERVER_AUTHENTICATION"
}

variable "redis_maxmemory_policy" {
  description = "Redis eviction policy"
  type        = string
  default     = "volatile-lru"
}

variable "redis_maintenance_window_day" {
  description = "Day for maintenance window (e.g., SUNDAY)"
  type        = string
  default     = "SUNDAY"
}

variable "redis_maintenance_window_hour" {
  description = "Hour for maintenance window (0-23 UTC)"
  type        = number
  default     = 2
}

variable "redis_create_private_service_connection" {
  description = "Create private service connection for Redis (set false if already exists)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# API Enablement
# -----------------------------------------------------------------------------

variable "apis_to_enable" {
  description = "List of GCP APIs to enable for this environment"
  type        = list(string)
  default = [
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "iam.googleapis.com",
    "compute.googleapis.com",
    "redis.googleapis.com",
    "vpcaccess.googleapis.com",
    "servicenetworking.googleapis.com",
  ]
}

variable "vertex_ai_apis" {
  description = "Vertex AI APIs to enable (only if enable_vertex_ai is true)"
  type        = list(string)
  default = [
    "aiplatform.googleapis.com",
    "notebooks.googleapis.com",
  ]
}

variable "gemini_api" {
  description = "Gemini API to enable"
  type        = string
  default     = "generativelanguage.googleapis.com"
}
