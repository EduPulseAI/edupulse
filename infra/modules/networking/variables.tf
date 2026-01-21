# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for networking resources"
  type        = string
}

variable "connector_name" {
  description = "Name of the Serverless VPC Access Connector"
  type        = string

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,23})?$", var.connector_name))
    error_message = "Connector name must be lowercase letters, numbers, and hyphens, starting with a letter, max 25 chars."
  }
}

# -----------------------------------------------------------------------------
# VPC Configuration
# -----------------------------------------------------------------------------

variable "network_name" {
  description = "Name of the VPC network (existing or to be created)"
  type        = string
  default     = "default"
}

variable "create_vpc" {
  description = "Whether to create a new VPC (false = use existing)"
  type        = bool
  default     = false
}

variable "auto_create_subnetworks" {
  description = "Auto-create subnetworks in new VPC (only if create_vpc=true)"
  type        = bool
  default     = true
}

# -----------------------------------------------------------------------------
# VPC Connector Configuration
# -----------------------------------------------------------------------------

variable "create_connector_subnet" {
  description = "Create a dedicated subnet for the VPC connector (recommended for production)"
  type        = bool
  default     = true
}

variable "connector_subnet_cidr" {
  description = "CIDR range for connector subnet (if create_connector_subnet=true)"
  type        = string
  default     = "10.8.0.0/28"

  validation {
    condition     = can(cidrhost(var.connector_subnet_cidr, 0))
    error_message = "Must be a valid CIDR range."
  }
}

variable "connector_ip_cidr_range" {
  description = "IP CIDR range for connector (if not using subnet-based config)"
  type        = string
  default     = "10.8.0.0/28"
}

variable "connector_machine_type" {
  description = "Machine type for VPC connector instances"
  type        = string
  default     = "e2-micro"

  validation {
    condition     = contains(["f1-micro", "e2-micro", "e2-standard-4"], var.connector_machine_type)
    error_message = "Machine type must be one of: f1-micro, e2-micro, e2-standard-4."
  }
}

variable "connector_min_instances" {
  description = "Minimum number of connector instances"
  type        = number
  default     = 2

  validation {
    condition     = var.connector_min_instances >= 2 && var.connector_min_instances <= 10
    error_message = "Minimum instances must be between 2 and 10."
  }
}

variable "connector_max_instances" {
  description = "Maximum number of connector instances"
  type        = number
  default     = 10

  validation {
    condition     = var.connector_max_instances >= 3 && var.connector_max_instances <= 10
    error_message = "Maximum instances must be between 3 and 10."
  }
}

variable "connector_min_throughput" {
  description = "Minimum throughput in Mbps (200-1000)"
  type        = number
  default     = 200

  validation {
    condition     = var.connector_min_throughput >= 200 && var.connector_min_throughput <= 1000
    error_message = "Min throughput must be between 200 and 1000 Mbps."
  }
}

variable "connector_max_throughput" {
  description = "Maximum throughput in Mbps (200-1000)"
  type        = number
  default     = 1000

  validation {
    condition     = var.connector_max_throughput >= 200 && var.connector_max_throughput <= 1000
    error_message = "Max throughput must be between 200 and 1000 Mbps."
  }
}
