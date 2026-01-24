# -----------------------------------------------------------------------------
# API Gateway Module Variables
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the API Gateway"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "api_id" {
  description = "Unique identifier for the API"
  type        = string
  default     = "edupulse-api"
}

variable "gateway_id" {
  description = "Unique identifier for the API Gateway"
  type        = string
  default     = "edupulse-gateway"
}

variable "display_name" {
  description = "Display name for the API"
  type        = string
  default     = "EduPulse API"
}

# -----------------------------------------------------------------------------
# Backend Services Configuration
# -----------------------------------------------------------------------------

variable "backend_services" {
  description = "Map of backend service names to their Cloud Run URLs"
  type = map(object({
    url         = string
    path_prefix = string
  }))
}

variable "default_backend_url" {
  description = "Default backend URL for unmatched routes"
  type        = string
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

variable "allow_unauthenticated" {
  description = "Allow unauthenticated access to the API Gateway"
  type        = bool
  default     = true
}

variable "enable_api_key" {
  description = "Require API key for access (recommended for production)"
  type        = bool
  default     = false
}

variable "cors_allowed_origins" {
  description = "List of allowed CORS origins"
  type        = list(string)
  default     = ["*"]
}

variable "cors_allowed_methods" {
  description = "List of allowed CORS methods"
  type        = list(string)
  default     = ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"]
}

variable "cors_allowed_headers" {
  description = "List of allowed CORS headers"
  type        = list(string)
  default     = ["Content-Type", "Authorization", "X-Requested-With"]
}

# -----------------------------------------------------------------------------
# Timeouts and Limits
# -----------------------------------------------------------------------------

variable "deadline" {
  description = "Backend request timeout in seconds"
  type        = number
  default     = 60
}

# -----------------------------------------------------------------------------
# Labels
# -----------------------------------------------------------------------------

variable "labels" {
  description = "Labels to apply to all resources"
  type        = map(string)
  default     = {}
}
