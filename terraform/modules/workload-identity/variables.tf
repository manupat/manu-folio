variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "name" {
  description = "Base name used for resource naming."
  type        = string
}

variable "region" {
  description = "GCP region (used for Artifact Registry IAM binding)."
  type        = string
}

variable "github_repository_owner" {
  description = "GitHub user or organisation owning the repository."
  type        = string
}

variable "github_repository_name" {
  description = "GitHub repository name."
  type        = string
}

variable "artifact_registry_repository_id" {
  description = "Artifact Registry repository ID to grant write access on."
  type        = string
}
