#!/bin/bash

set -e

# Configuration
AWS_REGION="us-east-1"
AWS_PROFILE="intellibridge"
ECR_REGISTRY="132880019009.dkr.ecr.us-east-1.amazonaws.com"
IMAGE_NAME="flow"
CLUSTER_NAME="flow-cluster"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    command -v kubectl >/dev/null 2>&1 || error "kubectl is required but not installed"
    command -v aws >/dev/null 2>&1 || error "aws cli is required but not installed"
    command -v docker >/dev/null 2>&1 || error "docker is required but not installed"
    
    log "Prerequisites check passed"
}

# Build and push Docker image
build_and_push() {
    log "Building and pushing Docker image..."
    
    # Build image
    docker build -t ${IMAGE_NAME} --platform linux/amd64 -f docker/images/n8n-custom/Dockerfile .
    
    # Tag image
    docker tag ${IMAGE_NAME}:latest ${ECR_REGISTRY}/${IMAGE_NAME}:latest
    
    # Login to ECR
    aws ecr get-login-password --region ${AWS_REGION} --profile ${AWS_PROFILE} | \
        docker login --username AWS --password-stdin ${ECR_REGISTRY}
    
    # Push image
    docker push ${ECR_REGISTRY}/${IMAGE_NAME}:latest
    
    log "Docker image pushed successfully"
}

# Create EKS cluster (if it doesn't exist)
create_cluster() {
    log "Checking if EKS cluster exists..."
    
    if aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} --profile ${AWS_PROFILE} >/dev/null 2>&1; then
        log "EKS cluster ${CLUSTER_NAME} already exists"
    else
        log "Creating EKS cluster ${CLUSTER_NAME}..."
        
        # Create cluster using eksctl (you need to install eksctl)
        eksctl create cluster \
            --name ${CLUSTER_NAME} \
            --region ${AWS_REGION} \
            --nodegroup-name flow-nodes \
            --node-type t3.medium \
            --nodes 2 \
            --nodes-min 1 \
            --nodes-max 4 \
            --managed \
            --profile ${AWS_PROFILE}
    fi
    
    # Update kubeconfig
    aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME} --profile ${AWS_PROFILE}
    
    log "EKS cluster configured"
}

# Install AWS Load Balancer Controller
install_alb_controller() {
    log "Installing AWS Load Balancer Controller..."
    
    # Check if already installed
    if kubectl get deployment -n kube-system aws-load-balancer-controller >/dev/null 2>&1; then
        log "AWS Load Balancer Controller already installed"
        return
    fi
    
    # Create IAM OIDC identity provider
    eksctl utils associate-iam-oidc-provider --region=${AWS_REGION} --cluster=${CLUSTER_NAME} --approve --profile ${AWS_PROFILE}
    
    # Download IAM policy
    curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.4.4/docs/install/iam_policy.json
    
    # Create IAM policy
    aws iam create-policy \
        --policy-name AWSLoadBalancerControllerIAMPolicy \
        --policy-document file://iam_policy.json \
        --profile ${AWS_PROFILE} || true
    
    # Create service account
    eksctl create iamserviceaccount \
        --cluster=${CLUSTER_NAME} \
        --namespace=kube-system \
        --name=aws-load-balancer-controller \
        --role-name "AmazonEKSLoadBalancerControllerRole" \
        --attach-policy-arn=arn:aws:iam::132880019009:policy/AWSLoadBalancerControllerIAMPolicy \
        --approve \
        --profile ${AWS_PROFILE}
    
    # Install controller using Helm
    helm repo add eks https://aws.github.io/eks-charts
    helm repo update
    helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
        -n kube-system \
        --set clusterName=${CLUSTER_NAME} \
        --set serviceAccount.create=false \
        --set serviceAccount.name=aws-load-balancer-controller
    
    rm -f iam_policy.json
    log "AWS Load Balancer Controller installed"
}

# Deploy application
deploy_app() {
    log "Deploying Flow application..."
    
    # Apply Kubernetes manifests in order
    kubectl apply -f k8s/namespace.yaml
    kubectl apply -f k8s/secrets.yaml
    kubectl apply -f k8s/configmap.yaml
    kubectl apply -f k8s/pvc.yaml
    kubectl apply -f k8s/deployment.yaml
    kubectl apply -f k8s/service.yaml
    
    # Wait for deployment to be ready
    kubectl wait --for=condition=available --timeout=300s deployment/flow -n flow
    
    # Apply ingress after deployment is ready
    kubectl apply -f k8s/ingress.yaml
    
    log "Application deployed successfully"
}

# Check deployment status
check_status() {
    log "Checking deployment status..."
    
    echo ""
    echo "Pods:"
    kubectl get pods -n flow
    
    echo ""
    echo "Services:"
    kubectl get svc -n flow
    
    echo ""
    echo "Ingress:"
    kubectl get ingress -n flow
    
    echo ""
    log "To get the Load Balancer URL:"
    echo "kubectl get ingress flow-ingress -n flow -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

# Main deployment function
main() {
    log "Starting Flow deployment to Kubernetes..."
    
    check_prerequisites
    build_and_push
    create_cluster
    install_alb_controller
    deploy_app
    check_status
    
    log "Deployment completed successfully!"
    warn "Don't forget to:"
    warn "1. Update your DNS to point to the ALB"
    warn "2. Replace YOUR_CERT_ARN in ingress.yaml with your actual certificate ARN"
    warn "3. Monitor the application logs: kubectl logs -f deployment/flow -n flow"
}

# Run main function
main "$@"