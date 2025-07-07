#!/bin/bash

# Input validation and security functions for n8n workflow
# This script provides reusable security functions

set -euo pipefail

# Rate limiting configuration
RATE_LIMIT_FILE="/tmp/n8n_rate_limit"
RATE_LIMIT_WINDOW=60  # seconds
RATE_LIMIT_MAX_REQUESTS=${RATE_LIMIT_REQUESTS_PER_MINUTE:-60}

# Security logging
SECURITY_LOG="/var/log/n8n/security.log"

# Logging function
security_log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SECURITY: $1" | tee -a "$SECURITY_LOG"
}

# Rate limiting function
check_rate_limit() {
    local client_id="${1:-unknown}"
    local current_time=$(date +%s)
    local window_start=$((current_time - RATE_LIMIT_WINDOW))
    
    # Create rate limit file if it doesn't exist
    touch "$RATE_LIMIT_FILE"
    
    # Clean old entries
    awk -v window_start="$window_start" '$1 >= window_start' "$RATE_LIMIT_FILE" > "${RATE_LIMIT_FILE}.tmp" || true
    mv "${RATE_LIMIT_FILE}.tmp" "$RATE_LIMIT_FILE"
    
    # Count current requests
    local request_count=$(grep -c "^[0-9]* $client_id" "$RATE_LIMIT_FILE" 2>/dev/null || echo "0")
    
    if [ "$request_count" -ge "$RATE_LIMIT_MAX_REQUESTS" ]; then
        security_log "Rate limit exceeded for client: $client_id"
        return 1
    fi
    
    # Record this request
    echo "$current_time $client_id" >> "$RATE_LIMIT_FILE"
    return 0
}

# URL validation function
validate_url() {
    local url="$1"
    local allowed_domains="${ALLOWED_DOMAINS:-reddit.com,pexels.com}"
    
    # Basic URL format validation
    if ! echo "$url" | grep -E '^https?://[a-zA-Z0-9.-]+' > /dev/null; then
        security_log "Invalid URL format: $url"
        return 1
    fi
    
    # Extract domain
    local domain=$(echo "$url" | sed -E 's|^https?://([^/]+).*|\1|')
    
    # Check against allowed domains
    if echo "$allowed_domains" | grep -q "$domain"; then
        return 0
    else
        security_log "Domain not allowed: $domain"
        return 1
    fi
}

# Input sanitization function
sanitize_input() {
    local input="$1"
    local max_length="${2:-10000}"
    
    # Remove null bytes
    input=$(echo "$input" | tr -d '\0')
    
    # Limit length
    if [ ${#input} -gt "$max_length" ]; then
        security_log "Input too long: ${#input} characters (max: $max_length)"
        return 1
    fi
    
    # Remove potentially dangerous characters for shell execution
    input=$(echo "$input" | sed 's/[;|&$`\\]//g')
    
    echo "$input"
}

# File size validation
validate_file_size() {
    local file_path="$1"
    local max_size_mb="${MAX_FILE_SIZE_MB:-500}"
    local max_size_bytes=$((max_size_mb * 1024 * 1024))
    
    if [ ! -f "$file_path" ]; then
        security_log "File does not exist: $file_path"
        return 1
    fi
    
    local file_size=$(stat -f%z "$file_path" 2>/dev/null || stat -c%s "$file_path" 2>/dev/null || echo 0)
    
    if [ "$file_size" -gt "$max_size_bytes" ]; then
        security_log "File too large: $file_size bytes (max: $max_size_bytes bytes)"
        return 1
    fi
    
    return 0
}

# Content type validation
validate_content_type() {
    local file_path="$1"
    local expected_type="$2"
    
    if ! command -v file &> /dev/null; then
        security_log "WARNING: 'file' command not available for content type validation"
        return 0
    fi
    
    local actual_type=$(file -b --mime-type "$file_path")
    
    case "$expected_type" in
        "video")
            if ! echo "$actual_type" | grep -q "^video/"; then
                security_log "Invalid video file type: $actual_type"
                return 1
            fi
            ;;
        "audio")
            if ! echo "$actual_type" | grep -q "^audio/"; then
                security_log "Invalid audio file type: $actual_type"
                return 1
            fi
            ;;
        "text")
            if ! echo "$actual_type" | grep -q "^text/"; then
                security_log "Invalid text file type: $actual_type"
                return 1
            fi
            ;;
        *)
            security_log "Unknown expected content type: $expected_type"
            return 1
            ;;
    esac
    
    return 0
}

# Secure temporary file creation
create_secure_temp_file() {
    local prefix="$1"
    local suffix="${2:-}"
    
    # Create with secure permissions
    local temp_file=$(mktemp "/tmp/${prefix}_XXXXXX${suffix}")
    chmod 600 "$temp_file"
    
    echo "$temp_file"
}

# Main security check function
security_check() {
    local operation="$1"
    local client_id="${2:-workflow}"
    
    # Create security log directory
    mkdir -p "$(dirname "$SECURITY_LOG")"
    
    # Check rate limit
    if ! check_rate_limit "$client_id"; then
        echo "Rate limit exceeded" >&2
        exit 1
    fi
    
    security_log "Security check passed for operation: $operation, client: $client_id"
    return 0
}

# Export functions for use in other scripts
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
    export -f security_log check_rate_limit validate_url sanitize_input
    export -f validate_file_size validate_content_type create_secure_temp_file security_check
fi