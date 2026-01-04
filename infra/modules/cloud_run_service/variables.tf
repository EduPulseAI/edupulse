# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID where the Cloud Run service will be deployed"
  type        = string
}

variable "location" {
  description = "GCP region for the Cloud Run service (e.g., us-central1)"
  type        = string
}

variable "service_name" {
  description = "Name of the Cloud Run service"
  type        = string

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", var.service_name))
    error_message = "Service name must be lowercase letters, numbers, and hyphens, starting with a letter, max 63 chars."
  }
}

variable "image_uri" {
  description = "Full container image URI (e.g., us-central1-docker.pkg.dev/project/repo/image:tag)"
  type        = string
}

variable "service_account_email" {
  description = "Service account email for the Cloud Run service runtime"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$", var.service_account_email))
    error_message = "Service account email must be a valid email address."
  }
}

# -----------------------------------------------------------------------------
# Container Configuration
# -----------------------------------------------------------------------------

variable "port" {
  description = "Container port to expose (default 8080 for Spring Boot)"
  type        = number
  default     = 8080

  validation {
    condition     = var.port > 0 && var.port <= 65535
    error_message = "Port must be between 1 and 65535."
  }
}

variable "cpu" {
  description = "CPU allocation (e.g., '1000m' = 1 vCPU, '2000m' = 2 vCPUs)"
  type        = string
  default     = "1000m"

  validation {
    condition     = can(regex("^[0-9]+m?$", var.cpu))
    error_message = "CPU must be a number followed by optional 'm' (e.g., '1000m' or '1')."
  }
}

variable "memory" {
  description = "Memory allocation (e.g., '512Mi', '1Gi', '2Gi')"
  type        = string
  default     = "512Mi"

  validation {
    condition     = can(regex("^[0-9]+(Mi|Gi)$", var.memory))
    error_message = "Memory must be a number followed by 'Mi' or 'Gi' (e.g., '512Mi', '1Gi')."
  }
}

# -----------------------------------------------------------------------------
# Scaling Configuration
# -----------------------------------------------------------------------------

variable "min_instances" {
  description = "Minimum number of instances (0 allows scale-to-zero)"
  type        = number
  default     = 0

  validation {
    condition     = var.min_instances >= 0
    error_message = "Minimum instances must be >= 0."
  }
}

variable "max_instances" {
  description = "Maximum number of instances for autoscaling"
  type        = number
  default     = 10

  validation {
    condition     = var.max_instances >= 1
    error_message = "Maximum instances must be >= 1."
  }
}

variable "concurrency" {
  description = "Maximum concurrent requests per instance"
  type        = number
  default     = 80

  validation {
    condition     = var.concurrency >= 1 && var.concurrency <= 1000
    error_message = "Concurrency must be between 1 and 1000."
  }
}

variable "timeout" {
  description = "Request timeout in seconds (max 3600 for 1st gen, 60 for 2nd gen by default)"
  type        = number
  default     = 60

  validation {
    condition     = var.timeout >= 1 && var.timeout <= 3600
    error_message = "Timeout must be between 1 and 3600 seconds."
  }
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "ingress" {
  description = "Ingress setting (all, internal, internal-and-cloud-load-balancing)"
  type        = string
  default     = "all"

  validation {
    condition     = contains(["INGRESS_TRAFFIC_ALL", "INGRESS_TRAFFIC_INTERNAL_ONLY", "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER", "all", "internal", "internal-and-cloud-load-balancing"], var.ingress)
    error_message = "Ingress must be one of: all, internal, internal-and-cloud-load-balancing."
  }
}

variable "vpc_connector_name" {
  description = "VPC Serverless Connector name for private resource access (optional)"
  type        = string
  default     = null
}

variable "vpc_egress_setting" {
  description = "VPC egress setting (all-traffic or private-ranges-only)"
  type        = string
  default     = "private-ranges-only"

  validation {
    condition     = contains(["all-traffic", "private-ranges-only"], var.vpc_egress_setting)
    error_message = "VPC egress setting must be one of: all-traffic, private-ranges-only."
  }
}

# -----------------------------------------------------------------------------
# Environment Variables
# -----------------------------------------------------------------------------

variable "env_vars" {
  description = "Map of environment variables (non-secret)"
  type        = map(string)
  default     = {}
}

variable "secret_env_vars" {
  description = "Map of secret environment variables from Secret Manager"
  type = map(object({
    secret_name = string
    version     = string
  }))
  default = {}
}

# -----------------------------------------------------------------------------
# Health Checks
# -----------------------------------------------------------------------------

variable "startup_probe_path" {
  description = "HTTP path for startup probe (e.g., /actuator/health/readiness). Set to null to disable."
  type        = string
  default     = null
}

variable "startup_probe_initial_delay" {
  description = "Initial delay for startup probe in seconds"
  type        = number
  default     = 0
}

variable "startup_probe_timeout" {
  description = "Timeout for startup probe in seconds"
  type        = number
  default     = 1
}

variable "startup_probe_period" {
  description = "Period for startup probe in seconds"
  type        = number
  default     = 10
}

variable "startup_probe_failure_threshold" {
  description = "Failure threshold for startup probe"
  type        = number
  default     = 3
}

variable "liveness_probe_path" {
  description = "HTTP path for liveness probe (e.g., /actuator/health/liveness). Set to null to disable."
  type        = string
  default     = null
}

variable "liveness_probe_initial_delay" {
  description = "Initial delay for liveness probe in seconds"
  type        = number
  default     = 0
}

variable "liveness_probe_timeout" {
  description = "Timeout for liveness probe in seconds"
  type        = number
  default     = 1
}

variable "liveness_probe_period" {
  description = "Period for liveness probe in seconds"
  type        = number
  default     = 10
}

variable "liveness_probe_failure_threshold" {
  description = "Failure threshold for liveness probe"
  type        = number
  default     = 3
}

# -----------------------------------------------------------------------------
# IAM and Access Control
# -----------------------------------------------------------------------------

variable "allow_unauthenticated" {
  description = "Allow unauthenticated access (public internet access)"
  type        = bool
  default     = false
}

variable "invoker_members" {
  description = "List of members granted Cloud Run Invoker role (e.g., ['serviceAccount:foo@project.iam.gserviceaccount.com'])"
  type        = list(string)
  default     = []
}

# -----------------------------------------------------------------------------
# Advanced Configuration
# -----------------------------------------------------------------------------

variable "session_affinity" {
  description = "Enable session affinity for WebSocket support (true/false)"
  type        = bool
  default     = false
}

variable "labels" {
  description = "Labels to apply to the Cloud Run service"
  type        = map(string)
  default     = {}
}
