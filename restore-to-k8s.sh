#!/bin/bash

set -e

# Configuration
NAMESPACE="flow"
DEPLOYMENT_NAME="flow"
BACKUP_DIR="${1:-$(ls -d n8n-backup-* | tail -1)}"  # Use latest backup if no arg provided

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

# Check if backup directory exists
if [ ! -d "$BACKUP_DIR" ]; then
    error "Backup directory $BACKUP_DIR not found. Run ./backup-ec2.sh first"
fi

log "Restoring n8n files from: $BACKUP_DIR"

# Check if deployment exists
if ! kubectl get deployment $DEPLOYMENT_NAME -n $NAMESPACE >/dev/null 2>&1; then
    error "Deployment $DEPLOYMENT_NAME not found in namespace $NAMESPACE. Deploy first with ./deploy.sh"
fi

# Get pod name
POD_NAME=$(kubectl get pods -n $NAMESPACE -l app=flow -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD_NAME" ]; then
    error "No running pods found for app=flow in namespace $NAMESPACE"
fi

log "Found pod: $POD_NAME"

# Create temporary archive of backup files
log "Creating archive of backup files..."
TEMP_ARCHIVE="/tmp/n8n-restore-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "$TEMP_ARCHIVE" -C "$BACKUP_DIR" .

# Copy archive to pod
log "Copying files to Kubernetes pod..."
kubectl cp "$TEMP_ARCHIVE" "$NAMESPACE/$POD_NAME:/tmp/restore.tar.gz"

# Extract files in pod
log "Extracting files in pod..."
kubectl exec -n $NAMESPACE "$POD_NAME" -- bash -c "
    cd /home/node/.n8n
    tar -xzf /tmp/restore.tar.gz --strip-components=1 --exclude='backup-info.txt' --exclude='n8n-version.txt'
    chown -R node:node /home/node/.n8n
    rm -f /tmp/restore.tar.gz
"

# Handle database migration if SQLite backup exists
if [ -f "$BACKUP_DIR/database.sqlite" ]; then
    warn "SQLite database found in backup, but Kubernetes setup uses PostgreSQL"
    warn "You'll need to migrate data manually or use n8n export/import workflows"
    warn "Consider using n8n CLI: n8n export:workflow --all"
fi

# Restart deployment to pick up changes
log "Restarting deployment to apply changes..."
kubectl rollout restart deployment/$DEPLOYMENT_NAME -n $NAMESPACE
kubectl rollout status deployment/$DEPLOYMENT_NAME -n $NAMESPACE --timeout=300s

# Clean up
rm -f "$TEMP_ARCHIVE"

log "Restore completed successfully!"
log "Files restored to pod: $POD_NAME"

# Show pod logs
warn "Checking application logs..."
kubectl logs -n $NAMESPACE deployment/$DEPLOYMENT_NAME --tail=20

log "Access your n8n instance at: https://flow.buildworkforce.ai"