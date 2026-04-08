# ════════════════════════════════════════════════════════════════
# outputs.tf
# ════════════════════════════════════════════════════════════════

output "static_ip_address" {
  description = "Global static IP address. Point your DNS A record to this value."
  value       = module.load_balancer.static_ip
}

output "cloud_run_url" {
  description = "Direct Cloud Run service URL (only reachable via the Load Balancer due to INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER)."
  value       = module.cloud_run.service_url
}

output "artifact_registry_repo" {
  description = "Full Artifact Registry repository path for pushing Docker images."
  value       = google_artifact_registry_repository.this.name
}

output "image_url" {
  description = "Full container image URL to use when building and pushing."
  value       = local.image_url
}

output "cloud_armor_policy" {
  description = "Cloud Armor security policy name."
  value       = module.cloud_armor.name
}

output "load_balancer_https_url" {
  description = "HTTPS URL once your domain DNS is configured and SSL cert is provisioned."
  value       = "https://${var.domains[0]}"
}

output "workload_identity_provider" {
  description = "Full WIF provider resource name. Set as the GCP_WORKLOAD_IDENTITY_PROVIDER GitHub Actions secret."
  value       = module.workload_identity.workload_identity_provider
}

output "github_deploy_service_account" {
  description = "Deploy service account email. Set as the GCP_SERVICE_ACCOUNT GitHub Actions secret."
  value       = module.workload_identity.service_account_email
}
