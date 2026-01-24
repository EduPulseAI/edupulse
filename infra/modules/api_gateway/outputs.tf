# -----------------------------------------------------------------------------
# API Gateway Module Outputs
# -----------------------------------------------------------------------------

output "gateway_url" {
  description = "The default hostname of the API Gateway"
  value       = "https://${google_api_gateway_gateway.gateway.default_hostname}"
}

output "gateway_id" {
  description = "The ID of the API Gateway"
  value       = google_api_gateway_gateway.gateway.gateway_id
}

output "gateway_name" {
  description = "The full resource name of the API Gateway"
  value       = google_api_gateway_gateway.gateway.name
}

output "api_id" {
  description = "The ID of the API"
  value       = google_api_gateway_api.api.api_id
}

output "api_config_id" {
  description = "The ID of the API Config"
  value       = google_api_gateway_api_config.config.api_config_id
}

output "service_account_email" {
  description = "The email of the API Gateway service account"
  value       = google_service_account.api_gateway.email
}

output "gateway_summary" {
  description = "Summary of the API Gateway configuration"
  value = {
    gateway_url           = "https://${google_api_gateway_gateway.gateway.default_hostname}"
    gateway_id            = google_api_gateway_gateway.gateway.gateway_id
    api_id                = google_api_gateway_api.api.api_id
    api_config_id         = google_api_gateway_api_config.config.api_config_id
    region                = var.region
    service_account_email = google_service_account.api_gateway.email
  }
}
