# ATP Quality Platform

Overview for the ATP Quality Platform repository.

Short description
- ATP Quality Platform is an ephemeral quality testing platform that provisions a short-lived Kubernetes cluster, deploys a demo app (Online Boutique), runs quality gates (E2E + performance), then tears everything down.

Quick start

1. See detailed infrastructure notes in [CLAUDE.md](CLAUDE.md).

2. Typical Terraform workflow (run from `.infrastructure/`):

```bash
terraform init
terraform plan -input=false
terraform apply -auto-approve -input=false
terraform destroy -auto-approve -input=false
```

3. Required GitHub secrets for CI: `DIGITALOCEAN_TOKEN`, `TF_API_TOKEN`.

Notes
- The CI pipeline provisions a cluster, deploys the demo app, runs health checks and quality gates, and then always tears down resources to avoid leftovers.

For more details on architecture and CI steps, see [CLAUDE.md](CLAUDE.md).
