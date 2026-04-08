# Service Account impersonated by GitHub Actions during CI/CD
resource "google_service_account" "github_deploy" {
  project      = var.project_id
  account_id   = "${var.name}-github-deploy"
  display_name = "GitHub Actions deploy SA for ${var.name}"
  description  = "Impersonated by GitHub Actions via Workload Identity Federation."
}

# Workload Identity Pool
resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "${var.name}-github-pool"
  display_name              = "GitHub Actions pool"
  description               = "Allows GitHub Actions to authenticate as ${google_service_account.github_deploy.email}."
}

# OIDC provider — scoped to the specific repository
resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "${var.name}-github-provider"
  display_name                       = "GitHub OIDC provider"
  description                        = "OIDC for ${var.github_repository_owner}/${var.github_repository_name}"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
  }

  # Restrict to this specific repository only
  attribute_condition = "assertion.repository == '${var.github_repository_owner}/${var.github_repository_name}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# Bind WIF principal set → impersonate SA
resource "google_service_account_iam_member" "wif_impersonation" {
  service_account_id = google_service_account.github_deploy.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository_owner}/${var.github_repository_name}"
}

# Push images to Artifact Registry
resource "google_artifact_registry_repository_iam_member" "ar_writer" {
  project    = var.project_id
  location   = var.region
  repository = var.artifact_registry_repository_id
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.github_deploy.email}"
}

# Deploy to Cloud Run
resource "google_project_iam_member" "run_developer" {
  project = var.project_id
  role    = "roles/run.developer"
  member  = "serviceAccount:${google_service_account.github_deploy.email}"
}

# Act as Cloud Run service account during deployment
resource "google_project_iam_member" "sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.github_deploy.email}"
}
