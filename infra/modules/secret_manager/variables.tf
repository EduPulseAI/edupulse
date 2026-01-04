variable "project_id" {
  description = "GCP project ID where Secret Manager secrets will be created"
  type        = string
}

variable "secrets" {
  description = "List of secrets to create in Secret Manager"
  type = list(object({
    name              = string
    description       = optional(string)
    labels            = optional(map(string))
    rotation_period   = optional(string)
    next_rotation_time = optional(string)
    secret_data       = optional(string)
  }))

  validation {
    condition = alltrue([
      for secret in var.secrets : can(regex("^[a-zA-Z0-9_-]+$", secret.name))
    ])
    error_message = "Secret names must contain only letters, numbers, hyphens, and underscores."
  }
}

variable "labels" {
  description = "Common labels to apply to all secrets"
  type        = map(string)
  default     = {}
}

variable "replication_policy" {
  description = "Replication policy for secrets (automatic or user_managed)"
  type        = string
  default     = "automatic"

  validation {
    condition     = contains(["automatic", "user_managed"], var.replication_policy)
    error_message = "Replication policy must be either 'automatic' or 'user_managed'."
  }
}

variable "replication_locations" {
  description = "List of locations for user-managed replication (only used if replication_policy is user_managed)"
  type        = list(string)
  default     = []

  validation {
    condition = var.replication_policy == "automatic" || (var.replication_policy == "user_managed" && length(var.replication_locations) > 0)
    error_message = "replication_locations must be provided when using user_managed replication policy."
  }
}

variable "kms_key_name" {
  description = "Cloud KMS key name for customer-managed encryption (optional, only for user_managed replication)"
  type        = string
  default     = null
}

variable "create_secret_versions" {
  description = "Whether to create secret versions with data from variables (NOT recommended for production - use gcloud/Console/CI instead)"
  type        = bool
  default     = false
}

variable "secret_accessors" {
  description = "Map of secret names to lists of members (service accounts, users) that should have secretAccessor role"
  type        = map(list(string))
  default     = null

  # Example:
  # {
  #   "kafka-api-key" = [
  #     "serviceAccount:event-ingest@project.iam.gserviceaccount.com",
  #     "serviceAccount:bandit-engine@project.iam.gserviceaccount.com"
  #   ]
  # }
}
