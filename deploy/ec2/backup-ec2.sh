#!/bin/bash

set -e

# Configuration
EC2_HOST="your-ec2-host"  # Replace with your EC2 IP/hostname
EC2_USER="ubuntu"         # Replace with your EC2 username (ubuntu/ec2-user/etc)
BACKUP_DIR="./n8n-backup-$(date +%Y%m%d-%H%M%S)"
N8N_HOME="/home/node/.n8n"  # Default n8n directory

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

# Create backup directory
mkdir -p "$BACKUP_DIR"

log "Starting n8n backup from EC2..."
log "Backup directory: $BACKUP_DIR"

# Backup n8n files
log "Backing up n8n user files..."
scp -r "$EC2_USER@$EC2_HOST:$N8N_HOME" "$BACKUP_DIR/" || warn "Failed to backup n8n user files"

# Backup docker-compose or systemd configs if they exist
log "Backing up configuration files..."
scp "$EC2_USER@$EC2_HOST:/opt/n8n/docker-compose.yml" "$BACKUP_DIR/" 2>/dev/null || warn "No docker-compose.yml found"
scp "$EC2_USER@$EC2_HOST:/etc/systemd/system/n8n.service" "$BACKUP_DIR/" 2>/dev/null || warn "No systemd service found"

# Backup environment files
scp "$EC2_USER@$EC2_HOST:/opt/n8n/.env" "$BACKUP_DIR/" 2>/dev/null || warn "No .env file found"

# Create database dump if using SQLite (common in EC2 setups)
log "Attempting to backup database..."
ssh "$EC2_USER@$EC2_HOST" "cd $N8N_HOME && ls -la database.sqlite" &>/dev/null && {
    log "SQLite database found, backing up..."
    scp "$EC2_USER@$EC2_HOST:$N8N_HOME/database.sqlite" "$BACKUP_DIR/"
} || warn "No SQLite database found (might be using external DB)"

# Get n8n version info
log "Getting n8n version information..."
ssh "$EC2_USER@$EC2_HOST" "n8n --version" > "$BACKUP_DIR/n8n-version.txt" 2>/dev/null || warn "Could not get n8n version"

# Create backup summary
cat > "$BACKUP_DIR/backup-info.txt" << EOF
n8n Backup Information
=====================
Backup Date: $(date)
Source: $EC2_USER@$EC2_HOST
n8n Home: $N8N_HOME

Files backed up:
$(ls -la "$BACKUP_DIR/")

Next steps:
1. Update k8s/secrets.yaml and k8s/configmap.yaml with your settings
2. Run ./restore-to-k8s.sh to restore files to Kubernetes
3. Deploy using ./deploy.sh
EOF

log "Backup completed: $BACKUP_DIR"
log "Review backup-info.txt for next steps"