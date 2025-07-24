# EC2 to Kubernetes Migration Plan

## Overview
This plan migrates your n8n Flow application from EC2 to Amazon EKS (Kubernetes) while maintaining your existing RDS database.

## Pre-Migration Checklist
- [ ] Install prerequisites: `kubectl`, `eksctl`, `helm`, `terraform` (if using terraform)
- [ ] Get SSL certificate ARN from AWS Certificate Manager for `flow.buildworkforce.ai`
- [ ] Backup your current RDS database
- [ ] Test your Docker image locally
- [ ] Verify ECR access with your AWS profile

## Migration Options

### Option 1: Bash Script Deployment (Recommended for quick setup)
```bash
./deploy.sh
```

### Option 2: Terraform Deployment (Recommended for production)
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

## Migration Steps

### 1. Backup Current EC2 Files
```bash
# Edit backup-ec2.sh with your EC2 details first
./backup-ec2.sh
```
This backs up:
- n8n user files (`/home/node/.n8n`)
- Configuration files (docker-compose, .env)
- Custom nodes and uploaded files

**Note**: Since you're using RDS PostgreSQL, no database migration is needed. Your workflows will remain in the existing RDS instance.

### 2. Infrastructure Setup
- **EKS Cluster**: Creates a managed Kubernetes cluster
- **VPC & Networking**: New VPC with public/private subnets
- **ALB Controller**: For ingress traffic management
- **Storage**: EBS persistent volumes for n8n data

### 3. Deploy to Kubernetes
```bash
./deploy.sh
```
This creates:
- **Namespace**: Isolated environment for Flow app
- **Secrets**: Encrypted storage for sensitive data
- **ConfigMap**: Environment variables (connects to same RDS)
- **Deployment**: 2 replicas for high availability
- **Service**: Internal load balancing
- **Ingress**: External access via ALB

### 4. Restore Files to Kubernetes
```bash
./restore-to-k8s.sh
```
This copies your backed up files to the Kubernetes persistent volume. Your workflows will automatically appear since the K8s deployment connects to the same RDS database.

### 5. Database Connection
- **No Changes**: Continues using existing RDS instance at `flowdb.cunxsqwqr7rg.us-east-1.rds.amazonaws.com`
- **Automatic**: Workflows appear immediately after deployment connects to RDS

## Key Benefits
- **High Availability**: Multiple replicas across AZs
- **Auto Scaling**: Horizontal pod autoscaling capability
- **Rolling Updates**: Zero-downtime deployments
- **Resource Management**: CPU/memory limits and requests
- **Health Checks**: Liveness and readiness probes

## Resource Specifications
- **CPU**: 500m requests, 2000m limits
- **Memory**: 1Gi requests, 4Gi limits
- **Storage**: 20Gi persistent volume
- **Replicas**: 2 (can be scaled)

## Post-Migration Tasks
1. **DNS Update**: Point `flow.buildworkforce.ai` to ALB hostname
2. **Monitoring**: Set up CloudWatch/Prometheus monitoring
3. **Backup**: Configure persistent volume backups
4. **SSL**: Verify HTTPS is working properly

## Rollback Plan
If issues occur:
1. Update DNS to point back to EC2 instance
2. Start EC2 instance if stopped
3. Verify application functionality
4. Debug Kubernetes issues offline

## Scaling Operations

### Scale Pods
```bash
kubectl scale deployment flow --replicas=4 -n flow
```

### Scale Nodes
```bash
# Update desired capacity in ASG or terraform
terraform apply -var="desired_capacity=3"
```

## Monitoring Commands
```bash
# Check pods
kubectl get pods -n flow

# Check logs
kubectl logs -f deployment/flow -n flow

# Check ingress
kubectl get ingress -n flow

# Check service
kubectl get svc -n flow
```

## Cost Comparison
- **EC2**: Single instance, limited availability
- **EKS**: 
  - Control plane: ~$73/month
  - Worker nodes: 2x t3.medium ~$60/month
  - ALB: ~$16/month
  - **Total**: ~$149/month (vs ~$30/month for single EC2)

## Security Improvements
- **IAM Roles**: Fine-grained permissions via IRSA
- **Network Policies**: Pod-to-pod communication control
- **Secrets Management**: Encrypted at rest
- **VPC Isolation**: Private subnets for worker nodes

## Troubleshooting

### Common Issues
1. **Pods not starting**: Check image pull secrets and ECR permissions
2. **Load balancer not accessible**: Verify certificate ARN and DNS
3. **Database connection**: Check security groups and RDS connectivity
4. **Health checks failing**: Verify `/healthz` endpoint in n8n

### Debug Commands
```bash
# Describe pod issues
kubectl describe pod <pod-name> -n flow

# Check events
kubectl get events -n flow --sort-by='.lastTimestamp'

# Port forward for testing
kubectl port-forward svc/flow-service 8080:80 -n flow
```

## Support
- Review Kubernetes manifests in `k8s/` directory
- Check deployment script logs
- Terraform state in `terraform/` directory
- AWS EKS documentation for advanced configurations