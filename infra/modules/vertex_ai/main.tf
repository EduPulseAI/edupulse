# -----------------------------------------------------------------------------
# Enable Vertex AI APIs
# Note: For hackathon simplicity, we only enable APIs and configure IAM.
# Actual model deployment/endpoints are managed separately (via Console or CLI).
# -----------------------------------------------------------------------------

resource "google_project_service" "vertex_ai_apis" {
  for_each = var.enable_apis ? toset(var.apis_to_enable) : toset([])

  project = var.project_id
  service = each.value

  disable_on_destroy         = false
  disable_dependent_services = false
}

# -----------------------------------------------------------------------------
# IAM - Grant Vertex AI User role to specified service accounts
# This allows Cloud Run services to invoke Vertex AI prediction endpoints
# -----------------------------------------------------------------------------

resource "google_project_iam_member" "vertex_ai_user" {
  for_each = toset(var.service_account_emails)

  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${each.value}"

  depends_on = [
    google_project_service.vertex_ai_apis
  ]
}

# -----------------------------------------------------------------------------
# IAM - Grant AI Platform Service Agent (optional, for advanced features)
# This role is needed for certain Vertex AI operations like AutoML
# Only granted if explicitly requested via variable
# -----------------------------------------------------------------------------

resource "google_project_iam_member" "vertex_ai_service_agent" {
  for_each = var.enable_service_agent_role ? toset(var.service_account_emails) : toset([])

  project = var.project_id
  role    = "roles/aiplatform.serviceAgent"
  member  = "serviceAccount:${each.value}"

  depends_on = [
    google_project_service.vertex_ai_apis
  ]
}

# -----------------------------------------------------------------------------
# IAM - Grant Vertex AI Admin role (optional, for endpoint deployment)
# Only grant if service accounts need to deploy/manage endpoints
# -----------------------------------------------------------------------------

resource "google_project_iam_member" "vertex_ai_admin" {
  for_each = var.enable_admin_role ? toset(var.admin_service_account_emails) : toset([])

  project = var.project_id
  role    = "roles/aiplatform.admin"
  member  = "serviceAccount:${each.value}"

  depends_on = [
    google_project_service.vertex_ai_apis
  ]
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "google_project" "project" {
  project_id = var.project_id
}

# Grant the default AI Platform Service Agent permissions (system-managed)
# This is the GCP-managed service account for Vertex AI operations
resource "google_project_iam_member" "default_ai_service_agent" {
  count = var.enable_default_service_agent ? 1 : 0

  project = var.project_id
  role    = "roles/aiplatform.serviceAgent"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"

  depends_on = [
    google_project_service.vertex_ai_apis
  ]
}

# -----------------------------------------------------------------------------
# Optional: Logging permissions for Vertex AI operations
# -----------------------------------------------------------------------------

resource "google_project_iam_member" "vertex_ai_logging" {
  for_each = var.enable_logging_permissions ? toset(var.service_account_emails) : toset([])

  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${each.value}"
}

resource "google_project_iam_member" "vertex_ai_metric_writer" {
  for_each = var.enable_monitoring_permissions ? toset(var.service_account_emails) : toset([])

  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${each.value}"
}
