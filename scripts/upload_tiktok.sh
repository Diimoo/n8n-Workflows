#!/bin/bash

# Production-ready TikTok upload script
# This script implements the complete TikTok API flow for video uploads

set -euo pipefail

# Source security functions
source "$(dirname "$0")/security_functions.sh"

# Configuration
VIDEO_PATH="$1"
TITLE="$2"
DESCRIPTION="$3"
ACCESS_TOKEN="${TIKTOK_ACCESS_TOKEN:-}"
CLIENT_KEY="${TIKTOK_CLIENT_KEY:-}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] TIKTOK: $1" >&2
}

# Error handling function
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Validate inputs
if [ -z "$VIDEO_PATH" ] || [ -z "$TITLE" ] || [ -z "$ACCESS_TOKEN" ]; then
    handle_error "Missing required parameters: VIDEO_PATH, TITLE, ACCESS_TOKEN"
fi

if [ ! -f "$VIDEO_PATH" ]; then
    handle_error "Video file not found: $VIDEO_PATH"
fi

# Security checks
security_check "tiktok_upload" "tiktok_api"
validate_file_size "$VIDEO_PATH"
validate_content_type "$VIDEO_PATH" "video"

log "Starting TikTok upload process"
log "Video: $VIDEO_PATH"
log "Title: $TITLE"

# Step 1: Get upload URL from TikTok API
log "Requesting upload URL from TikTok"
UPLOAD_RESPONSE=$(curl -s -X POST \
    "https://open.tiktokapis.com/v2/video/upload/" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"source_info\": {
            \"source\": \"FILE_UPLOAD\"
        }
    }")

if [ $? -ne 0 ]; then
    handle_error "Failed to get upload URL from TikTok API"
fi

# Parse response
UPLOAD_URL=$(echo "$UPLOAD_RESPONSE" | jq -r '.data.upload_url // empty')
VIDEO_ID=$(echo "$UPLOAD_RESPONSE" | jq -r '.data.video_id // empty')

if [ -z "$UPLOAD_URL" ] || [ -z "$VIDEO_ID" ]; then
    log "TikTok API Response: $UPLOAD_RESPONSE"
    handle_error "Failed to parse upload URL or video ID from TikTok response"
fi

log "Received upload URL and video ID: $VIDEO_ID"

# Step 2: Upload video file
log "Uploading video file to TikTok"
UPLOAD_FILE_RESPONSE=$(curl -s -X POST \
    "$UPLOAD_URL" \
    -F "video=@$VIDEO_PATH" \
    -H "Authorization: Bearer $ACCESS_TOKEN")

if [ $? -ne 0 ]; then
    handle_error "Failed to upload video file to TikTok"
fi

log "Video file uploaded successfully"

# Step 3: Publish the video
log "Publishing video on TikTok"
PUBLISH_RESPONSE=$(curl -s -X POST \
    "https://open.tiktokapis.com/v2/video/publish/" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{
        \"video_id\": \"$VIDEO_ID\",
        \"post_info\": {
            \"title\": \"$TITLE\",
            \"description\": \"$DESCRIPTION\",
            \"privacy_level\": \"PUBLIC_TO_EVERYONE\",
            \"disable_duet\": false,
            \"disable_comment\": false,
            \"disable_stitch\": false,
            \"video_cover_timestamp_ms\": 1000
        },
        \"source_info\": {
            \"source\": \"FILE_UPLOAD\"
        }
    }")

if [ $? -ne 0 ]; then
    handle_error "Failed to publish video on TikTok"
fi

# Parse publish response
PUBLISH_ID=$(echo "$PUBLISH_RESPONSE" | jq -r '.data.publish_id // empty')
STATUS=$(echo "$PUBLISH_RESPONSE" | jq -r '.data.status // empty')

if [ -z "$PUBLISH_ID" ]; then
    log "TikTok Publish Response: $PUBLISH_RESPONSE"
    handle_error "Failed to get publish ID from TikTok response"
fi

log "Video published successfully"
log "Publish ID: $PUBLISH_ID"
log "Status: $STATUS"

# Step 4: Check upload status (optional)
log "Checking upload status"
for attempt in {1..10}; do
    STATUS_RESPONSE=$(curl -s -X GET \
        "https://open.tiktokapis.com/v2/video/list/?fields=id,title,status&video_id=$VIDEO_ID" \
        -H "Authorization: Bearer $ACCESS_TOKEN")
    
    if [ $? -eq 0 ]; then
        VIDEO_STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.data.videos[0].status // empty')
        
        case "$VIDEO_STATUS" in
            "PROCESSING")
                log "Video is processing (attempt $attempt/10)"
                sleep 10
                ;;
            "READY")
                log "Video processing completed successfully"
                break
                ;;
            "FAILED")
                handle_error "Video processing failed on TikTok"
                ;;
            *)
                log "Unknown video status: $VIDEO_STATUS"
                ;;
        esac
    else
        log "Failed to check video status (attempt $attempt/10)"
    fi
    
    if [ $attempt -eq 10 ]; then
        log "WARNING: Status check timed out, but upload may have succeeded"
    fi
done

# Output result
cat << EOF
{
    "success": true,
    "platform": "tiktok",
    "video_id": "$VIDEO_ID",
    "publish_id": "$PUBLISH_ID",
    "status": "$VIDEO_STATUS",
    "title": "$TITLE",
    "uploaded_at": "$(date -Iseconds)"
}
EOF

log "TikTok upload process completed"