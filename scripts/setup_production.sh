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
else\n    log \"WARNING: Unknown package manager, please install ffmpeg, curl, wget, jq, and bc manually\"\nfi\n\n# Set up cron jobs for maintenance\nlog \"Setting up cron jobs\"\ncat > /tmp/n8n_cron << 'EOF'\n# N8N Maintenance Cron Jobs\n# Clean up temporary files daily at 2 AM\n0 2 * * * /app/scripts/cleanup_temp_files.sh\n\n# Monitor workflow health every 5 minutes\n*/5 * * * * /app/scripts/monitor_workflow.sh\n\n# Weekly log rotation\n0 3 * * 0 /app/scripts/rotate_logs.sh\nEOF\n\n# Install cron job\nif command -v crontab &> /dev/null; then\n    crontab /tmp/n8n_cron\n    log \"Cron jobs installed successfully\"\nelse\n    log \"WARNING: crontab not available, manual setup of scheduled tasks required\"\nfi\n\n# Set up log rotation\nlog \"Setting up log rotation\"\ncat > /etc/logrotate.d/n8n << 'EOF'\n/var/log/n8n/*.log {\n    daily\n    rotate 7\n    compress\n    delaycompress\n    missingok\n    notifempty\n    create 0644 root root\n}\nEOF\n\n# Validate environment\nlog \"Validating environment\"\nif ! command -v ffmpeg &> /dev/null; then\n    handle_error \"FFmpeg is not installed or not in PATH\"\nfi\n\nif ! command -v curl &> /dev/null; then\n    handle_error \"curl is not installed or not in PATH\"\nfi\n\nif ! command -v jq &> /dev/null; then\n    handle_error \"jq is not installed or not in PATH\"\nfi\n\nlog \"Environment setup completed successfully\"\nlog \"Please review the following configuration files:\"\nlog \"  - /app/n8n_workflow_reddit_video_automation.json\"\nlog \"  - /app/docker-compose.yml\"\nlog \"  - Environment variables in .env file\"\nlog \"  - Cron jobs in crontab\"\nlog \"  - Log rotation in /etc/logrotate.d/n8n\"\n