# -----------------------------------------------------------------------------
# Required Variables
# -----------------------------------------------------------------------------

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for Redis instance"
  type        = string
}

variable "instance_name" {
  description = "Name of the Redis instance"
  type        = string

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,38}[a-z0-9])?$", var.instance_name))
    error_message = "Instance name must be lowercase letters, numbers, and hyphens, starting with a letter, max 40 chars."
  }
}

variable "network_name" {
  description = "Name of the VPC network to connect Redis to"
  type        = string
  default     = "default"
}

# -----------------------------------------------------------------------------
# Instance Configuration
# -----------------------------------------------------------------------------

variable "tier" {
  description = "Service tier: BASIC (no HA) or STANDARD_HA (high availability with replica)"
  type        = string
  default     = "BASIC"

  validation {
    condition     = contains(["BASIC", "STANDARD_HA"], var.tier)
    error_message = "Tier must be either BASIC or STANDARD_HA."
  }
}

variable "memory_size_gb" {
  description = "Redis memory size in GB (1-300)"
  type        = number
  default     = 1

  validation {
    condition     = var.memory_size_gb >= 1 && var.memory_size_gb <= 300
    error_message = "Memory size must be between 1 and 300 GB."
  }
}

variable "redis_version" {
  description = "Redis version to use"
  type        = string
  default     = "REDIS_7_0"

  validation {
    condition     = contains(["REDIS_7_0", "REDIS_6_X", "REDIS_5_0", "REDIS_4_0"], var.redis_version)
    error_message = "Redis version must be one of: REDIS_7_0, REDIS_6_X, REDIS_5_0, REDIS_4_0."
  }
}

variable "display_name" {
  description = "Display name for the Redis instance"
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Network Configuration
# -----------------------------------------------------------------------------

variable "create_private_service_connection" {
  description = "Whether to create private service connection (set to false if already exists)"
  type        = bool
  default     = true
}

variable "ip_range_prefix_length" {
  description = "Prefix length for the private IP range (e.g., 16 = /16 CIDR)"
  type        = number
  default     = 16
}

# -----------------------------------------------------------------------------
# Redis Configuration
# -----------------------------------------------------------------------------

variable "maxmemory_policy" {
  description = "Redis maxmemory eviction policy"
  type        = string
  default     = "volatile-lru"

  validation {
    condition = contains([
      "volatile-lru", "allkeys-lru", "volatile-lfu", "allkeys-lfu",
      "volatile-random", "allkeys-random", "volatile-ttl", "noeviction"
    ], var.maxmemory_policy)
    error_message = "Invalid maxmemory policy."
  }
}

variable "redis_configs" {
  description = "Additional Redis configuration parameters"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

variable "auth_enabled" {
  description = "Enable Redis AUTH for password protection"
  type        = bool
  default     = true
}

variable "transit_encryption_mode" {
  description = "Transit encryption mode: DISABLED or SERVER_AUTHENTICATION"
  type        = string
  default     = "SERVER_AUTHENTICATION"

  validation {
    condition     = contains(["DISABLED", "SERVER_AUTHENTICATION"], var.transit_encryption_mode)
    error_message = "Transit encryption mode must be DISABLED or SERVER_AUTHENTICATION."
  }
}

# -----------------------------------------------------------------------------
# Maintenance Window
# -----------------------------------------------------------------------------

variable "maintenance_window_day" {
  description = "Day of week for maintenance window (MONDAY, TUESDAY, etc.). Set to null to disable."
  type        = string
  default     = null
}

variable "maintenance_window_hour" {
  description = "Hour of day (0-23) for maintenance window start time (UTC)"
  type        = number
  default     = 2
}

# -----------------------------------------------------------------------------
# Labels
# -----------------------------------------------------------------------------

variable "labels" {
  description = "Labels to apply to the Redis instance"
  type        = map(string)
  default     = {}
}
