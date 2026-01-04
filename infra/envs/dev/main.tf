# -----------------------------------------------------------------------------
# Local Variables
# -----------------------------------------------------------------------------

locals {
  artifact_registry_location = var.artifact_registry_location != "" ? var.artifact_registry_location : var.region

  common_labels = merge(
    var.labels,
    {
      environment = var.environment
      terraform   = "true"
    }
  )
}

# -----------------------------------------------------------------------------
# Enable Required APIs
# -----------------------------------------------------------------------------

resource "google_project_service" "required_apis" {
  for_each = toset(concat(
    var.apis_to_enable,
    var.enable_vertex_ai ? var.vertex_ai_apis : [],
    [var.gemini_api]
  ))

  project = var.project_id
  service = each.value

  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# Artifact Registry
# -----------------------------------------------------------------------------

module "artifact_registry" {
  source = "../../modules/artifact_registry"

  project_id    = var.project_id
  location      = local.artifact_registry_location
  repository_id = var.artifact_registry_repository_id
  description   = "Container images for EduPulse ${var.environment} environment"

  labels = local.common_labels

  depends_on = [
    google_project_service.required_apis
  ]
}

# -----------------------------------------------------------------------------
# Secret Manager
# -----------------------------------------------------------------------------

module "secret_manager" {
  source = "../../modules/secret_manager"

  project_id = var.project_id
  secrets    = var.secrets
  labels     = local.common_labels

  replication_policy = "automatic"

  # Do not create secret versions - values will be set manually or via CI/CD
  create_secret_versions = false

  depends_on = [
    google_project_service.required_apis
  ]
}

# -----------------------------------------------------------------------------
# IAM - Service Accounts and Role Bindings
# -----------------------------------------------------------------------------

locals {
  # Transform services configuration to IAM module format
  iam_services = {
    for service_name, service_config in var.services :
    service_name => {
      display_name = "Service Account for ${service_name}"
      description  = "Service account for ${service_name} in ${var.environment} environment"

      # Extract secret names from secret_env_vars
      secret_names = [
        for secret_key, secret_config in service_config.secret_env_vars :
        secret_config.secret_name
      ]

      # Enable Vertex AI for bandit-engine
      enable_vertex_ai            = service_name == "bandit-engine" && var.enable_vertex_ai
      enable_vertex_ai_prediction = service_name == "bandit-engine" && var.enable_vertex_ai

      # Enable Artifact Registry pull (optional, Cloud Run handles this automatically)
      enable_artifact_registry_pull = false

      # No additional custom roles needed
      additional_roles = []

      # No service-to-service auth needed
      can_act_as = []

      # No Workload Identity (not using GKE)
      enable_workload_identity = false
    }
  }
}

module "iam" {
  source = "../../modules/iam"

  project_id  = var.project_id
  environment = var.environment
  services    = local.iam_services
  labels      = local.common_labels

  depends_on = [
    google_project_service.required_apis,
    module.secret_manager
  ]
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

data "google_project" "project" {
  project_id = var.project_id
}

# -----------------------------------------------------------------------------
# Cloud Run Services
# Deploy each microservice as a Cloud Run service
# -----------------------------------------------------------------------------

module "cloud_run_services" {
  source   = "../../modules/cloud_run_service"
  for_each = var.services

  # Basic configuration
  project_id   = var.project_id
  location     = var.region
  service_name = each.key

  # Container image
  image_uri = "${module.artifact_registry.repository_full_path}/${each.value.image_name}:${each.value.image_tag}"

  # Service account
  service_account_email = module.iam.service_account_emails[each.key]

  # Resource configuration
  port          = each.value.port
  cpu           = each.value.cpu
  memory        = each.value.memory
  min_instances = each.value.min_instances
  max_instances = each.value.max_instances
  concurrency   = each.value.concurrency
  timeout       = each.value.timeout

  # Network configuration
  ingress = each.value.ingress

  # VPC connector (optional, not needed for Confluent Cloud)
  vpc_connector_name = var.enable_vpc_connector ? var.vpc_connector_name : null
  vpc_egress_setting = var.vpc_egress_setting

  # Environment variables
  env_vars        = each.value.env_vars
  secret_env_vars = each.value.secret_env_vars

  # Health checks (Spring Boot Actuator endpoints)
  startup_probe_path              = "/actuator/health/readiness"
  startup_probe_initial_delay     = 0
  startup_probe_timeout           = 3
  startup_probe_period            = 10
  startup_probe_failure_threshold = 3

  liveness_probe_path              = "/actuator/health/liveness"
  liveness_probe_initial_delay     = 0
  liveness_probe_timeout           = 3
  liveness_probe_period            = 10
  liveness_probe_failure_threshold = 3

  # Session affinity for WebSocket (realtime-gateway)
  session_affinity = each.key == "realtime-gateway"

  # IAM
  allow_unauthenticated = var.allow_unauthenticated
  invoker_members       = []

  # Labels
  labels = merge(
    local.common_labels,
    {
      service = each.key
    }
  )

  depends_on = [
    google_project_service.required_apis,
    module.iam,
    module.artifact_registry
  ]
}

# -----------------------------------------------------------------------------
# VPC Connector (Optional - Not needed for Confluent Cloud)
# -----------------------------------------------------------------------------

# VPC Connector is not required for Confluent Cloud access
# Confluent Cloud uses public endpoints with TLS and API key authentication
# Only enable if you need to access private GCP resources (e.g., Cloud SQL, Redis)

# module "vpc_connector" {
#   source = "../../modules/networking"
#   count  = var.enable_vpc_connector ? 1 : 0
#
#   project_id    = var.project_id
#   region        = var.region
#   connector_name = var.vpc_connector_name
#   cidr_range    = var.vpc_connector_cidr
#   machine_type  = var.vpc_connector_machine_type
# }
