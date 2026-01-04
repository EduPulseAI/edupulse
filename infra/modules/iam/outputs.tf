output "service_account_emails" {
  description = "Map of service names to their service account email addresses"
  value = {
    for service_name, sa in google_service_account.service_accounts :
    service_name => sa.email
  }
}

output "service_account_ids" {
  description = "Map of service names to their service account unique IDs"
  value = {
    for service_name, sa in google_service_account.service_accounts :
    service_name => sa.unique_id
  }
}

output "service_account_names" {
  description = "Map of service names to their service account resource names (projects/{project}/serviceAccounts/{email})"
  value = {
    for service_name, sa in google_service_account.service_accounts :
    service_name => sa.name
  }
}

output "service_accounts" {
  description = "Complete map of all service account details"
  value = {
    for service_name, sa in google_service_account.service_accounts :
    service_name => {
      email       = sa.email
      unique_id   = sa.unique_id
      name        = sa.name
      account_id  = sa.account_id
      display_name = sa.display_name
      description = sa.description
    }
  }
}

output "secret_access_bindings" {
  description = "Map of secret access IAM bindings created"
  value = {
    for binding_key, binding in google_secret_manager_secret_iam_member.secret_access :
    binding_key => {
      secret_id = binding.secret_id
      role      = binding.role
      member    = binding.member
    }
  }
}

output "vertex_ai_bindings" {
  description = "Map of Vertex AI IAM bindings created"
  value = {
    for service_name, binding in google_project_iam_member.vertex_ai_user :
    service_name => {
      role   = binding.role
      member = binding.member
    }
  }
}

output "custom_role_bindings" {
  description = "Map of custom IAM role bindings created"
  value = {
    for binding_key, binding in google_project_iam_member.custom_roles :
    binding_key => {
      role   = binding.role
      member = binding.member
    }
  }
}

output "iam_summary" {
  description = "Summary of IAM configuration for each service"
  value = {
    for service_name, sa in google_service_account.service_accounts :
    service_name => {
      service_account = sa.email
      secrets_access = [
        for binding_key, binding in google_secret_manager_secret_iam_member.secret_access :
        binding.secret_id if startswith(binding_key, "${service_name}:")
      ]
      has_vertex_ai = contains(keys(google_project_iam_member.vertex_ai_user), service_name)
      has_artifact_registry = contains(keys(google_project_iam_member.artifact_registry_reader), service_name)
      additional_roles = [
        for binding_key, binding in google_project_iam_member.custom_roles :
        binding.role if startswith(binding_key, "${service_name}:")
      ]
    }
  }
}
