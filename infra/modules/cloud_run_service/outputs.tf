# -----------------------------------------------------------------------------
# Cloud Run Service Outputs
# -----------------------------------------------------------------------------

output "service_name" {
  description = "Name of the Cloud Run service"
  value       = google_cloud_run_v2_service.service.name
}

output "service_id" {
  description = "Full resource ID of the Cloud Run service"
  value       = google_cloud_run_v2_service.service.id
}

output "service_uri" {
  description = "URI of the Cloud Run service (HTTPS endpoint)"
  value       = google_cloud_run_v2_service.service.uri
}

output "service_url" {
  description = "Public URL of the Cloud Run service (same as uri)"
  value       = google_cloud_run_v2_service.service.uri
}

output "location" {
  description = "Location where the service is deployed"
  value       = google_cloud_run_v2_service.service.location
}

output "latest_revision" {
  description = "Name of the latest ready revision"
  value       = google_cloud_run_v2_service.service.latest_ready_revision
}

output "latest_created_revision" {
  description = "Name of the latest created revision"
  value       = google_cloud_run_v2_service.service.latest_created_revision
}

output "service_account_email" {
  description = "Service account email used by the Cloud Run service"
  value       = var.service_account_email
}

output "image_uri" {
  description = "Container image URI deployed to this service"
  value       = var.image_uri
}

output "is_public" {
  description = "Whether the service allows unauthenticated access"
  value       = var.allow_unauthenticated
}

output "ingress" {
  description = "Ingress setting for the service"
  value       = var.ingress
}

output "resource_limits" {
  description = "Resource limits (CPU and memory) configured for the service"
  value = {
    cpu    = var.cpu
    memory = var.memory
  }
}

output "scaling_config" {
  description = "Autoscaling configuration"
  value = {
    min_instances = var.min_instances
    max_instances = var.max_instances
    concurrency   = var.concurrency
  }
}

output "env_var_count" {
  description = "Number of environment variables configured"
  value       = length(var.env_vars)
}

output "secret_env_var_count" {
  description = "Number of secret environment variables configured"
  value       = length(var.secret_env_vars)
}

output "health_checks_enabled" {
  description = "Summary of enabled health checks"
  value = {
    startup_probe  = var.startup_probe_path != null
    liveness_probe = var.liveness_probe_path != null
  }
}

output "vpc_access_enabled" {
  description = "Whether VPC access is configured"
  value       = var.vpc_connector_name != null
}

output "service_summary" {
  description = "Summary of the Cloud Run service configuration"
  value = {
    name            = google_cloud_run_v2_service.service.name
    url             = google_cloud_run_v2_service.service.uri
    location        = google_cloud_run_v2_service.service.location
    image           = var.image_uri
    service_account = var.service_account_email
    cpu             = var.cpu
    memory          = var.memory
    min_instances   = var.min_instances
    max_instances   = var.max_instances
    allow_public    = var.allow_unauthenticated
    ingress         = var.ingress
    latest_revision = google_cloud_run_v2_service.service.latest_ready_revision
  }
}
