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

  # Optional: uncomment and configure to use a GCS backend
  # backend "gcs" {
  #   bucket = "<YOUR_TF_STATE_BUCKET>"
  #   prefix = "manu-folio/state"
  # }
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
  ]
}

resource "google_project_service" "apis" {
  for_each           = toset(local.required_apis)
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

# ──────────────────────────────────────────────────────────────
# Artifact Registry — store the container image
# ──────────────────────────────────────────────────────────────
resource "google_artifact_registry_repository" "career_website" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.name}-repo"
  description   = "Container images for the career website"
  format        = "DOCKER"

  depends_on = [google_project_service.apis]
}

locals {
  image_url = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.career_website.repository_id}/${var.name}:latest"
}

# ──────────────────────────────────────────────────────────────
# Cloud Run v2 Service
# ──────────────────────────────────────────────────────────────
resource "google_cloud_run_v2_service" "career_website" {
  project  = var.project_id
  name     = var.name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER" # only LB traffic allowed

  template {
    scaling {
      min_instance_count = 0           # scale-to-zero
      max_instance_count = var.max_instances
    }

    timeout = "10s"

    containers {
      image = local.image_url

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
        cpu_idle          = true  # throttle CPU when not processing requests
        startup_cpu_boost = true  # burst CPU on cold start
      }

      liveness_probe {
        http_get {
          path = "/healthz"
          port = 8080
        }
        initial_delay_seconds = 5
        period_seconds        = 30
        failure_threshold     = 3
      }

      startup_probe {
        http_get {
          path = "/healthz"
          port = 8080
        }
        initial_delay_seconds = 1
        period_seconds        = 5
        failure_threshold     = 5
      }
    }
  }

  depends_on = [google_project_service.apis]
}

# Allow unauthenticated invocations (public website)
resource "google_cloud_run_v2_service_iam_member" "allow_unauthenticated" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.career_website.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ──────────────────────────────────────────────────────────────
# Static Global IP Address
# ──────────────────────────────────────────────────────────────
resource "google_compute_global_address" "career_website" {
  project      = var.project_id
  name         = "${var.name}-ip"
  address_type = "EXTERNAL"
  ip_version   = "IPV4"

  depends_on = [google_project_service.apis]
}

# ──────────────────────────────────────────────────────────────
# Cloud Armor Security Policy
# ──────────────────────────────────────────────────────────────
resource "google_compute_security_policy" "career_website" {
  project     = var.project_id
  name        = "${var.name}-armor"
  description = "Cloud Armor WAF policy for the career website"
  type        = "CLOUD_ARMOR"

  # ── Preconfigured WAF rules ───────────────────────────────

  # OWASP Top 10: SQL injection
  rule {
    action   = "deny(403)"
    priority = 1000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable')"
      }
    }
    description = "Block SQL injection attacks"
  }

  # OWASP Top 10: XSS
  rule {
    action   = "deny(403)"
    priority = 1010
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
    description = "Block XSS attacks"
  }

  # OWASP Top 10: Local File Inclusion
  rule {
    action   = "deny(403)"
    priority = 1020
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-stable')"
      }
    }
    description = "Block local file inclusion"
  }

  # OWASP Top 10: Remote Code Execution
  rule {
    action   = "deny(403)"
    priority = 1030
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-stable')"
      }
    }
    description = "Block remote code execution"
  }

  # OWASP Top 10: Scanner detection
  rule {
    action   = "deny(403)"
    priority = 1040
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('scannerdetection-stable')"
      }
    }
    description = "Block automated scanners"
  }

  # Rate limiting per IP — mitigates DDoS / credential stuffing
  rule {
    action   = "throttle"
    priority = 2000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = var.rate_limit_requests_per_minute
        interval_sec = 60
      }
    }
    description = "Rate limit per source IP"
  }

  # ── Geo-blocking (optional — blocked countries list) ─────
  dynamic "rule" {
    for_each = length(var.blocked_countries) > 0 ? [1] : []
    content {
      action   = "deny(403)"
      priority = 900
      match {
        expr {
          expression = "origin.region_code in ['${join("','", var.blocked_countries)}']"
        }
      }
      description = "Block traffic from specified countries"
    }
  }

  # Default: allow everything else
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow rule"
  }

  depends_on = [google_project_service.apis]
}

# ──────────────────────────────────────────────────────────────
# Serverless Network Endpoint Group — connects LB to Cloud Run
# ──────────────────────────────────────────────────────────────
resource "google_compute_region_network_endpoint_group" "career_website" {
  project               = var.project_id
  name                  = "${var.name}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.region

  cloud_run {
    service = google_cloud_run_v2_service.career_website.name
  }

  depends_on = [google_project_service.apis]
}

# ──────────────────────────────────────────────────────────────
# Backend Service (HTTPS LB backend)
# ──────────────────────────────────────────────────────────────
resource "google_compute_backend_service" "career_website" {
  project               = var.project_id
  name                  = "${var.name}-backend"
  protocol              = "HTTPS"
  port_name             = "https"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  timeout_sec           = 30
  security_policy       = google_compute_security_policy.career_website.self_link

  backend {
    group = google_compute_region_network_endpoint_group.career_website.id
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  depends_on = [google_project_service.apis]
}

# ──────────────────────────────────────────────────────────────
# URL Map (HTTPS)
# ──────────────────────────────────────────────────────────────
resource "google_compute_url_map" "career_website_https" {
  project         = var.project_id
  name            = "${var.name}-url-map"
  default_service = google_compute_backend_service.career_website.id
}

# URL Map for HTTP → HTTPS redirect
resource "google_compute_url_map" "career_website_http_redirect" {
  project = var.project_id
  name    = "${var.name}-http-redirect"

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# ──────────────────────────────────────────────────────────────
# SSL Certificate (Google-managed)
# ──────────────────────────────────────────────────────────────
resource "google_compute_managed_ssl_certificate" "career_website" {
  project = var.project_id
  name    = "${var.name}-ssl-cert"

  managed {
    domains = var.domains
  }

  depends_on = [google_project_service.apis]
}

# ──────────────────────────────────────────────────────────────
# Target HTTPS Proxy
# ──────────────────────────────────────────────────────────────
resource "google_compute_target_https_proxy" "career_website" {
  project          = var.project_id
  name             = "${var.name}-https-proxy"
  url_map          = google_compute_url_map.career_website_https.id
  ssl_certificates = [google_compute_managed_ssl_certificate.career_website.id]
}

# Target HTTP Proxy (redirect only)
resource "google_compute_target_http_proxy" "career_website_redirect" {
  project = var.project_id
  name    = "${var.name}-http-proxy"
  url_map = google_compute_url_map.career_website_http_redirect.id
}

# ──────────────────────────────────────────────────────────────
# Global Forwarding Rules
# ──────────────────────────────────────────────────────────────
resource "google_compute_global_forwarding_rule" "career_website_https" {
  project               = var.project_id
  name                  = "${var.name}-https-fwd"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.career_website.id
  ip_address            = google_compute_global_address.career_website.id

  depends_on = [google_project_service.apis]
}

resource "google_compute_global_forwarding_rule" "career_website_http" {
  project               = var.project_id
  name                  = "${var.name}-http-fwd"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.career_website_redirect.id
  ip_address            = google_compute_global_address.career_website.id

  depends_on = [google_project_service.apis]
}
