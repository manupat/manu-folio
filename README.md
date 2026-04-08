# Kaushikmanu Patel — Career Website

Interactive single-page career website, deployed on **Google Cloud Run** behind a **Global External HTTPS Load Balancer** protected by **Cloud Armor**.

## Architecture

```
Internet
   │
   ▼
Global External HTTPS LB  ◄─── Cloud Armor WAF (OWASP rules + rate-limiting)
   │ (port 443 / TLS)
   │   HTTP → HTTPS redirect (port 80)
   ▼
Serverless NEG
   │
   ▼
Cloud Run v2 Service  (min_instances = 0, scale-to-zero)
   │  nginx:alpine container
   └─ /healthz  (liveness + startup probes)
```

Key properties:
- **Scale-to-zero** (`min_instance_count = 0`) — no idle costs
- **Internal ingress only** — Cloud Run rejects direct traffic; only the LB can call it
- **Google-managed SSL** certificate — auto-renewed
- **HTTP → HTTPS** redirect
- **Cloud Armor** — OWASP Top 10 pre-configured WAF rules + per-IP rate limiting + optional geo-blocking

---

## Project Structure

```
manu-folio/
├── app/
│   ├── Dockerfile       # nginx:alpine, port 8080, runs as non-root
│   ├── nginx.conf       # security headers, health check, SPA fallback
│   ├── index.html       # Single-page career website
│   ├── style.css        # Dark-theme, responsive, animated
│   └── script.js        # Particles, typed effect, scroll animations
└── terraform/
    ├── main.tf                   # All GCP resources
    ├── variables.tf              # Input variables
    ├── outputs.tf                # Useful outputs (IP, image URL, etc.)
    └── terraform.tfvars.example  # Copy → terraform.tfvars
```

---

## Prerequisites

| Tool | Version |
|------|---------|
| Terraform | >= 1.5 |
| Google Cloud SDK (`gcloud`) | latest |
| Docker | latest |

---

## Step-by-Step Deployment

### 1 — Authenticate with GCP

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### 2 — Configure Terraform variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your project_id and domain(s)
```

### 3 — Deploy infrastructure

```bash
terraform init
terraform plan
terraform apply
```

Note the output values — especially `static_ip_address` and `image_url`.

### 4 — Point DNS to the static IP

Create an **A record** in your DNS provider:
```
kaushikmanu.dev  →  <static_ip_address from terraform output>
```

> SSL certificate provisioning starts automatically but requires the DNS record to propagate first (may take 10–60 minutes).

### 5 — Build and push the container image

```bash
# Configure Docker to use Artifact Registry
gcloud auth configure-docker europe-west1-docker.pkg.dev

# Build and push
IMAGE_URL=$(cd terraform && terraform output -raw image_url)

docker build -t "$IMAGE_URL" ./app
docker push "$IMAGE_URL"
```

### 6 — Deploy updated Cloud Run revision

```bash
gcloud run services update manu-folio \
  --image "$IMAGE_URL" \
  --region europe-west1
```

Or you can re-run `terraform apply` after building/pushing the image.

---

## Updating the Website

1. Edit files in `app/` (HTML, CSS, JS).
2. Rebuild and push the Docker image (step 5).
3. Cloud Run automatically creates a new revision and routes traffic to it.

---

## Cloud Armor Rules Summary

| Priority | Rule | Action |
|----------|------|--------|
| 900 | Geo-blocking (optional) | deny(403) |
| 1000 | SQLi (OWASP) | deny(403) |
| 1010 | XSS (OWASP) | deny(403) |
| 1020 | LFI (OWASP) | deny(403) |
| 1030 | RCE (OWASP) | deny(403) |
| 1040 | Scanner detection | deny(403) |
| 2000 | Rate limit per IP | throttle → deny(429) |
| 2147483647 | Default | allow |

---

## CI/CD (GitHub Actions)

Two workflow files live in [`.github/workflows/`](.github/workflows/):

| File | Trigger | What it does |
|------|---------|-------------|
| [`ci.yml`](.github/workflows/ci.yml) | Every PR → `main` | Hadolint · Terraform fmt/validate · Docker build smoke-test |
| [`deploy.yml`](.github/workflows/deploy.yml) | Push to `main` (merge) | Build & push image to Artifact Registry → Deploy to Cloud Run |

Authentication uses **Workload Identity Federation** — no long-lived service-account key files stored in GitHub.

### Required GitHub Actions secrets

| Secret | Value |
|--------|-------|
| `GCP_PROJECT_ID` | Your GCP project ID |
| `GCP_REGION` | e.g. `europe-west1` |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | Full WIF provider resource name (`projects/<NUM>/locations/global/workloadIdentityPools/<POOL>/providers/<PROVIDER>`) |
| `GCP_SERVICE_ACCOUNT` | Service account email the WIF pool can impersonate (e.g. `github-deploy@<project>.iam.gserviceaccount.com`) |

### Minimum IAM roles for the deploy service account

```
roles/run.developer          # update Cloud Run services
roles/artifactregistry.writer  # push images
roles/iam.serviceAccountUser   # act as the SA itself
```

---

## Tear Down

```bash
cd terraform
terraform destroy
```

> This removes **all** created resources including the static IP, Cloud Run service, and Artifact Registry repository.
