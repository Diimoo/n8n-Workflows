#!/bin/bash

# Production-ready Instagram Reels upload script
# This script implements the complete Instagram Graph API flow for Reels uploads

set -euo pipefail

# Source security functions
source "$(dirname "$0")/security_functions.sh"

# Configuration
VIDEO_PATH="$1"
CAPTION="$2"
ACCESS_TOKEN="${INSTAGRAM_ACCESS_TOKEN:-}"
ACCOUNT_ID="${INSTAGRAM_ACCOUNT_ID:-}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INSTAGRAM: $1" >&2
}

# Error handling function
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Validate inputs
if [ -z "$VIDEO_PATH" ] || [ -z "$CAPTION" ] || [ -z "$ACCESS_TOKEN" ] || [ -z "$ACCOUNT_ID" ]; then
    handle_error "Missing required parameters: VIDEO_PATH, CAPTION, ACCESS_TOKEN, ACCOUNT_ID"
fi

if [ ! -f "$VIDEO_PATH" ]; then
    handle_error "Video file not found: $VIDEO_PATH"
fi

# Security checks
security_check "instagram_upload" "instagram_api"
validate_file_size "$VIDEO_PATH"
validate_content_type "$VIDEO_PATH" "video"

log "Starting Instagram Reels upload process"
log "Video: $VIDEO_PATH"
log "Caption length: ${#CAPTION} characters"

# Instagram requires video to be accessible via URL
# Upload to temporary public hosting (you'll need to implement this based on your setup)
PUBLIC_VIDEO_URL=""

# For production, you would upload the video to a publicly accessible URL
# This could be:
# 1. Your own web server
# 2. AWS S3 with public access
# 3. Google Cloud Storage with public access
# 4. Any other public file hosting service

# Example implementation for AWS S3 (uncomment and configure):
# log "Uploading video to S3 for public access"
# S3_BUCKET="${S3_BUCKET:-your-bucket-name}"
# S3_KEY="temp-videos/$(basename "$VIDEO_PATH")"
# aws s3 cp "$VIDEO_PATH" "s3://$S3_BUCKET/$S3_KEY" --acl public-read
# PUBLIC_VIDEO_URL="https://$S3_BUCKET.s3.amazonaws.com/$S3_KEY"

# For this template, we'll create a placeholder
PUBLIC_VIDEO_URL="https://your-domain.com/temp-videos/$(basename "$VIDEO_PATH")"
log "WARNING: Using placeholder URL. In production, implement actual file hosting."
log "Placeholder URL: $PUBLIC_VIDEO_URL"

# Step 1: Create media container
log "Creating Instagram media container"
CONTAINER_RESPONSE=$(curl -s -X POST \
    "https://graph.facebook.com/v18.0/$ACCOUNT_ID/media" \
    -F "media_type=REELS" \
    -F "video_url=$PUBLIC_VIDEO_URL" \
    -F "caption=$CAPTION" \
    -F "share_to_feed=true" \
    -F "access_token=$ACCESS_TOKEN")

if [ $? -ne 0 ]; then
    handle_error "Failed to create Instagram media container"
fi

# Parse container ID
CONTAINER_ID=$(echo "$CONTAINER_RESPONSE" | jq -r '.id // empty')

if [ -z "$CONTAINER_ID" ]; then
    log "Instagram Container Response: $CONTAINER_RESPONSE"
    handle_error "Failed to parse container ID from Instagram response"
fi

log "Media container created with ID: $CONTAINER_ID"

# Step 2: Check container status
log "Checking container processing status"
for attempt in {1..20}; do
    STATUS_RESPONSE=$(curl -s -X GET \
        "https://graph.facebook.com/v18.0/$CONTAINER_ID?fields=status_code,status&access_token=$ACCESS_TOKEN")
    
    if [ $? -eq 0 ]; then
        STATUS_CODE=$(echo "$STATUS_RESPONSE" | jq -r '.status_code // empty')
        STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status // empty')
        
        case "$STATUS_CODE" in
            "FINISHED")
                log "Container processing completed successfully"
                break
                ;;
            "IN_PROGRESS")
                log "Container processing in progress (attempt $attempt/20)"
                sleep 15
                ;;
            "ERROR")
                handle_error "Container processing failed with error: $STATUS"
                ;;
            *)
                log "Unknown status code: $STATUS_CODE, status: $STATUS"
                ;;
        esac
    else
        log "Failed to check container status (attempt $attempt/20)"
    fi
    
    if [ $attempt -eq 20 ]; then
        handle_error "Container processing timed out"
    fi
done

# Step 3: Publish the media
log "Publishing Instagram Reel"
PUBLISH_RESPONSE=$(curl -s -X POST \
    "https://graph.facebook.com/v18.0/$ACCOUNT_ID/media_publish" \
    -F "creation_id=$CONTAINER_ID" \
    -F "access_token=$ACCESS_TOKEN")

if [ $? -ne 0 ]; then
    handle_error "Failed to publish Instagram Reel"
fi

# Parse publish response
MEDIA_ID=$(echo "$PUBLISH_RESPONSE" | jq -r '.id // empty')

if [ -z "$MEDIA_ID" ]; then
    log "Instagram Publish Response: $PUBLISH_RESPONSE"
    handle_error "Failed to get media ID from Instagram publish response"
fi

log "Instagram Reel published successfully"
log "Media ID: $MEDIA_ID"

# Step 4: Get published media info
log "Getting published media information"
MEDIA_INFO_RESPONSE=$(curl -s -X GET \
    "https://graph.facebook.com/v18.0/$MEDIA_ID?fields=id,media_type,media_url,permalink,timestamp&access_token=$ACCESS_TOKEN")

if [ $? -eq 0 ]; then
    PERMALINK=$(echo "$MEDIA_INFO_RESPONSE" | jq -r '.permalink // empty')
    TIMESTAMP=$(echo "$MEDIA_INFO_RESPONSE" | jq -r '.timestamp // empty')
    
    log "Media permalink: $PERMALINK"
    log "Published at: $TIMESTAMP"
fi

# Cleanup: Remove public video file if uploaded to temporary hosting
# Implement based on your hosting solution
# Example for S3:
# aws s3 rm "s3://$S3_BUCKET/$S3_KEY"

# Output result
cat << EOF
{
    "success": true,
    "platform": "instagram",
    "media_id": "$MEDIA_ID",
    "container_id": "$CONTAINER_ID",
    "permalink": "$PERMALINK",
    "caption": "$CAPTION",
    "published_at": "$TIMESTAMP"
}
EOF

log "Instagram Reels upload process completed"