#!/bin/bash

# Production cleanup script for temporary files
# This script should be run periodically to clean up temporary files

set -euo pipefail

# Configuration
TEMP_DIR="/tmp"
LOG_FILE="/var/log/n8n_cleanup.log"
MAX_AGE_DAYS=1

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "Starting cleanup process"

# Clean up old TTS audio files
find "$TEMP_DIR" -name "tts_audio_*.wav" -mtime +$MAX_AGE_DAYS -type f -delete 2>/dev/null || true
log "Cleaned up old TTS audio files"

# Clean up old video segments
find "$TEMP_DIR" -name "video_segment_*.mp4" -mtime +$MAX_AGE_DAYS -type f -delete 2>/dev/null || true
log "Cleaned up old video segments"

# Clean up old final videos
find "$TEMP_DIR" -name "final_video_*.mp4" -mtime +$MAX_AGE_DAYS -type f -delete 2>/dev/null || true
log "Cleaned up old final videos"

# Clean up old SRT files
find "$TEMP_DIR" -name "subtitles_*.srt" -mtime +$MAX_AGE_DAYS -type f -delete 2>/dev/null || true
log "Cleaned up old SRT files"

# Clean up old stock video downloads
find "$TEMP_DIR" -name "temp_stock_video_*.mp4" -mtime +$MAX_AGE_DAYS -type f -delete 2>/dev/null || true
log "Cleaned up old stock video downloads"

# Report disk usage
DISK_USAGE=$(df -h "$TEMP_DIR" | awk 'NR==2 {print $5}')
log "Temp directory disk usage: $DISK_USAGE"

log "Cleanup process completed"