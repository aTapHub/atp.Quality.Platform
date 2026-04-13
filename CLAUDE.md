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

Local development requires `.infrastructure/terraform.tfvars` (gitignored) with variable values. Run `terraform init` after adding or changing providers to update `.terraform.lock.hcl` — commit the lock file so Terraform Cloud uses pinned versions.

## Architecture

### What Terraform Manages

Everything is provisioned in a single `terraform apply`:

1. **VPC** (`vpc.tf`) — isolated DigitalOcean network in `fra1`
2. **Kubernetes cluster** (`cluster.tf`) — 3-node autoscaling pool (`s-2vcpu-4gb`) on DigitalOcean K8s, version controlled via `do_kubernetes_version` variable
3. **Helm release** (`helm.tf`) — Online Boutique deployed from Google's OCI registry (`oci://us-docker.pkg.dev/online-boutique-ci/charts`), with `atomic = true` and `wait = true`
4. **LoadBalancer URL** — captured via `kubernetes_service` data source after Helm completes, exposed as `boutique_public_url` output

State is stored remotely in Terraform Cloud (`atp-quality-platform` org/workspace).

### VPC Destroy Race Condition

DigitalOcean's API reports a K8s cluster as deleted before its node droplets are fully removed from the VPC, causing a 409 on `terraform destroy`. The fix is a `local-exec` provisioner on the VPC with `when = destroy` that sleeps 90 seconds after the cluster is gone before the VPC delete is attempted.

### CI/CD Pipeline (`.github/workflows/pipeline.yml`)

Triggers on push and PR to `master`. Four sequential jobs:

| Job | Purpose |
|-----|---------|
| `infrastructure` | `terraform apply` — provisions cluster + VPC + Helm release. Captures `boutique_public_url` into job output. |
| `health_check` | Polls the boutique URL (up to 10× every 15s) until HTTP 200. Fails the pipeline if the app doesn't come up. |
| `quality_gates` | Receives `BOUTIQUE_URL` env var. Placeholder for parallelized Playwright + K6. |
| `teardown` | Runs with `if: always()`. Waits 3 minutes (`sleep 180`) then `terraform destroy`. Runs even if earlier jobs fail to prevent orphaned resources. |

Required GitHub secrets: `DIGITALOCEAN_TOKEN`, `TF_API_TOKEN`.

`boutique_url` flows from Terraform → `$GITHUB_OUTPUT` → job `outputs:` → `needs.infrastructure.outputs.boutique_url` → `BOUTIQUE_URL` env var in `health_check` and `quality_gates`.

## Remaining Work (Phase 2)

- Playwright E2E tests wired into `quality_gates` using `$BOUTIQUE_URL`
- K6 performance scripts wired into `quality_gates` using `$BOUTIQUE_URL`
- Both should run in parallel within the `quality_gates` job
