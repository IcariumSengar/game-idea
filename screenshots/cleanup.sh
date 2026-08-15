#!/bin/bash
# Cleanup script for screenshots older than 7 days (macOS/Linux)
# Usage: ./cleanup.sh

DAYSOLD=7
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Cleaning up screenshots older than $DAYSOLD days in $SCRIPT_DIR..."

# Find and delete PNG and JPG files older than 7 days
find "$SCRIPT_DIR" -maxdepth 1 \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" \) -mtime +$DAYSOLD -delete

echo "Cleanup complete: removed files older than $DAYSOLD days"
