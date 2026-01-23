# -----------------------------------------------------------------------------
# Redis Memorystore Module
# Creates a managed Redis instance for caching and session storage
# -----------------------------------------------------------------------------

# Enable required APIs
resource "google_project_service" "redis_api" {
  project = var.project_id
  service = "redis.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "servicenetworking_api" {
  project = var.project_id
  service = "servicenetworking.googleapis.com"

  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# VPC Network Configuration for Private Service Access
# Redis Memorystore requires private connectivity via VPC
# -----------------------------------------------------------------------------

# Get existing VPC network
data "google_compute_network" "vpc" {
  name    = var.network_name
  project = var.project_id
}

# Reserve an IP range for private service access (if not already exists)
resource "google_compute_global_address" "private_ip_range" {
  count = var.create_private_service_connection ? 1 : 0

  project       = var.project_id
  name          = "${var.instance_name}-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = var.ip_range_prefix_length
  network       = data.google_compute_network.vpc.id

  depends_on = [
    google_project_service.servicenetworking_api
  ]
}

# Create private service connection to Google services
resource "google_service_networking_connection" "private_vpc_connection" {
  count = var.create_private_service_connection ? 1 : 0

  network                 = data.google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range[0].name]

  # Prevent recreation when peering ranges change - the connection is a singleton
  lifecycle {
    ignore_changes = [reserved_peering_ranges]
  }

  depends_on = [
    google_project_service.servicenetworking_api,
    google_compute_global_address.private_ip_range
  ]
}

# -----------------------------------------------------------------------------
# Redis Memorystore Instance
# -----------------------------------------------------------------------------

resource "google_redis_instance" "redis" {
  project = var.project_id
  region  = var.region
  name    = var.instance_name

  # Instance tier: BASIC (no replication) or STANDARD_HA (high availability)
  tier = var.tier

  # Memory size in GB
  memory_size_gb = var.memory_size_gb

  # Redis version
  redis_version = var.redis_version

  # Display name
  display_name = var.display_name != "" ? var.display_name : "Redis for ${var.instance_name}"

  # Network configuration - connect to VPC for private access
  authorized_network = data.google_compute_network.vpc.id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"

  # Redis configuration parameters
  redis_configs = merge(
    {
      maxmemory-policy = var.maxmemory_policy
    },
    var.redis_configs
  )

  # Maintenance window
  dynamic "maintenance_policy" {
    for_each = var.maintenance_window_day != null ? [1] : []
    content {
      weekly_maintenance_window {
        day = var.maintenance_window_day
        start_time {
          hours   = var.maintenance_window_hour
          minutes = 0
          seconds = 0
          nanos   = 0
        }
      }
    }
  }

  # Auth enabled (password protection)
  auth_enabled = var.auth_enabled

  # TLS/Transit encryption
  transit_encryption_mode = var.transit_encryption_mode

  # Labels
  labels = var.labels

  # Lifecycle - prevent unnecessary recreation
  lifecycle {
    prevent_destroy = false
  }

  depends_on = [
    google_project_service.redis_api,
    google_service_networking_connection.private_vpc_connection
  ]
}
