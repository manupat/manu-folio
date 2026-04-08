# ════════════════════════════════════════════════════════════════
# main.tf  —  Career Website on Google Cloud Run + LB + Cloud Armor
# ════════════════════════════════════════════════════════════════
#
# Architecture:
#   Internet → Global External HTTPS LB (with Cloud Armor WAF)
#            → Serverless NEG (Cloud Run)
#            → Cloud Run Service (min_instance_count = 0)
#
# NOTE: HTTP (port 80) traffic is redirected to HTTPS.

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Remote state in GCS — bucket must be created before first `terraform init`.
  # Create it once with:
  #   gcloud storage buckets create gs://manu-folio-tfstate\
  #     --project=<PROJECT_ID> --location=europe-west1 \
  #     --uniform-bucket-level-access
  #
  # Then replace <PROJECT_ID> below and run `terraform init` to migrate state.
  backend "gcs" {
    bucket = "manu-folio-tfstate"
    prefix = "manu-folio/state"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# ──────────────────────────────────────────────────────────────
# Enable required APIs
# ──────────────────────────────────────────────────────────────
locals {
  required_apis = [
    "run.googleapis.com",
    "compute.googleapis.com",
    "artifactregistry.googleapis.com",
    "certificatemanager.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
  ]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.required_apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ──────────────────────────────────────────────────────────────
# Artifact Registry — foundational, stays in root
# ──────────────────────────────────────────────────────────────
resource "google_artifact_registry_repository" "this" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.name}-repo"
  description   = "Container images for ${var.name}"
  format        = "DOCKER"

  depends_on = [google_project_service.apis]
}

locals {
  # On first apply the real image doesn't exist yet (CI hasn't run).
  # Use a public placeholder so Cloud Run can be created; CI will deploy the real image.
  image_url = "us-docker.pkg.dev/cloudrun/container/hello:latest"
}

# ──────────────────────────────────────────────────────────────
# Modules
# ──────────────────────────────────────────────────────────────
module "cloud_armor" {
  source = "./modules/cloud-armor"

  project_id                     = var.project_id
  name                           = var.name
  rate_limit_requests_per_minute = var.rate_limit_requests_per_minute
  blocked_countries              = var.blocked_countries

  depends_on = [google_project_service.apis]
}

module "cloud_run" {
  source = "./modules/cloud-run"

  project_id    = var.project_id
  region        = var.region
  name          = var.name
  image_url     = local.image_url
  max_instances = var.max_instances
  cpu_limit     = var.cpu_limit
  memory_limit  = var.memory_limit

  depends_on = [google_project_service.apis]
}

module "load_balancer" {
  source = "./modules/load-balancer"

  project_id                = var.project_id
  name                      = var.name
  region                    = var.region
  cloud_run_service_name    = module.cloud_run.service_name
  security_policy_self_link = module.cloud_armor.self_link
  domains                   = var.domains

  depends_on = [google_project_service.apis]
}

module "workload_identity" {
  source = "./modules/workload-identity"

  project_id                      = var.project_id
  name                            = var.name
  region                          = var.region
  github_repository_owner         = var.github_repository_owner
  github_repository_name          = var.github_repository_name
  artifact_registry_repository_id = google_artifact_registry_repository.this.repository_id

  depends_on = [google_project_service.apis]
}
