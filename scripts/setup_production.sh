#!/bin/bash

# Production environment setup script
# This script sets up the production environment for the Reddit video automation workflow

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/var/log/n8n_setup.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Error handling function
handle_error() {
    log "ERROR: $1"
    exit 1
}

log "Starting production environment setup"

# Create necessary directories
log "Creating necessary directories"
mkdir -p /tmp/n8n_temp
mkdir -p /var/log/n8n
mkdir -p /data/shared/videos
mkdir -p /data/shared/audio
mkdir -p /data/shared/subtitles

# Set proper permissions
log "Setting permissions"
chmod 755 /tmp/n8n_temp
chmod 755 /var/log/n8n
chmod 755 /data/shared/videos
chmod 755 /data/shared/audio
chmod 755 /data/shared/subtitles

# Install required system packages
log "Checking system dependencies"
if command -v apt-get &> /dev/null; then
    # Debian/Ubuntu
    apt-get update
    apt-get install -y ffmpeg curl wget jq bc
elif command -v yum &> /dev/null; then
    # CentOS/RHEL
    yum install -y ffmpeg curl wget jq bc
elif command -v apk &> /dev/null; then
    # Alpine Linux
    apk add --no-cache ffmpeg curl wget jq bc
else
    log "WARNING: Unknown package manager, please install ffmpeg, curl, wget, jq, and bc manually"
fi

# Set up cron jobs for maintenance
log "Setting up cron jobs"
cat > /tmp/n8n_cron << 'EOF'
# N8N Maintenance Cron Jobs
# Clean up temporary files daily at 2 AM
0 2 * * * /app/scripts/cleanup_temp_files.sh

# Monitor workflow health every 5 minutes
*/5 * * * * /app/scripts/monitor_workflow.sh

# Weekly log rotation
0 3 * * 0 /app/scripts/rotate_logs.sh
EOF

# Install cron job
if command -v crontab &> /dev/null; then
    crontab /tmp/n8n_cron
    log "Cron jobs installed successfully"
else
    log "WARNING: crontab not available, manual setup of scheduled tasks required"
fi

# Set up log rotation
log "Setting up log rotation"
cat > /etc/logrotate.d/n8n << 'EOF'
/var/log/n8n/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0644 root root
}
EOF

# Validate environment
log "Validating environment"
if ! command -v ffmpeg &> /dev/null; then
    handle_error "FFmpeg is not installed or not in PATH"
fi

if ! command -v curl &> /dev/null; then
    handle_error "curl is not installed or not in PATH"
fi

if ! command -v jq &> /dev/null; then
    handle_error "jq is not installed or not in PATH"
fi

log "Environment setup completed successfully"
log "Please review the following configuration files:"
log "  - /app/n8n_workflow_reddit_video_automation.json"
log "  - /app/docker-compose.yml"
log "  - Environment variables in .env file"
log "  - Cron jobs in crontab"
log "  - Log rotation in /etc/logrotate.d/n8n"