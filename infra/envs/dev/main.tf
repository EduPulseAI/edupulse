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

  # Services that register with / discover from Eureka
  eureka_dependent_services = toset(["api-gateway", "profile-service"])

  eureka_env_vars = {
    EUREKA_PROTOCOL = "https"
    EUREKA_HOST     = trimprefix(module.eureka_server.service_uri, "https://")
    EUREKA_PORT     = "443"
  }

  # Exclude eureka-server from the general for_each (deployed separately below)
  # and inject computed eureka env vars into any dependent service
  services_for_each = {
    for k, v in var.services : k => merge(v, {
      env_vars = contains(local.eureka_dependent_services, k) ? merge(v.env_vars, local.eureka_env_vars) : v.env_vars
    }) if k != "eureka-server"
  }
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
# Secret Values Configuration
# -----------------------------------------------------------------------------
# Secret values must be set manually using the set-secrets.sh script:
#   scripts/gcloud/set-secrets.sh <project-id>
#
# This is done separately from terraform apply to avoid provisioning timing issues.
# Run the script after: terraform apply
# -----------------------------------------------------------------------------

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

      # Enable Vertex AI for services that need it
      enable_vertex_ai            = contains(["quiz-service", "bandit-engine", "tip-service"], service_name) && var.enable_vertex_ai
      enable_vertex_ai_prediction = contains(["quiz-service", "bandit-engine", "tip-service"], service_name) && var.enable_vertex_ai

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
# Vertex AI
# Enable Vertex AI APIs and configure IAM for AI-powered features
# -----------------------------------------------------------------------------

module "vertex_ai" {
  source = "../../modules/vertex_ai"
  count  = var.enable_vertex_ai ? 1 : 0

  project_id = var.project_id
  region     = var.region

  # Enable APIs via this module
  enable_apis    = true
  apis_to_enable = var.vertex_ai_apis

  # Grant Vertex AI User role to service accounts that need it
  # Only include service accounts that are actually deployed
  # Use service account emails directly from IAM module (computed)
  service_account_emails = [
    for service_name in ["quiz-service", "bandit-engine", "tip-service", "profile-service"] :
    "${service_name}-sa@${var.project_id}.iam.gserviceaccount.com"
    if contains(keys(var.services), service_name)
  ]

  # Enable default GCP-managed service agent for Vertex AI
  # Disabled until we actually deploy Vertex AI models/endpoints
  enable_default_service_agent = false

  # Optional: Enable logging and monitoring for Vertex AI operations
  enable_logging_permissions    = true
  enable_monitoring_permissions = true

  # Labels
  labels = local.common_labels

  depends_on = [
    google_project_service.required_apis,
    module.iam
  ]
}

# -----------------------------------------------------------------------------
# Eureka Server (deployed first so its URI can be injected into dependent services)
# -----------------------------------------------------------------------------

module "eureka_server" {
  source = "../../modules/cloud_run_service"

  project_id            = var.project_id
  location              = var.region
  service_name          = "eureka-server"
  image_uri             = "${module.artifact_registry.repository_full_path}/${var.services["eureka-server"].image_name}:${var.services["eureka-server"].image_tag}"
  service_account_email = module.iam.service_account_emails["eureka-server"]

  port          = var.services["eureka-server"].port
  cpu           = var.services["eureka-server"].cpu
  memory        = var.services["eureka-server"].memory
  min_instances = var.services["eureka-server"].min_instances
  max_instances = var.services["eureka-server"].max_instances
  concurrency   = var.services["eureka-server"].concurrency
  timeout       = var.services["eureka-server"].timeout
  ingress       = var.services["eureka-server"].ingress

  enable_vpc_access  = var.enable_vpc_connector
  vpc_connector_name = var.enable_vpc_connector ? module.networking[0].connector_self_link : null
  vpc_egress_setting = var.vpc_egress_setting

  env_vars        = var.services["eureka-server"].env_vars
  secret_env_vars = var.services["eureka-server"].secret_env_vars

  startup_probe_path              = "/actuator/health/readiness"
  startup_probe_initial_delay     = 0
  startup_probe_timeout           = 3
  startup_probe_period            = 10
  startup_probe_failure_threshold = 6

  liveness_probe_path              = "/actuator/health/liveness"
  liveness_probe_initial_delay     = 0
  liveness_probe_timeout           = 3
  liveness_probe_period            = 10
  liveness_probe_failure_threshold = 3

  session_affinity      = false
  allow_unauthenticated = var.allow_unauthenticated
  invoker_members       = []

  labels = merge(local.common_labels, { service = "eureka-server" })

  depends_on = [
    google_project_service.required_apis,
    module.iam,
    module.artifact_registry,
  ]
}

# -----------------------------------------------------------------------------
# Cloud Run Services
# Deploy each microservice as a Cloud Run service
# -----------------------------------------------------------------------------

module "cloud_run_services" {
  source   = "../../modules/cloud_run_service"
  for_each = local.services_for_each

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

  # VPC connector (for private VPC resource access)
  # Note: enable_vpc_access uses static bool to avoid "block count changed" errors
  # when vpc_connector_name is a computed value from the networking module
  enable_vpc_access  = var.enable_vpc_connector
  vpc_connector_name = var.enable_vpc_connector ? module.networking[0].connector_self_link : null
  vpc_egress_setting = var.vpc_egress_setting

  # Environment variables
  env_vars        = each.value.env_vars
  secret_env_vars = each.value.secret_env_vars

  # Health checks (Spring Boot Actuator endpoints)
  startup_probe_path              = "/actuator/health/readiness"
  startup_probe_initial_delay     = 0
  startup_probe_timeout           = 3
  startup_probe_period            = 10
  startup_probe_failure_threshold = 6

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
    module.artifact_registry,
  ]
}

# -----------------------------------------------------------------------------
# VPC Connector
# -----------------------------------------------------------------------------

# VPC Connector enables Cloud Run to connect to private VPC resources
# Required for: Cloud SQL (private IP), internal services

module "networking" {
  source = "../../modules/networking"
  count  = var.enable_vpc_connector ? 1 : 0

  project_id     = var.project_id
  region         = var.region
  connector_name = var.vpc_connector_name
  network_name   = var.network_name

  # Subnet configuration for VPC connector
  create_connector_subnet = true
  connector_subnet_cidr   = var.vpc_connector_cidr

  # Connector sizing (use e2-micro for dev, e2-standard-4 for prod)
  connector_machine_type  = var.vpc_connector_machine_type
  connector_min_instances = var.vpc_connector_min_instances
  connector_max_instances = var.vpc_connector_max_instances

  depends_on = [
    google_project_service.required_apis
  ]
}

