#!/bin/bash

# Log rotation script for n8n workflow logs
# This script rotates and compresses old log files

set -euo pipefail

# Configuration
LOG_DIR="/var/log/n8n"
RETENTION_DAYS=30

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting log rotation"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Rotate and compress logs older than 1 day
find "$LOG_DIR" -name "*.log" -mtime +1 -exec gzip {} \;

# Remove compressed logs older than retention period
find "$LOG_DIR" -name "*.log.gz" -mtime +$RETENTION_DAYS -delete

# Rotate current logs if they're too large (>100MB)
for log_file in "$LOG_DIR"/*.log; do
    if [ -f "$log_file" ] && [ $(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0) -gt 104857600 ]; then
        mv "$log_file" "${log_file}.$(date +%Y%m%d-%H%M%S)"
        touch "$log_file"
        log "Rotated large log file: $(basename "$log_file")"
    fi
done

log "Log rotation completed"