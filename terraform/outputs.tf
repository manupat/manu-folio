# ════════════════════════════════════════════════════════════════
# outputs.tf
# ════════════════════════════════════════════════════════════════

output "static_ip_address" {
  description = "Global static IP address. Point your DNS A record to this value."
  value       = google_compute_global_address.career_website.address
}

output "cloud_run_url" {
  description = "Direct Cloud Run service URL (only reachable via the Load Balancer due to INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER)."
  value       = google_cloud_run_v2_service.career_website.uri
}

output "artifact_registry_repo" {
  description = "Full Artifact Registry repository path for pushing Docker images."
  value       = google_artifact_registry_repository.career_website.name
}

output "image_url" {
  description = "Full container image URL to use when building and pushing."
  value       = local.image_url
}

output "cloud_armor_policy" {
  description = "Cloud Armor security policy name."
  value       = google_compute_security_policy.career_website.name
}

output "load_balancer_https_url" {
  description = "HTTPS URL once your domain DNS is configured and SSL cert is provisioned."
  value       = "https://${var.domains[0]}"
}
