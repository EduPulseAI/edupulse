# -----------------------------------------------------------------------------
# Cloud Run Service Module
# Deploys a single Cloud Run service with configurable settings
# -----------------------------------------------------------------------------

resource "google_cloud_run_v2_service" "service" {
  project  = var.project_id
  location = var.location
  name     = var.service_name

  ingress = var.ingress

  labels = var.labels

  template {
    # Service account for the Cloud Run service
    service_account = var.service_account_email

    # Scaling configuration
    scaling {
      min_instance_count = var.min_instances
      max_instance_count = var.max_instances
    }

    # Execution timeout
    timeout = "${var.timeout}s"

    # Max concurrent requests per instance
    max_instance_request_concurrency = var.concurrency

    containers {
      # Container image from Artifact Registry
      image = var.image_uri

      # Container port
      ports {
        container_port = var.port
        name           = "http1"
      }

      # Resource limits
      resources {
        limits = {
          cpu    = var.cpu
          memory = var.memory
        }

        # CPU is always allocated (not throttled when idle)
        cpu_idle = false

        # Startup CPU boost for faster cold starts
        startup_cpu_boost = true
      }

      # Environment variables (non-secret)
      dynamic "env" {
        for_each = var.env_vars
        content {
          name  = env.key
          value = env.value
        }
      }

      # Secret environment variables from Secret Manager
      dynamic "env" {
        for_each = var.secret_env_vars
        content {
          name = env.key
          value_source {
            secret_key_ref {
              secret  = env.value.secret_name
              version = env.value.version
            }
          }
        }
      }

      # Startup probe (optional)
      dynamic "startup_probe" {
        for_each = var.startup_probe_path != null ? [1] : []
        content {
          http_get {
            path = var.startup_probe_path
            port = var.port
          }
          initial_delay_seconds = var.startup_probe_initial_delay
          timeout_seconds       = var.startup_probe_timeout
          period_seconds        = var.startup_probe_period
          failure_threshold     = var.startup_probe_failure_threshold
        }
      }

      # Liveness probe (optional)
      dynamic "liveness_probe" {
        for_each = var.liveness_probe_path != null ? [1] : []
        content {
          http_get {
            path = var.liveness_probe_path
            port = var.port
          }
          initial_delay_seconds = var.liveness_probe_initial_delay
          timeout_seconds       = var.liveness_probe_timeout
          period_seconds        = var.liveness_probe_period
          failure_threshold     = var.liveness_probe_failure_threshold
        }
      }
    }

    # VPC connector (optional, for private resource access)
    # Note: Use enable_vpc_access (static bool) instead of checking vpc_connector_name != null
    # to avoid "block count changed" errors when vpc_connector_name is a computed value
    dynamic "vpc_access" {
      for_each = var.enable_vpc_access ? [1] : []
      content {
        connector = var.vpc_connector_name
        egress    = var.vpc_egress_setting
      }
    }

    # Session affinity (for WebSocket support)
    session_affinity = var.session_affinity
  }

  # Traffic routing (100% to latest revision)
  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }

  depends_on = [
    google_project_service.cloudrun_api
  ]
}

# Enable Cloud Run API (idempotent)
resource "google_project_service" "cloudrun_api" {
  project = var.project_id
  service = "run.googleapis.com"

  disable_on_destroy = false
}

# IAM policy for public/authenticated access
resource "google_cloud_run_v2_service_iam_member" "public_access" {
  count = var.allow_unauthenticated ? 1 : 0

  project  = var.project_id
  location = var.location
  name     = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Grant Cloud Run Invoker to specific members (for internal services)
resource "google_cloud_run_v2_service_iam_member" "invokers" {
  for_each = toset(var.invoker_members)

  project  = var.project_id
  location = var.location
  name     = google_cloud_run_v2_service.service.name
  role     = "roles/run.invoker"
  member   = each.value
}
