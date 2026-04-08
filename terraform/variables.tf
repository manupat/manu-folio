# ════════════════════════════════════════════════════════════════
# variables.tf
# ════════════════════════════════════════════════════════════════

variable "project_id" {
  description = "Google Cloud project ID where all resources will be created."
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud Run service and Artifact Registry."
  type        = string
  default     = "europe-west1"
}

variable "name" {
  description = "Base name used for all resources (Cloud Run service, LB, etc.)."
  type        = string
  default     = "manu-folio"
}

variable "domains" {
  description = "List of domain names for the Google-managed SSL certificate. DNS A record must point to the static IP before the cert can be provisioned."
  type        = list(string)
  # Example: ["kaushikmanu.dev", "www.kaushikmanu.dev"]
}

variable "max_instances" {
  description = "Maximum number of Cloud Run instances."
  type        = number
  default     = 10
}

variable "cpu_limit" {
  description = "CPU limit per Cloud Run container (e.g. '1000m' = 1 vCPU)."
  type        = string
  default     = "1000m"
}

variable "memory_limit" {
  description = "Memory limit per Cloud Run container."
  type        = string
  default     = "256Mi"
}

variable "rate_limit_requests_per_minute" {
  description = "Maximum requests per IP per minute before Cloud Armor throttles."
  type        = number
  default     = 300
}

variable "blocked_countries" {
  description = "ISO 3166-1 alpha-2 country codes to block via Cloud Armor geo-filtering. Leave empty to allow all countries."
  type        = list(string)
  default     = []
}
