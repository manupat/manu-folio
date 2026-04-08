resource "google_cloud_run_v2_service" "this" {
  project  = var.project_id
  name     = var.name
  location = var.region
  ingress  = "INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER"

  template {
    scaling {
      min_instance_count = 0
      max_instance_count = var.max_instances
    }

    timeout = "10s"

    containers {
      image = var.image_url

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          cpu    = var.cpu_limit
          memory = var.memory_limit
        }
        cpu_idle          = true
        startup_cpu_boost = true
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
}

resource "google_cloud_run_v2_service_iam_member" "allow_unauthenticated" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.this.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
