variable "project_id" {
  description = "Google Cloud project ID."
  type        = string
}

variable "name" {
  description = "Base name used for resource naming."
  type        = string
}

variable "rate_limit_requests_per_minute" {
  description = "Max requests per IP per minute before throttling."
  type        = number
}

variable "blocked_countries" {
  description = "ISO 3166-1 alpha-2 country codes to block. Leave empty to allow all."
  type        = list(string)
}
