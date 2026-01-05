resource "google_secret_manager_secret" "secrets" {
  for_each = { for secret in var.secrets : secret.name => secret }

  project   = var.project_id
  secret_id = each.value.name

  labels = merge(
    var.labels,
    try(each.value.labels, {})
  )

  replication {
    dynamic "auto" {
      for_each = var.replication_policy == "automatic" ? [1] : []
      content {}
    }

    dynamic "user_managed" {
      for_each = var.replication_policy == "user_managed" ? [1] : []
      content {
        dynamic "replicas" {
          for_each = var.replication_locations
          content {
            location = replicas.value
            dynamic "customer_managed_encryption" {
              for_each = var.kms_key_name != null ? [1] : []
              content {
                kms_key_name = var.kms_key_name
              }
            }
          }
        }
      }
    }
  }

  # Optional: Set expiration time for secrets
  # dynamic "rotation" {
  #   for_each = try(each.value.rotation_period, null) != null ? [1] : []
  #   content {
  #     rotation_period = each.value.rotation_period
  #     next_rotation_time = try(each.value.next_rotation_time, null)
  #   }
  # }

  depends_on = [
    google_project_service.secretmanager_api
  ]
}

# Only create secret versions if explicitly provided (not recommended for production)
# Secret values should be set via gcloud CLI, Console, or CI/CD pipelines
resource "google_secret_manager_secret_version" "secret_versions" {
  for_each = var.create_secret_versions ? { for secret in var.secrets : secret.name => secret if try(secret.secret_data, null) != null } : {}

  secret      = google_secret_manager_secret.secrets[each.key].id
  secret_data = each.value.secret_data

  depends_on = [
    google_secret_manager_secret.secrets
  ]
}

# Enable Secret Manager API
resource "google_project_service" "secretmanager_api" {
  project = var.project_id
  service = "secretmanager.googleapis.com"

  disable_on_destroy = false
}

# IAM bindings for secret access
resource "google_secret_manager_secret_iam_member" "secret_accessors" {
  for_each = var.secret_accessors != null ? {
    for pair in flatten([
      for secret_name, members in var.secret_accessors : [
        for member in members : {
          secret_name = secret_name
          member      = member
        }
      ]
    ]) : "${pair.secret_name}:${pair.member}" => pair
  } : {}

  project   = var.project_id
  secret_id = google_secret_manager_secret.secrets[each.value.secret_name].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value.member

  depends_on = [
    google_secret_manager_secret.secrets
  ]
}
