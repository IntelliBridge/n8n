# Deployment Guide

This document outlines the deployment process for the n8n Flow application using modern CI/CD practices.

## Overview

The deployment architecture separates infrastructure management from application deployment:
- **Terraform** manages AWS infrastructure (EKS, VPC, IAM, certificates)
- **Helm** manages Kubernetes application resources
- **GitHub Actions** orchestrates both infrastructure and application deployments

## Deployment Methods

### 1. Automated Deployment (Recommended)

#### GitHub Actions Workflows

The repository includes two automated workflows:

**Infrastructure Deployment** (`.github/workflows/infrastructure.yml`)
- Triggers on changes to `terraform/**` files
- Manages AWS resources using Terraform
- Runs on pushes to `main`/`master` branches

**Application Deployment** (`.github/workflows/application.yml`)
- Triggers on changes to application code
- Builds Docker images with proper versioning
- Performs security scanning with Trivy
- Deploys using Helm charts
- Runs on pushes to `main`/`master` branches

#### Required Secrets

Configure the following secrets in GitHub repository settings:

```
AWS_ROLE_ARN=arn:aws:iam::ACCOUNT:role/GitHubActionsRole
N8N_ENCRYPTION_KEY=your-encryption-key
OPENSEARCH_HOST=your-opensearch-url-with-credentials
DB_PASSWORD=your-database-password
```

### 2. Manual Deployment

#### Prerequisites

- AWS CLI configured with appropriate permissions
- kubectl installed and configured
- Helm 3.12+ installed
- Docker installed (for local builds)

#### Infrastructure Setup

```bash
cd terraform/

# Initialize Terraform
terraform init

# Plan infrastructure changes
terraform plan \
  -var="n8n_encryption_key=YOUR_KEY" \
  -var="opensearch_host=YOUR_HOST" \
  -var="db_password=YOUR_PASSWORD"

# Apply infrastructure
terraform apply \
  -var="n8n_encryption_key=YOUR_KEY" \
  -var="opensearch_host=YOUR_HOST" \
  -var="db_password=YOUR_PASSWORD"
```

#### Application Deployment

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name flow-cluster

# Deploy with Helm
helm upgrade --install flow ./helm/flow \
  --namespace flow \
  --create-namespace \
  --set image.tag=v1.0.0 \
  --set secrets.N8N_ENCRYPTION_KEY="YOUR_KEY" \
  --set secrets.OPENSEARCH_HOST="YOUR_HOST" \
  --set secrets.DB_POSTGRESDB_PASSWORD="YOUR_PASSWORD" \
  --wait \
  --timeout 10m
```

## Environment Configuration

### Production Values

Create environment-specific values files:

```yaml
# helm/flow/values-prod.yaml
image:
  tag: "v1.2.3"  # Specific version tag

ingress:
  hosts:
    - host: flow.buildworkforce.ai
  certificateArn: "arn:aws:acm:us-east-1:123456789:certificate/abc123"

resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "2Gi"
    cpu: "1000m"
```

Deploy with environment-specific values:
```bash
helm upgrade --install flow ./helm/flow \
  -f helm/flow/values-prod.yaml \
  --namespace flow
```

## Security Best Practices

### Secret Management

- **Never commit secrets** to the repository
- Use AWS Secrets Manager or Parameter Store for production
- Configure External Secrets Operator for automatic secret sync
- Rotate secrets regularly

### Image Security

- Images are tagged with semantic versions (no `:latest`)
- Automated security scanning with Trivy
- Vulnerability reports uploaded to GitHub Security tab
- Images signed and verified before deployment

### Network Security

- Applications run in private subnets
- Load balancer in public subnets
- SSL/TLS certificates managed by ACM
- WAF protection (configure separately if needed)

## Monitoring and Troubleshooting

### Deployment Status

```bash
# Check deployment status
kubectl rollout status deployment/flow --namespace flow

# View pods
kubectl get pods --namespace flow

# Check logs
kubectl logs -f deployment/flow --namespace flow

# Describe resources for troubleshooting
kubectl describe deployment flow --namespace flow
```

### Helm Operations

```bash
# List deployments
helm list --namespace flow

# Get deployment status
helm status flow --namespace flow

# Rollback to previous version
helm rollback flow 1 --namespace flow

# Uninstall (be careful!)
helm uninstall flow --namespace flow
```

## Support

For deployment issues:
1. Check GitHub Actions workflow logs
2. Review Kubernetes events: `kubectl get events --namespace flow`
3. Examine Helm deployment history: `helm history flow --namespace flow`
4. Consult application logs: `kubectl logs -f deployment/flow --namespace flow`
