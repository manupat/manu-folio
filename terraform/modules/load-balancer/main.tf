# Static global IP
resource "google_compute_global_address" "this" {
  project      = var.project_id
  name         = "${var.name}-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"
}

# Serverless NEG — connects the LB to Cloud Run
resource "google_compute_region_network_endpoint_group" "this" {
  project               = var.project_id
  name                  = "${var.name}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = var.cloud_run_service_name
  }
}

# Backend service
resource "google_compute_backend_service" "this" {
  project               = var.project_id
  name                  = "${var.name}-backend"
  protocol              = "HTTPS"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30
  security_policy       = var.security_policy_self_link

  backend {
    group = google_compute_region_network_endpoint_group.this.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL map — HTTPS
resource "google_compute_url_map" "https" {
  project         = var.project_id
  name            = "${var.name}-url-map"
  default_service = google_compute_backend_service.this.id
}

# URL map — HTTP → HTTPS redirect
resource "google_compute_url_map" "http_redirect" {
  project = var.project_id
  name    = "${var.name}-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# Google-managed SSL certificate — only created when domains are provided
resource "google_compute_managed_ssl_certificate" "this" {
  count   = length(var.domains) > 0 ? 1 : 0
  project = var.project_id
  name    = "${var.name}-ssl-cert"

  managed {
    domains = var.domains
  }
}

# Target HTTPS proxy — only created when domains are provided
resource "google_compute_target_https_proxy" "this" {
  count            = length(var.domains) > 0 ? 1 : 0
  project          = var.project_id
  name             = "${var.name}-https-proxy"
  url_map          = google_compute_url_map.https.id
  ssl_certificates = [google_compute_managed_ssl_certificate.this[0].id]
}

# Target HTTP proxy (redirect only)
resource "google_compute_target_http_proxy" "redirect" {
  project = var.project_id
  name    = "${var.name}-http-proxy"
  url_map = google_compute_url_map.http_redirect.id
}

# Forwarding rule — HTTPS (443) — only created when domains are provided
resource "google_compute_global_forwarding_rule" "https" {
  count                 = length(var.domains) > 0 ? 1 : 0
  project               = var.project_id
  name                  = "${var.name}-https-fwd"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.this[0].id
  ip_address            = google_compute_global_address.this.id
}

# Forwarding rule — HTTP (80) redirect
resource "google_compute_global_forwarding_rule" "http" {
  project               = var.project_id
  name                  = "${var.name}-http-fwd"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.redirect.id
  ip_address            = google_compute_global_address.this.id
}
