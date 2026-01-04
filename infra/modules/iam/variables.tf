variable "project_id" {
  description = "GCP project ID where IAM resources will be created"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, prod) for resource naming and descriptions"
  type        = string
  default     = "dev"
}

variable "services" {
  description = "Map of service configurations with IAM requirements"
  type = map(object({
    # Service account metadata
    display_name = optional(string)
    description  = optional(string)

    # Secret Manager access
    secret_names = optional(list(string), [])

    # Vertex AI access
    enable_vertex_ai            = optional(bool, false)
    enable_vertex_ai_prediction = optional(bool, false)

    # Artifact Registry access
    enable_artifact_registry_pull = optional(bool, false)

    # Additional IAM roles (use sparingly, prefer specific flags above)
    additional_roles = optional(list(string), [])

    # Service-to-service authentication
    # List of service names this service can impersonate/act as
    can_act_as = optional(list(string), [])

    # Workload Identity (for GKE)
    enable_workload_identity = optional(bool, false)
    k8s_namespace           = optional(string, "default")
  }))

  validation {
    condition = alltrue([
      for service_name, config in var.services :
      can(regex("^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", service_name))
    ])
    error_message = "Service names must be lowercase letters, numbers, and hyphens, starting with a letter."
  }
}

variable "labels" {
  description = "Common labels to apply to service accounts"
  type        = map(string)
  default     = {}
}
