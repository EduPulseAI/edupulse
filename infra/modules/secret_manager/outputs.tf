output "secret_ids" {
  description = "Map of secret names to their full resource IDs (projects/{project}/secrets/{secret_id})"
  value = {
    for name, secret in google_secret_manager_secret.secrets :
    name => secret.id
  }
}

output "secret_names" {
  description = "Map of secret names to their secret_id values"
  value = {
    for name, secret in google_secret_manager_secret.secrets :
    name => secret.secret_id
  }
}

output "secret_versions" {
  description = "Map of secret names to their latest version IDs (if versions were created)"
  value = var.create_secret_versions ? {
    for name, version in google_secret_manager_secret_version.secret_versions :
    name => version.id
  } : {}
  sensitive = true
}

output "secret_version_names" {
  description = "Map of secret names to their latest version names (if versions were created)"
  value = var.create_secret_versions ? {
    for name, version in google_secret_manager_secret_version.secret_versions :
    name => version.name
  } : {}
}

output "all_secrets" {
  description = "Complete map of all secret resources created"
  value = {
    for name, secret in google_secret_manager_secret.secrets :
    name => {
      id         = secret.id
      secret_id  = secret.secret_id
      project    = secret.project
      name       = secret.name
      create_time = secret.create_time
      labels     = secret.labels
    }
  }
}
