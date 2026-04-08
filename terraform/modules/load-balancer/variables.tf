variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "name" {
  description = "Base name used for resource naming."
  type        = string
}

variable "region" {
  description = "GCP region (used for the Serverless NEG)."
  type        = string
}

variable "cloud_run_service_name" {
  description = "Name of the Cloud Run service to route traffic to."
  type        = string
}

variable "security_policy_self_link" {
  description = "Self-link of the Cloud Armor security policy."
  type        = string
}

variable "domains" {
  description = "Domain names for the Google-managed SSL certificate."
  type        = list(string)
}
