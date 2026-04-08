variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "region" {
  description = "GCP region for the Cloud Run service."
  type        = string
}

variable "name" {
  description = "Cloud Run service name."
  type        = string
}

variable "image_url" {
  description = "Full container image URL to deploy."
  type        = string
}

variable "max_instances" {
  description = "Maximum number of Cloud Run instances."
  type        = number
}

variable "cpu_limit" {
  description = "CPU limit per container (e.g. '1000m')."
  type        = string
}

variable "memory_limit" {
  description = "Memory limit per container (e.g. '256Mi')."
  type        = string
}
