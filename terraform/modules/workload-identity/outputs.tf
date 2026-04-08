output "workload_identity_provider" {
  description = "Full WIF provider resource name. Set as GCP_WORKLOAD_IDENTITY_PROVIDER GitHub Actions secret."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "service_account_email" {
  description = "Deploy service account email. Set as GCP_SERVICE_ACCOUNT GitHub Actions secret."
  value       = google_service_account.github_deploy.email
}
