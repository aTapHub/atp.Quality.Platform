# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ATP Quality Platform (aTapHub) is an infrastructure-as-code and CI/CD pipeline project for provisioning a quality assurance platform on DigitalOcean Kubernetes. It is in early scaffolding stage with planned Phase 2 additions for application deployment and quality gates.

## Infrastructure Commands

All Terraform commands run from the `.infrastructure/` directory:

```bash
terraform init                            # Initialize providers and remote state
terraform plan -input=false               # Preview changes
terraform apply -auto-approve -input=false # Apply changes (CI only)
terraform validate                        # Validate configuration syntax
```

Local development requires a `.infrastructure/terraform.tfvars` file (gitignored) with variable values.

## Architecture

### Infrastructure Stack

- **Cloud**: DigitalOcean (Frankfurt region `fra1`)
- **Orchestration**: DigitalOcean Kubernetes (`atp-quality-cluster`)
- **Networking**: Isolated VPC (`atp-quality-vpc`)
- **State**: Terraform Cloud (`atp-quality-platform` org/workspace)
- **Provider**: DigitalOcean provider v2.81.0 (pinned in `.terraform.lock.hcl`)

Cluster spec: 3-node autoscaling pool (`s-2vcpu-4gb`), Kubernetes version controlled via `do_kubernetes_version` variable with validation.

### CI/CD Pipeline (`.github/workflows/pipeline.yml`)

Three sequential phases:
1. **Infrastructure** — Terraform init → plan → apply on `master` push
2. **Application Deployment** *(Phase 2 placeholder)* — Helm deploy of Boutique App to DigitalOcean K8s
3. **Quality Gates** *(Phase 2 placeholder)* — Parallelized Playwright (E2E) and K6 (performance) tests

Required GitHub secrets: `DIGITALOCEAN_TOKEN`, `TF_API_TOKEN`.

### Terraform File Layout (`.infrastructure/`)

| File | Purpose |
|------|---------|
| `provider.tf` | DigitalOcean provider + Terraform Cloud backend |
| `cluster.tf` | Kubernetes cluster resource |
| `vpc.tf` | VPC network resource |
| `variable.tf` | Input variables with validation |
| `output.tf` | Cluster ID and kubeconfig outputs |
| `terraform.tfvars` | Local variable values (gitignored) |

## Planned Phase 2 Work

- Helm chart deployment for Boutique App
- Playwright E2E test integration
- K6 performance test integration (parallelized with Playwright)
