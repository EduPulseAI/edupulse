# -----------------------------------------------------------------------------
# Project Information
# -----------------------------------------------------------------------------

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region for resources"
  value       = var.region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

# -----------------------------------------------------------------------------
# Artifact Registry Outputs
# -----------------------------------------------------------------------------

output "artifact_registry_repository_id" {
  description = "Artifact Registry repository ID"
  value       = module.artifact_registry.repository_id
}

output "artifact_registry_repository_url" {
  description = "Artifact Registry repository URL for docker commands"
  value       = module.artifact_registry.repository_url
}

output "artifact_registry_docker_hostname" {
  description = "Docker registry hostname"
  value       = module.artifact_registry.docker_hostname
}

output "artifact_registry_full_path" {
  description = "Full path for docker images"
  value       = module.artifact_registry.repository_full_path
}

# -----------------------------------------------------------------------------
# Secret Manager Outputs
# -----------------------------------------------------------------------------

output "secret_ids" {
  description = "Map of secret names to their resource IDs"
  value       = module.secret_manager.secret_ids
}

output "secret_names" {
  description = "Map of secret names to their secret_id values"
  value       = module.secret_manager.secret_names
}

output "secrets_created" {
  description = "List of secret names created"
  value       = keys(module.secret_manager.secret_ids)
}

# -----------------------------------------------------------------------------
# Service Account Outputs
# -----------------------------------------------------------------------------

output "service_accounts" {
  description = "Map of Cloud Run service names to their service account details"
  value       = module.iam.service_accounts
}

output "service_account_emails" {
  description = "Map of service names to their service account email addresses"
  value       = module.iam.service_account_emails
}

output "iam_summary" {
  description = "Summary of IAM configuration for each service"
  value       = module.iam.iam_summary
}

# -----------------------------------------------------------------------------
# Cloud Run Service Outputs
# -----------------------------------------------------------------------------

output "cloud_run_services" {
  description = "Map of Cloud Run service names to their details"
  value = {
    for service_name, service in module.cloud_run_services :
    service_name => service.service_summary
  }
}

output "cloud_run_service_urls" {
  description = "Map of Cloud Run service names to their public URLs"
  value = {
    for service_name, service in module.cloud_run_services :
    service_name => service.service_url
  }
}

output "cloud_run_service_names" {
  description = "List of Cloud Run service names"
  value       = [for service_name in keys(module.cloud_run_services) : service_name]
}

# -----------------------------------------------------------------------------
# Docker Build Commands
# -----------------------------------------------------------------------------

output "docker_build_commands" {
  description = "Example docker build and push commands for each service"
  value = {
    for service_name, service_config in var.services :
    service_name => {
      tag       = "${module.artifact_registry.repository_full_path}/${service_config.image_name}:${service_config.image_tag}"
      build_cmd = "docker build -t ${module.artifact_registry.repository_full_path}/${service_config.image_name}:${service_config.image_tag} ./backend/${service_name}"
      push_cmd  = "docker push ${module.artifact_registry.repository_full_path}/${service_config.image_name}:${service_config.image_tag}"
    }
  }
}

# -----------------------------------------------------------------------------
# Next Steps
# -----------------------------------------------------------------------------

output "next_steps" {
  description = "Next steps for deployment"
  value       = <<-EOT

  ====================================================================
  Terraform Apply Successful - Next Steps:
  ====================================================================

  1. Authenticate Docker with Artifact Registry:
     gcloud auth configure-docker ${module.artifact_registry.docker_hostname}

  2. Set secret values (replace with actual values from Confluent Cloud):

     # Kafka credentials
     echo -n "pkc-xxxxx.us-east-1.aws.confluent.cloud:9092" | gcloud secrets versions add kafka-bootstrap-servers --data-file=-
     echo -n "YOUR_KAFKA_API_KEY" | gcloud secrets versions add kafka-api-key --data-file=-
     echo -n "YOUR_KAFKA_API_SECRET" | gcloud secrets versions add kafka-api-secret --data-file=-

     # Schema Registry credentials
     echo -n "https://psrc-xxxxx.us-east-1.aws.confluent.cloud" | gcloud secrets versions add schema-registry-url --data-file=-
     echo -n "YOUR_SR_API_KEY" | gcloud secrets versions add schema-registry-api-key --data-file=-
     echo -n "YOUR_SR_API_SECRET" | gcloud secrets versions add schema-registry-api-secret --data-file=-

     # Gemini API key
     echo -n "YOUR_GEMINI_API_KEY" | gcloud secrets versions add gemini-api-key --data-file=-

     # PostgreSQL credentials (for quizzer service)
     echo -n "edupulse" | gcloud secrets versions add postgres-user --data-file=-
     echo -n "YOUR_POSTGRES_PASSWORD" | gcloud secrets versions add postgres-password --data-file=-
     echo -n "edupulse" | gcloud secrets versions add postgres-database --data-file=-

     # JWT signing key
     echo -n "$(openssl rand -base64 32)" | gcloud secrets versions add jwt-signing-key --data-file=-

  3. Build and push container images:
     # Example for event-ingest-service
     cd ../../../backend/event-ingest-service
     docker build -t ${module.artifact_registry.repository_full_path}/event-ingest-service:latest .
     docker push ${module.artifact_registry.repository_full_path}/event-ingest-service:latest

     # Or use the deploy script (once created):
     # ../../../scripts/deploy_with_terraform.sh

  4. Deploy Cloud Run services:
     terraform apply

  5. Verify deployment:
     gcloud run services list --project=${var.project_id} --region=${var.region}

  6. Access your services:
     ${join("\n     ", [for name, url in module.cloud_run_services : "${name}: ${url.service_url}"])}

  7. Test Kafka connectivity from event-ingest-service:
     curl -X POST https://YOUR_SERVICE_URL/actuator/health

  ====================================================================
  EOT
}
