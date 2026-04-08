output "self_link" {
  description = "Self-link of the Cloud Armor security policy."
  value       = google_compute_security_policy.this.self_link
}

output "name" {
  description = "Name of the Cloud Armor security policy."
  value       = google_compute_security_policy.this.name
}
