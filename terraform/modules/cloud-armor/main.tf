resource "google_compute_security_policy" "this" {
  project     = var.project_id
  name        = "${var.name}-armor"
  description = "Cloud Armor WAF policy for ${var.name}"
  type        = "CLOUD_ARMOR"

  # OWASP Top 10: SQL injection
  rule {
    action      = "deny(403)"
    priority    = 1000
    description = "Block SQL injection attacks"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable')"
      }
    }
  }

  # OWASP Top 10: XSS
  rule {
    action      = "deny(403)"
    priority    = 1010
    description = "Block XSS attacks"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
  }

  # OWASP Top 10: Local File Inclusion
  rule {
    action      = "deny(403)"
    priority    = 1020
    description = "Block local file inclusion"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('lfi-stable')"
      }
    }
  }

  # OWASP Top 10: Remote Code Execution
  rule {
    action      = "deny(403)"
    priority    = 1030
    description = "Block remote code execution"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('rce-stable')"
      }
    }
  }

  # OWASP Top 10: Scanner detection
  rule {
    action      = "deny(403)"
    priority    = 1040
    description = "Block automated scanners"
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('scannerdetection-stable')"
      }
    }
  }

  # Rate limiting per IP
  rule {
    action      = "throttle"
    priority    = 2000
    description = "Rate limit per source IP"
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
  }

  # Geo-blocking (optional)
  dynamic "rule" {
    for_each = length(var.blocked_countries) > 0 ? [1] : []
    content {
      action      = "deny(403)"
      priority    = 900
      description = "Block traffic from specified countries"
      match {
        expr {
          expression = "origin.region_code in ['${join("','", var.blocked_countries)}']"
        }
      }
    }
  }

  # Default allow
  rule {
    action      = "allow"
    priority    = 2147483647
    description = "Default allow rule"
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
  }
}
