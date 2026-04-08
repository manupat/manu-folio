output "static_ip" {
  description = "Global static IP address. Point your DNS A record here."
  value       = google_compute_global_address.this.address
}
