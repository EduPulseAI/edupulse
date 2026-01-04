variable "project_id" {
  description = "GCP project ID where the Artifact Registry repository will be created"
  type        = string
}

variable "location" {
  description = "GCP region/location for the Artifact Registry repository (e.g., us-central1, us-east1)"
  type        = string
}

variable "repository_id" {
  description = "The ID/name of the Artifact Registry repository"
  type        = string

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,61}[a-z0-9])?$", var.repository_id))
    error_message = "Repository ID must be lowercase letters, numbers, and hyphens, starting with a letter, max 63 chars."
  }
}

variable "description" {
  description = "Description of the Artifact Registry repository"
  type        = string
  default     = "Container images for EduPulse microservices"
}

variable "labels" {
  description = "Labels to apply to the Artifact Registry repository"
  type        = map(string)
  default     = {}
}

variable "kms_key_name" {
  description = "The full Cloud KMS key name for customer-managed encryption. If null, Google-managed encryption is used."
  type        = string
  default     = null
}

variable "cleanup_policy_dry_run" {
  description = "If true, cleanup policies run in dry-run mode (no actual deletion)"
  type        = bool
  default     = false
}

variable "cleanup_policies" {
  description = "List of cleanup policies for managing image lifecycle"
  type = list(object({
    id     = string
    action = string
    condition = optional(object({
      tag_state             = optional(string)
      tag_prefixes          = optional(list(string))
      version_name_prefixes = optional(list(string))
      package_name_prefixes = optional(list(string))
      older_than            = optional(string)
      newer_than            = optional(string)
    }))
    most_recent_versions = optional(object({
      package_name_prefixes = optional(list(string))
      keep_count            = optional(number)
    }))
  }))
  default = [
    {
      id     = "delete-untagged-old-images"
      action = "DELETE"
      condition = {
        tag_state  = "UNTAGGED"
        older_than = "2592000s" # 30 days
      }
      most_recent_versions = null
    },
    {
      id     = "keep-recent-versions"
      action = "KEEP"
      condition = null
      most_recent_versions = {
        keep_count = 10
      }
    }
  ]
}
