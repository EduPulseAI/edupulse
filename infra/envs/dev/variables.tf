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

variable "enable_vpc_connector" {
  description = "Enable VPC Serverless Connector for Cloud Run egress (required for private resources)"
  type        = bool
  default     = false
}

variable "vpc_connector_name" {
  description = "Name of the VPC Serverless Connector (only used if enable_vpc_connector is true)"
  type        = string
  default     = "edupulse-connector"
}

variable "vpc_connector_cidr" {
  description = "CIDR range for VPC Serverless Connector (e.g., 10.8.0.0/28)"
  type        = string
  default     = "10.8.0.0/28"
}

variable "vpc_connector_machine_type" {
  description = "Machine type for VPC Serverless Connector instances"
  type        = string
  default     = "e2-micro"
}

variable "vpc_egress_setting" {
  description = "VPC egress setting for Cloud Run (all-traffic or private-ranges-only)"
  type        = string
  default     = "private-ranges-only"

  validation {
    condition     = contains(["all-traffic", "private-ranges-only"], var.vpc_egress_setting)
    error_message = "VPC egress setting must be one of: all-traffic, private-ranges-only."
  }
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
