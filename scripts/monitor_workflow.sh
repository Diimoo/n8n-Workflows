#!/bin/bash

# Production monitoring script for n8n workflow health
# This script monitors the health of the Reddit video automation workflow

set -euo pipefail

# Configuration
LOG_FILE="/var/log/n8n_monitor.log"
ALERT_EMAIL="${ALERT_EMAIL:-}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Alert function
send_alert() {
    local message="$1"
    local severity="$2"
    
    log "ALERT [$severity]: $message"
    
    # Send webhook notification if configured
    if [ -n "$WEBHOOK_URL" ]; then
        curl -X POST -H "Content-Type: application/json" \
             -d "{\"text\":\"N8N Alert [$severity]: $message\"}" \
             "$WEBHOOK_URL" 2>/dev/null || true
    fi
    
    # Send email if configured
    if [ -n "$ALERT_EMAIL" ]; then
        echo "$message" | mail -s "N8N Alert [$severity]" "$ALERT_EMAIL" 2>/dev/null || true
    fi
}

# Check disk space
check_disk_space() {
    local usage=$(df /tmp | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$usage" -gt 80 ]; then
        send_alert "Disk space critical: ${usage}% used in /tmp" "CRITICAL"
    elif [ "$usage" -gt 70 ]; then
        send_alert "Disk space warning: ${usage}% used in /tmp" "WARNING"
    fi
}

# Check service health
check_service_health() {
    # Check if required services are running
    local services=("ollama" "n8n" "postgres" "qdrant")
    
    for service in "${services[@]}"; do
        if ! docker ps --filter "name=$service" --filter "status=running" -q | grep -q .; then
            send_alert "Service $service is not running" "CRITICAL"
        fi
    done
}

# Check file permissions
check_file_permissions() {
    local temp_dir="/tmp"
    
    if [ ! -w "$temp_dir" ]; then
        send_alert "Cannot write to temporary directory: $temp_dir" "CRITICAL"
    fi
}

# Check recent workflow executions
check_workflow_executions() {
    local log_file="/var/log/n8n_execution.log"
    
    if [ -f "$log_file" ]; then
        local recent_errors=$(grep -c "ERROR" "$log_file" 2>/dev/null || echo "0")
        local recent_executions=$(grep -c "Starting" "$log_file" 2>/dev/null || echo "0")
        
        if [ "$recent_errors" -gt 5 ]; then
            send_alert "High error rate detected: $recent_errors errors in recent executions" "WARNING"
        fi
        
        if [ "$recent_executions" -eq 0 ]; then
            send_alert "No recent workflow executions detected" "WARNING"
        fi
    fi
}

# Main monitoring function
main() {
    log "Starting health check"
    
    check_disk_space
    check_service_health
    check_file_permissions
    check_workflow_executions
    
    log "Health check completed"
}

main "$@"