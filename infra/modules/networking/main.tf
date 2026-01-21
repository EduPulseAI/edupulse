# -----------------------------------------------------------------------------
# Networking Module
# Manages VPC, Serverless VPC Connector, and related networking resources
# for Cloud Run private access to Redis, Cloud SQL, etc.
# -----------------------------------------------------------------------------

# Enable required APIs
resource "google_project_service" "vpcaccess_api" {
  project = var.project_id
  service = "vpcaccess.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "compute_api" {
  project = var.project_id
  service = "compute.googleapis.com"

  disable_on_destroy = false
}

# -----------------------------------------------------------------------------
# VPC Network (optional - use existing or create new)
# -----------------------------------------------------------------------------

# Use existing default VPC or a specified VPC
data "google_compute_network" "vpc" {
  count   = var.create_vpc ? 0 : 1
  name    = var.network_name
  project = var.project_id
}

# Create new VPC if specified
resource "google_compute_network" "vpc" {
  count = var.create_vpc ? 1 : 0

  project                 = var.project_id
  name                    = var.network_name
  auto_create_subnetworks = var.auto_create_subnetworks
  routing_mode            = "REGIONAL"

  depends_on = [
    google_project_service.compute_api
  ]
}

locals {
  vpc_network = var.create_vpc ? google_compute_network.vpc[0] : data.google_compute_network.vpc[0]
}

# -----------------------------------------------------------------------------
# Subnet for VPC Connector (required for Serverless VPC Access)
# -----------------------------------------------------------------------------

resource "google_compute_subnetwork" "connector_subnet" {
  count = var.create_connector_subnet ? 1 : 0

  project       = var.project_id
  name          = "${var.connector_name}-subnet"
  region        = var.region
  network       = local.vpc_network.id
  ip_cidr_range = var.connector_subnet_cidr

  private_ip_google_access = true

  depends_on = [
    google_project_service.compute_api
  ]
}

# -----------------------------------------------------------------------------
# Serverless VPC Access Connector
# Enables Cloud Run to connect to VPC resources (Redis, Cloud SQL, etc.)
# -----------------------------------------------------------------------------

# Option 1: Subnet-based connector (recommended for production)
resource "google_vpc_access_connector" "connector" {
  count = var.create_connector_subnet ? 1 : 0

  project = var.project_id
  name    = var.connector_name
  region  = var.region

  subnet {
    name       = google_compute_subnetwork.connector_subnet[0].name
    project_id = var.project_id
  }

  # Connector sizing
  machine_type  = var.connector_machine_type
  min_instances = var.connector_min_instances
  max_instances = var.connector_max_instances

  # Throughput limits
  min_throughput = var.connector_min_throughput
  max_throughput = var.connector_max_throughput

  depends_on = [
    google_project_service.vpcaccess_api,
    google_compute_subnetwork.connector_subnet
  ]
}

# Option 2: IP range-based connector (simpler setup, uses default VPC)
resource "google_vpc_access_connector" "connector_ip_range" {
  count = var.create_connector_subnet ? 0 : 1

  project = var.project_id
  name    = var.connector_name
  region  = var.region

  # Network and IP range for non-subnet configuration
  network       = local.vpc_network.name
  ip_cidr_range = var.connector_ip_cidr_range

  # Connector sizing
  machine_type  = var.connector_machine_type
  min_instances = var.connector_min_instances
  max_instances = var.connector_max_instances

  # Throughput limits
  min_throughput = var.connector_min_throughput
  max_throughput = var.connector_max_throughput

  depends_on = [
    google_project_service.vpcaccess_api
  ]
}
