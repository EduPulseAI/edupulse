output "repository_id" {
  description = "The ID of the Artifact Registry repository"
  value       = google_artifact_registry_repository.main.repository_id
}

output "repository_name" {
  description = "The full resource name of the repository (projects/{project}/locations/{location}/repositories/{repository_id})"
  value       = google_artifact_registry_repository.main.name
}

output "location" {
  description = "The location where the repository is created"
  value       = google_artifact_registry_repository.main.location
}

output "repository_url" {
  description = "The base URL for the Artifact Registry repository (for docker tag/push)"
  value       = "${google_artifact_registry_repository.main.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"
}

output "docker_hostname" {
  description = "The Docker registry hostname for this repository location"
  value       = "${google_artifact_registry_repository.main.location}-docker.pkg.dev"
}

output "repository_full_path" {
  description = "Full path for docker images: {location}-docker.pkg.dev/{project}/{repository}"
  value       = "${google_artifact_registry_repository.main.location}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.main.repository_id}"
}

output "format" {
  description = "The format of the repository (DOCKER)"
  value       = google_artifact_registry_repository.main.format
}
