variable "project_id" {
  description = "GCP project ID where Vertex AI will be enabled"
  type        = string
}

variable "enable_apis" {
  description = "Whether to enable Vertex AI APIs via this module (set to false if APIs are enabled elsewhere)"
  type        = bool
  default     = true
}

variable "apis_to_enable" {
  description = "List of Vertex AI and related APIs to enable"
  type        = list(string)
  default = [
    "aiplatform.googleapis.com",      # Vertex AI API
    "notebooks.googleapis.com",        # Vertex AI Workbench (optional)
    "ml.googleapis.com",               # Legacy ML API (for compatibility)
    "compute.googleapis.com",          # Required for Vertex AI infrastructure
    "storage.googleapis.com",          # Required for model artifacts
  ]
}

variable "service_account_emails" {
  description = "List of service account emails that need Vertex AI access (Cloud Run services)"
  type        = list(string)
  default     = []

  validation {
    condition = alltrue([
      for email in var.service_account_emails :
      can(regex("^[a-z0-9._%+-]+@[a-z0-9.-]+\\.[a-z]{2,}$", email))
    ])
    error_message = "Service account emails must be valid email addresses."
  }
}

variable "enable_service_agent_role" {
  description = "Grant aiplatform.serviceAgent role to service accounts (needed for AutoML, custom training)"
  type        = bool
  default     = false
}

variable "enable_admin_role" {
  description = "Grant aiplatform.admin role to specified service accounts (for endpoint deployment/management)"
  type        = bool
  default     = false
}

variable "admin_service_account_emails" {
  description = "List of service account emails that need Vertex AI admin access (only if enable_admin_role is true)"
  type        = list(string)
  default     = []
}

variable "enable_default_service_agent" {
  description = "Grant permissions to the default GCP-managed AI Platform service agent"
  type        = bool
  default     = true
}

variable "enable_logging_permissions" {
  description = "Grant logging.logWriter role to service accounts for Vertex AI operation logs"
  type        = bool
  default     = false
}

variable "enable_monitoring_permissions" {
  description = "Grant monitoring.metricWriter role to service accounts for Vertex AI metrics"
  type        = bool
  default     = false
}

variable "region" {
  description = "GCP region for Vertex AI resources (informational, used in outputs)"
  type        = string
  default     = "us-central1"
}

variable "labels" {
  description = "Labels to apply to resources (currently informational, as API enablement doesn't support labels)"
  type        = map(string)
  default     = {}
}
