# -----------------------------------------------------------------------------
# Redis Memorystore Outputs
# -----------------------------------------------------------------------------

output "instance_id" {
  description = "The ID of the Redis instance"
  value       = google_redis_instance.redis.id
}

output "instance_name" {
  description = "The name of the Redis instance"
  value       = google_redis_instance.redis.name
}

output "host" {
  description = "The IP address of the Redis instance (for connection)"
  value       = google_redis_instance.redis.host
}

output "port" {
  description = "The port of the Redis instance"
  value       = google_redis_instance.redis.port
}

output "current_location_id" {
  description = "The current zone where the Redis instance is located"
  value       = google_redis_instance.redis.current_location_id
}

output "auth_string" {
  description = "The AUTH string for Redis (only if auth_enabled=true)"
  value       = google_redis_instance.redis.auth_string
  sensitive   = true
}

output "connection_string" {
  description = "Redis connection string in format host:port"
  value       = "${google_redis_instance.redis.host}:${google_redis_instance.redis.port}"
}

output "redis_version" {
  description = "The version of Redis software"
  value       = google_redis_instance.redis.redis_version
}

output "memory_size_gb" {
  description = "Memory size in GB"
  value       = google_redis_instance.redis.memory_size_gb
}

output "tier" {
  description = "Service tier (BASIC or STANDARD_HA)"
  value       = google_redis_instance.redis.tier
}

output "network" {
  description = "The VPC network the instance is connected to"
  value       = google_redis_instance.redis.authorized_network
}

# Output for use in Secret Manager or environment variables
output "spring_redis_host" {
  description = "Redis host formatted for Spring Boot configuration"
  value       = google_redis_instance.redis.host
}

output "spring_redis_port" {
  description = "Redis port formatted for Spring Boot configuration"
  value       = tostring(google_redis_instance.redis.port)
}
