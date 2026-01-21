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


output "quiz_service_url" {
  description = "Quiz ingest service URL"
  value       = try(module.cloud_run_services["quiz-service"].service_url, "")
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
# Vertex AI Outputs
# -----------------------------------------------------------------------------

output "vertex_ai_enabled" {
  description = "Whether Vertex AI is enabled for this environment"
  value       = var.enable_vertex_ai
}

output "vertex_ai_service_accounts" {
  description = "Service accounts with Vertex AI access"
  value       = var.enable_vertex_ai ? module.vertex_ai[0].service_accounts_with_access : []
}

output "vertex_ai_endpoint_format" {
  description = "Format for Vertex AI endpoint URLs"
  value       = var.enable_vertex_ai ? module.vertex_ai[0].vertex_ai_endpoint_format : null
}

output "vertex_ai_iam_roles" {
  description = "Summary of IAM roles granted for Vertex AI"
  value       = var.enable_vertex_ai ? module.vertex_ai[0].iam_roles_granted : {}
}

output "vertex_ai_enabled_apis" {
  description = "List of Vertex AI APIs that were enabled"
  value       = var.enable_vertex_ai ? module.vertex_ai[0].enabled_apis : []
}

# -----------------------------------------------------------------------------
# Redis Memorystore Outputs
# -----------------------------------------------------------------------------

output "redis_enabled" {
  description = "Whether Redis Memorystore is enabled"
  value       = var.enable_redis
}

output "redis_host" {
  description = "Redis instance host IP"
  value       = var.enable_redis ? module.redis[0].host : null
}

output "redis_port" {
  description = "Redis instance port"
  value       = var.enable_redis ? module.redis[0].port : null
}

output "redis_connection_string" {
  description = "Redis connection string (host:port)"
  value       = var.enable_redis ? module.redis[0].connection_string : null
}

output "redis_auth_string" {
  description = "Redis AUTH password (sensitive)"
  value       = var.enable_redis ? module.redis[0].auth_string : null
  sensitive   = true
}

# -----------------------------------------------------------------------------
# VPC Connector Outputs
# -----------------------------------------------------------------------------

output "vpc_connector_enabled" {
  description = "Whether VPC connector is enabled"
  value       = var.enable_vpc_connector
}

output "vpc_connector_name" {
  description = "Name of the VPC connector"
  value       = var.enable_vpc_connector ? module.networking[0].connector_name : null
}

output "vpc_connector_self_link" {
  description = "Self-link of the VPC connector (for Cloud Run)"
  value       = var.enable_vpc_connector ? module.networking[0].connector_self_link : null
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

     # PostgreSQL credentials (for quiz service)
     echo -n "edupulse" | gcloud secrets versions add postgres-user --data-file=-
     echo -n "YOUR_POSTGRES_PASSWORD" | gcloud secrets versions add postgres-password --data-file=-
     echo -n "edupulse" | gcloud secrets versions add postgres-database --data-file=-

     # JWT signing key
     echo -n "$(openssl rand -base64 32)" | gcloud secrets versions add jwt-signing-key --data-file=-

     # Redis Memorystore credentials (after terraform apply creates Redis instance)
     # Get values from terraform output:
     #   terraform output redis_host
     #   terraform output redis_port
     #   terraform output -raw redis_auth_string
     echo -n "REDIS_HOST_FROM_OUTPUT" | gcloud secrets versions add redis-host --data-file=-
     echo -n "6379" | gcloud secrets versions add redis-port --data-file=-
     terraform output -raw redis_auth_string | gcloud secrets versions add redis-password --data-file=-

  3. Build and push container images:
     # Example for quiz-service
     cd ../../../backend/quiz-service
     docker build -t ${module.artifact_registry.repository_full_path}/quiz-service:latest .
     docker push ${module.artifact_registry.repository_full_path}/quiz-service:latest

     # Or use the deploy script (once created):
     # ../../../scripts/deploy_with_terraform.sh

  4. Deploy Cloud Run services:
     terraform apply

  5. Verify deployment:
     gcloud run services list --project=${var.project_id} --region=${var.region}

  6. Access your services:
     ${join("\n     ", [for name, url in module.cloud_run_services : "${name}: ${url.service_url}"])}

  7. Test Kafka connectivity from quiz-service:
     curl -X POST https://YOUR_SERVICE_URL/actuator/health

  ${var.enable_vertex_ai ? "8. Configure Vertex AI for bandit-engine (if using AI features):\n     # Deploy a model endpoint or use pre-trained model\n     gcloud ai endpoints list --project=${var.project_id} --region=${var.region}\n     \n     # Update bandit-engine environment variable with endpoint ID:\n     VERTEX_AI_ENDPOINT_ID=your-endpoint-id\n" : ""}
  ====================================================================
  EOT
}
