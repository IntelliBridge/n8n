# TODO: wire AWS credentials into the CI deploy pipeline

> GitHub Issues are disabled on this repo, so this tracked doc stands in for the
> issue. Delete it once the pipeline is wired up.

## Problem

`.github/workflows/flow-deploy.yml` cannot push to ECR or run the SSM rollout
because the AWS credentials it expects do not exist. The image **builds and
passes the Trivy scan**, then the `build` job fails at **Configure AWS
credentials** with:

```
Credentials could not be loaded, please check your action inputs:
Could not load credentials from any providers
```

As a result, production deploys are currently done **manually** from a laptop
with `eric-luna` AWS creds (build → `docker push` to ECR → `aws ssm send-command`
running `docker compose pull && up -d` on the prod EC2). See `README.md`.

## What's missing

- **Repo secrets** `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`, referenced by
  both the `build` and `deploy` jobs — not set (the repo has no secrets).
- **`production` GitHub Environment** — the `deploy` job declares
  `environment: production`, but only a `benchmarking` environment exists. No
  approval gate, no environment-scoped secrets.

## Recommended fix (preferred: OIDC, no long-lived keys)

1. Create a GitHub OIDC identity provider in AWS account `132880019009`
   (`token.actions.githubusercontent.com`).
2. Create an IAM role (e.g. `flow-github-deploy`) whose trust policy is
   restricted to this repo + branch, e.g.
   `repo:IntelliBridge/n8n:ref:refs/heads/master` (and/or the `production`
   environment).
3. Attach a **least-privilege** policy:
   - ECR: `ecr:GetAuthorizationToken` (resource `*`) plus
     `ecr:BatchCheckLayerAvailability`, `ecr:InitiateLayerUpload`,
     `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, `ecr:PutImage` scoped to
     `arn:aws:ecr:us-east-1:132880019009:repository/flow`.
   - SSM: `ssm:SendCommand` scoped to instance `i-038a90bc1fc8c0a79` and the
     `AWS-RunShellScript` document, plus `ssm:GetCommandInvocation` for the
     status poll.
4. Update both `configure-aws-credentials` steps to
   `role-to-assume: arn:aws:iam::132880019009:role/flow-github-deploy` (drop the
   access-key inputs) and add `permissions: { id-token: write }` to the jobs.

## Alternative (long-lived keys, only if OIDC is not feasible)

Create a **dedicated CI IAM user** (not `eric-luna`) with the least-privilege
policy above, generate one access key, store it as **`production` environment**
secrets (not repo-wide), and set a rotation reminder. Never reuse a personal
user's keys for CI.

## Also recommended

- Create the **`production` environment** with **required reviewers** so the
  prod `deploy` job pauses for manual approval; move deploy secrets to the
  environment scope.
- Once CI deploys work, demote the manual steps in `README.md` to a documented
  fallback rather than the default path.
