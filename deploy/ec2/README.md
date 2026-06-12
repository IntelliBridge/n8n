# Flow deployment (EC2 + docker-compose)

**This directory is the real deployment method for flow.buildworkforce.ai.**

Production = one EC2 instance (`i-038a90bc1fc8c0a79`, us-east-1) running docker-compose
behind ALB `torqflow-staging`, with RDS PostgreSQL (`flowdb`). The Kubernetes/Helm/Terraform
assets from the 1.90 fork were **never applied to any environment**; they live only on the
`legacy/1.90-master` branch and are intentionally not carried on this branch.

## Fork layout

- Branch `flow-2.x` (this branch) = upstream tag `n8n@2.25.7` + a small curated patch stack
  (branding + this deploy dir). Keep the stack small: prefer env-var configuration over
  source patches — `N8N_TEMPLATES_ENABLED=false` replaced a 24-file source deletion.
- Branch `legacy/1.90-master` = the old 1.90.0 fork, preserved read-only.
- Upstream sync = rebase the patch-stack commits onto the new upstream tag (monthly,
  plus immediately for security advisories).

## Building the image

2.x images are built from a pre-compiled tree (the 1.x `n8n-custom` single-stage Dockerfile
no longer exists upstream):

```bash
pnpm install --frozen-lockfile
pnpm build:deploy   # compiles to ./compiled
# Prod EC2 is x86_64 — ALWAYS build for linux/amd64 (a build on an Apple Silicon
# Mac defaults to arm64 and fails on the host with "exec /sbin/tini: exec format error").
docker buildx build --platform linux/amd64 \
  --build-arg N8N_VERSION=2.25.7 --build-arg N8N_RELEASE_TYPE=stable --load \
  -t 132880019009.dkr.ecr.us-east-1.amazonaws.com/flow:2.25.7-$(git rev-parse --short HEAD) \
  -f docker/images/n8n/Dockerfile .
```

Pass `N8N_RELEASE_TYPE=stable` so the instance reports `releaseChannel: stable`
(the 1.90 image was built without it and self-reported `dev`).

## Deploying

CI (`.github/workflows/flow-deploy.yml`) builds + pushes to ECR, then deploys via
SSM Run Command: `docker compose pull && docker compose up -d` in `/opt/flow` on the
instance. Manual `workflow_dispatch` gate for prod.

## Non-negotiables

- `N8N_ENCRYPTION_KEY` must be the original key (Secrets Manager: `flow/n8n-encryption-key`).
- The `runners` sidecar version must match the n8n image version.
- `N8N_DEFAULT_BINARY_DATA_MODE=filesystem` + the `n8n_data` volume (in-memory mode is gone in 2.x).
- Broker port 5679 never leaves the compose network.
- Rollback = RDS snapshot restore + old image; `n8n db:revert` is not a viable path.

See the full migration plan: `~/Coding/agile-defense/n8n-migration-plan.md` (Phase 3/6 runbooks).
