# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ATP Quality Platform is an **ephemeral quality testing platform**. A single push to `master` provisions a real Kubernetes cluster on DigitalOcean, deploys a microservices demo app (Google Online Boutique) via Helm, runs quality gates (Playwright E2E + K6 performance) against it, then tears everything down. The cluster is never permanent — it exists only for the duration of the pipeline run.

## Infrastructure Commands

All Terraform commands run from `.infrastructure/`:

```bash
terraform init                             # Initialize providers and remote state
terraform plan -input=false                # Preview changes
terraform apply -auto-approve -input=false # Apply (CI only)
terraform destroy -auto-approve -input=false # Tear down
terraform validate                         # Validate syntax
terraform output -raw boutique_public_url  # Get deployed app URL
```

Local development requires `.infrastructure/terraform.tfvars` (gitignored) with variable values.

### Provider Lock File

The `.terraform.lock.hcl` must include hashes for both `linux_amd64` (Terraform Cloud) and `windows_amd64` (local). After adding or changing providers, run:

```bash
terraform providers lock -platform=linux_amd64 -platform=windows_amd64
```

Commit the updated lock file. Without pinned Linux hashes, Terraform Cloud re-downloads providers from GitHub releases on every run and is susceptible to transient 502/504/connection-reset errors.

### Local kubectl Access

Export the kubeconfig from Terraform output to inspect the cluster:

```bash
$env:KUBECONFIG = "C:\path\to\kubeconfig.yaml"  # PowerShell — must use quotes
kubectl get pods -n default
kubectl get service frontend-external -n default  # get boutique external IP
```

## Architecture

### What Terraform Manages

Everything is provisioned in a single `terraform apply`:

1. **VPC** (`vpc.tf`) — isolated DigitalOcean network in `fra1`
2. **Kubernetes cluster** (`cluster.tf`) — 3-node autoscaling pool (`s-2vcpu-4gb`) on DigitalOcean K8s, version controlled via `do_kubernetes_version` variable
3. **Helm release** (`helm.tf`) — Online Boutique deployed from Google's OCI registry (`oci://us-docker.pkg.dev/online-boutique-ci/charts`), with `atomic = false` and `wait = false`
4. **LoadBalancer URL** — reads `frontend-external` service (not `frontend`) after a 90s `time_sleep`, exposed as `boutique_public_url` output

State is stored remotely in Terraform Cloud (`atp-quality-platform` org/workspace).

### Known Issues: Online Boutique on DigitalOcean

- **`emailservice` and `recommendationservice`** crash loop due to gRPC liveness probe timeout (default 1s is too tight). Fixed in the `health_check` pipeline job via `kubectl patch` — not fixable via Helm chart values as the chart doesn't expose probe configuration.
- **`atomic = false` / `wait = false`** on the Helm release is intentional — these services crash looping would otherwise cause `terraform apply` to roll back the entire release.
- **`frontend-external`** is the LoadBalancer service (not `frontend` which is ClusterIP). The chart creates this automatically via `externalService: true` default.
- Do not attempt to fix the gRPC probe issue via Helm `set` values for `googleCloudOperations.*` — these change chart behaviour in ways that break the frontend (requires OpenTelemetry collector).

### VPC Destroy Race Condition

DigitalOcean's API reports a K8s cluster as deleted before its node droplets are fully removed from the VPC, causing a 409 on `terraform destroy`. The fix is a `local-exec` provisioner on the VPC (`vpc.tf`) with `when = destroy` that sleeps 90 seconds before the VPC delete is attempted.

### CI/CD Pipeline (`.github/workflows/pipeline.yml`)

Triggers on push and PR to `master`. Four sequential jobs:

| Job | Purpose |
|-----|---------|
| `infrastructure` | `terraform apply` — provisions cluster + VPC + Helm release. Captures `boutique_public_url` into job output. |
| `health_check` | Installs `doctl`, exports kubeconfig, patches gRPC probe timeouts on `emailservice` and `recommendationservice`, then polls boutique URL (up to 10× every 15s) until HTTP 200. |
| `quality_gates` | Receives `BOUTIQUE_URL` env var. Placeholder for parallelized Playwright + K6. |
| `teardown` | Runs with `if: always()`. Waits 3 minutes (`sleep 180`) then `terraform destroy`. Runs even if earlier jobs fail to prevent orphaned resources. |

Required GitHub secrets: `DIGITALOCEAN_TOKEN`, `TF_API_TOKEN`.

`boutique_url` flows from Terraform → `$GITHUB_OUTPUT` → job `outputs:` → `needs.infrastructure.outputs.boutique_url` → `BOUTIQUE_URL` env var in `health_check` and `quality_gates`.

### Helm Provider v3 Syntax

The project uses `hashicorp/helm ~> 3.0.0`. Provider v3 changed block syntax to object assignment:
- `kubernetes {}` → `kubernetes = {}`
- `set {}` → `set = [{ name = "...", value = "..." }]`

IDE diagnostics may flag these as errors — this is a false positive from the Terraform extension not having the v3 schema. The actual Terraform plan/apply validates correctly.

## Remaining Work (Phase 2)

- Playwright E2E tests wired into `quality_gates` using `$BOUTIQUE_URL`
- K6 performance scripts wired into `quality_gates` using `$BOUTIQUE_URL`
- Both should run in parallel within the `quality_gates` job
