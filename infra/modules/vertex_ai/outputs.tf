output "enabled_apis" {
  description = "List of Vertex AI APIs that were enabled"
  value       = var.enable_apis ? var.apis_to_enable : []
}

output "api_enablement_status" {
  description = "Map of API names to their enablement status"
  value = var.enable_apis ? {
    for api in var.apis_to_enable :
    api => "enabled"
  } : {}
}

output "vertex_ai_user_bindings" {
  description = "Map of service accounts granted Vertex AI User role"
  value = {
    for email in var.service_account_emails :
    email => {
      role   = "roles/aiplatform.user"
      member = "serviceAccount:${email}"
    }
  }
}

output "vertex_ai_service_agent_bindings" {
  description = "Map of service accounts granted Vertex AI Service Agent role (if enabled)"
  value = var.enable_service_agent_role ? {
    for email in var.service_account_emails :
    email => {
      role   = "roles/aiplatform.serviceAgent"
      member = "serviceAccount:${email}"
    }
  } : {}
}

output "vertex_ai_admin_bindings" {
  description = "Map of service accounts granted Vertex AI Admin role (if enabled)"
  value = var.enable_admin_role ? {
    for email in var.admin_service_account_emails :
    email => {
      role   = "roles/aiplatform.admin"
      member = "serviceAccount:${email}"
    }
  } : {}
}

output "service_accounts_with_access" {
  description = "List of all service account emails with Vertex AI access"
  value       = var.service_account_emails
}

output "vertex_ai_endpoint_format" {
  description = "Format for Vertex AI endpoint URLs (informational)"
  value       = "https://${var.region}-aiplatform.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/endpoints/{ENDPOINT_ID}:predict"
}

output "iam_roles_granted" {
  description = "Summary of all IAM roles granted by this module"
  value = {
    vertex_ai_user = {
      role               = "roles/aiplatform.user"
      granted_to         = var.service_account_emails
      count              = length(var.service_account_emails)
    }
    vertex_ai_service_agent = {
      role               = "roles/aiplatform.serviceAgent"
      granted_to         = var.enable_service_agent_role ? var.service_account_emails : []
      count              = var.enable_service_agent_role ? length(var.service_account_emails) : 0
    }
    vertex_ai_admin = {
      role               = "roles/aiplatform.admin"
      granted_to         = var.enable_admin_role ? var.admin_service_account_emails : []
      count              = var.enable_admin_role ? length(var.admin_service_account_emails) : 0
    }
    default_service_agent = {
      role               = "roles/aiplatform.serviceAgent"
      granted_to         = var.enable_default_service_agent ? ["service-${data.google_project.project.number}@gcp-sa-aiplatform.iam.gserviceaccount.com"] : []
      count              = var.enable_default_service_agent ? 1 : 0
    }
  }
}

output "next_steps" {
  description = "Next steps for using Vertex AI"
  value = <<-EOT

  ====================================================================
  Vertex AI Module - Configuration Complete
  ====================================================================

  APIs Enabled: ${var.enable_apis ? join(", ", var.apis_to_enable) : "Managed elsewhere"}
  Service Accounts with Access: ${length(var.service_account_emails)}

  Next Steps:

  1. Deploy a Vertex AI model endpoint (if not already deployed):
     gcloud ai endpoints deploy-model ${var.region} \
       --project=${var.project_id} \
       --model=YOUR_MODEL_ID \
       --display-name=bandit-model

  2. Get endpoint ID:
     gcloud ai endpoints list --project=${var.project_id} --region=${var.region}

  3. Test prediction from authorized service account:
     curl -X POST \
       -H "Authorization: Bearer $(gcloud auth print-access-token)" \
       -H "Content-Type: application/json" \
       https://${var.region}-aiplatform.googleapis.com/v1/projects/${var.project_id}/locations/${var.region}/endpoints/ENDPOINT_ID:predict \
       -d '{"instances": [{"feature1": 0.5, "feature2": 0.8}]}'

  4. Use endpoint in application (Spring Boot example):
     VERTEX_AI_ENDPOINT_ID=your-endpoint-id
     VERTEX_AI_PROJECT=${var.project_id}
     VERTEX_AI_REGION=${var.region}

  ====================================================================
  EOT
}
