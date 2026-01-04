# -----------------------------------------------------------------------------
# Design Decision: Per-Service Service Accounts
#
# We create individual service accounts for each Cloud Run service rather than
# a shared service account because:
# 1. Security isolation: Compromised service doesn't expose others
# 2. Granular access: Each service gets only the secrets/APIs it needs
# 3. Audit clarity: Actions are clearly attributed to specific services
# 4. Compliance: Easier to prove least-privilege access for certifications
# 5. Scalability: New services don't inherit unnecessary permissions
#
# Trade-off: More IAM resources to manage, but tools like this module mitigate that.
# -----------------------------------------------------------------------------

# Create service accounts for each Cloud Run service
resource "google_service_account" "service_accounts" {
  for_each = var.services

  project      = var.project_id
  account_id   = "${each.key}-sa"
  display_name = try(each.value.display_name, "Service Account for ${each.key}")
  description  = try(each.value.description, "Managed by Terraform for ${each.key} in ${var.environment} environment")
}

# -----------------------------------------------------------------------------
# Secret Manager Access
# Grant secretAccessor role to service accounts for their specific secrets
# -----------------------------------------------------------------------------

resource "google_secret_manager_secret_iam_member" "secret_access" {
  for_each = {
    for pair in flatten([
      for service_name, service_config in var.services : [
        for secret_name in try(service_config.secret_names, []) : {
          key          = "${service_name}:${secret_name}"
          service_name = service_name
          secret_name  = secret_name
        }
      ]
    ]) : pair.key => pair
  }

  project   = var.project_id
  secret_id = each.value.secret_name
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.service_accounts[each.value.service_name].email}"
}

# -----------------------------------------------------------------------------
# Vertex AI Access
# Grant Vertex AI User role to services that need AI capabilities
# -----------------------------------------------------------------------------

resource "google_project_iam_member" "vertex_ai_user" {
  for_each = {
    for service_name, service_config in var.services :
    service_name => service_config
    if try(service_config.enable_vertex_ai, false)
  }

  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.service_accounts[each.key].email}"
}

# Grant Vertex AI Prediction Service Agent for model invocation
resource "google_project_iam_member" "vertex_ai_prediction" {
  for_each = {
    for service_name, service_config in var.services :
    service_name => service_config
    if try(service_config.enable_vertex_ai_prediction, false)
  }

  project = var.project_id
  role    = "roles/aiplatform.serviceAgent"
  member  = "serviceAccount:${google_service_account.service_accounts[each.key].email}"
}

# -----------------------------------------------------------------------------
# Artifact Registry Access
# Grant Artifact Registry Reader for pulling container images
# Note: Cloud Run automatically grants this to the Cloud Run Service Agent,
# but we can explicitly grant it to service accounts for clarity/direct pulls
# -----------------------------------------------------------------------------

resource "google_project_iam_member" "artifact_registry_reader" {
  for_each = {
    for service_name, service_config in var.services :
    service_name => service_config
    if try(service_config.enable_artifact_registry_pull, false)
  }

  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.service_accounts[each.key].email}"
}

# -----------------------------------------------------------------------------
# Custom Role Bindings
# Support for additional custom roles per service
# -----------------------------------------------------------------------------

resource "google_project_iam_member" "custom_roles" {
  for_each = {
    for pair in flatten([
      for service_name, service_config in var.services : [
        for role in try(service_config.additional_roles, []) : {
          key          = "${service_name}:${role}"
          service_name = service_name
          role         = role
        }
      ]
    ]) : pair.key => pair
  }

  project = var.project_id
  role    = each.value.role
  member  = "serviceAccount:${google_service_account.service_accounts[each.value.service_name].email}"
}

# -----------------------------------------------------------------------------
# Service Account Token Creator (for service-to-service auth if needed)
# -----------------------------------------------------------------------------

resource "google_service_account_iam_member" "token_creator" {
  for_each = {
    for pair in flatten([
      for service_name, service_config in var.services : [
        for allowed_service in try(service_config.can_act_as, []) : {
          key            = "${service_name}:${allowed_service}"
          service_name   = service_name
          allowed_service = allowed_service
        }
      ]
    ]) : pair.key => pair
  }

  service_account_id = google_service_account.service_accounts[each.value.allowed_service].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.service_accounts[each.value.service_name].email}"
}

# -----------------------------------------------------------------------------
# Workload Identity (for GKE if needed in future)
# -----------------------------------------------------------------------------

resource "google_service_account_iam_member" "workload_identity" {
  for_each = {
    for service_name, service_config in var.services :
    service_name => service_config
    if try(service_config.enable_workload_identity, false)
  }

  service_account_id = google_service_account.service_accounts[each.key].name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${try(each.value.k8s_namespace, "default")}/${each.key}]"
}
