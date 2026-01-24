# -----------------------------------------------------------------------------
# API Gateway Module
# Configures GCP API Gateway with OpenAPI specification routing
# -----------------------------------------------------------------------------

locals {
  api_id     = "${var.api_id}-${var.environment}"
  gateway_id = "${var.gateway_id}-${var.environment}"
  config_id  = "${var.api_id}-config-${formatdate("YYYYMMDDhhmmss", timestamp())}"
}

# -----------------------------------------------------------------------------
# Enable Required APIs
# -----------------------------------------------------------------------------

resource "google_project_service" "apigateway" {
  project = var.project_id
  service = "apigateway.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "servicecontrol" {
  project = var.project_id
  service = "servicecontrol.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "servicemanagement" {
  project = var.project_id
  service = "servicemanagement.googleapis.com"

  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# Service Account for API Gateway
# -----------------------------------------------------------------------------

resource "google_service_account" "api_gateway" {
  project      = var.project_id
  account_id   = "api-gateway-${var.environment}"
  display_name = "API Gateway Service Account (${var.environment})"
  description  = "Service account for API Gateway to invoke Cloud Run services"
}

# Grant the service account permission to invoke Cloud Run services
resource "google_project_iam_member" "api_gateway_run_invoker" {
  project = var.project_id
  role    = "roles/run.invoker"
  member  = "serviceAccount:${google_service_account.api_gateway.email}"
}

# -----------------------------------------------------------------------------
# API Gateway API Definition
# -----------------------------------------------------------------------------

resource "google_api_gateway_api" "api" {
  provider = google-beta
  project  = var.project_id

  api_id       = local.api_id
  display_name = "${var.display_name} (${var.environment})"

  labels = var.labels

  depends_on = [
    google_project_service.apigateway,
    google_project_service.servicecontrol,
    google_project_service.servicemanagement
  ]
}

# -----------------------------------------------------------------------------
# API Gateway API Config (OpenAPI Specification)
# -----------------------------------------------------------------------------

resource "google_api_gateway_api_config" "config" {
  provider = google-beta
  project  = var.project_id

  api           = google_api_gateway_api.api.api_id
  api_config_id = local.config_id
  display_name  = "API Config ${var.environment}"

  openapi_documents {
    document {
      path     = "openapi.yaml"
      contents = base64encode(templatefile("${path.module}/openapi.yaml.tpl", {
        project_id            = var.project_id
        api_title             = var.display_name
        api_description       = "EduPulse Real-Time Adaptive Learning Platform API"
        default_backend_url   = var.default_backend_url
        backend_services      = var.backend_services
        service_account_email = google_service_account.api_gateway.email
        deadline              = var.deadline
        cors_allowed_origins  = join(",", var.cors_allowed_origins)
        cors_allowed_methods  = join(",", var.cors_allowed_methods)
        cors_allowed_headers  = join(",", var.cors_allowed_headers)
        enable_api_key        = var.enable_api_key
      }))
    }
  }

  gateway_config {
    backend_config {
      google_service_account = google_service_account.api_gateway.email
    }
  }

  labels = var.labels

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    google_api_gateway_api.api,
    google_service_account.api_gateway,
    google_project_iam_member.api_gateway_run_invoker
  ]
}

# -----------------------------------------------------------------------------
# API Gateway Gateway (Deployment)
# -----------------------------------------------------------------------------

resource "google_api_gateway_gateway" "gateway" {
  provider = google-beta
  project  = var.project_id
  region   = var.region

  gateway_id = local.gateway_id
  api_config = google_api_gateway_api_config.config.id

  display_name = "${var.display_name} Gateway (${var.environment})"

  labels = var.labels

  depends_on = [
    google_api_gateway_api_config.config
  ]
}
