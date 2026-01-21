# -----------------------------------------------------------------------------
# Networking Module Outputs
# -----------------------------------------------------------------------------

locals {
  # Select the appropriate connector based on configuration
  connector = var.create_connector_subnet ? google_vpc_access_connector.connector[0] : google_vpc_access_connector.connector_ip_range[0]
}

output "vpc_network_id" {
  description = "The ID of the VPC network"
  value       = local.vpc_network.id
}

output "vpc_network_name" {
  description = "The name of the VPC network"
  value       = local.vpc_network.name
}

output "vpc_network_self_link" {
  description = "The self-link of the VPC network"
  value       = local.vpc_network.self_link
}

output "connector_id" {
  description = "The ID of the Serverless VPC Access Connector"
  value       = local.connector.id
}

output "connector_name" {
  description = "The name of the Serverless VPC Access Connector"
  value       = local.connector.name
}

output "connector_self_link" {
  description = "The fully qualified name of the VPC connector (for Cloud Run)"
  value       = local.connector.id
}

output "connector_state" {
  description = "The state of the VPC connector"
  value       = local.connector.state
}

output "connector_subnet_name" {
  description = "The name of the connector subnet (if created)"
  value       = var.create_connector_subnet ? google_compute_subnetwork.connector_subnet[0].name : null
}

output "connector_subnet_cidr" {
  description = "The CIDR range of the connector subnet"
  value       = var.create_connector_subnet ? google_compute_subnetwork.connector_subnet[0].ip_cidr_range : var.connector_ip_cidr_range
}
