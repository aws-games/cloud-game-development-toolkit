#!/bin/bash

# Define logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_message "Starting license file watch process for filename: ${license_server_name}.zip"

# Cleanup function for background processes
cleanup() {
    kill $(jobs -p) 2>/dev/null
}
trap cleanup EXIT

# Function to refresh the s3fs mount
refresh_s3fs_mount() {
    ls -la /mnt/s3 > /dev/null 2>&1
}

# Function to process the license file
process_license_file() {
    log_message "License file detected, starting import..."

    # Copy to local directory
    log_message "Copying file from S3 to local directory..."
    if ! cp /mnt/s3/${license_server_name}.zip /opt/UnityLicensingServer/; then
        log_message "Failed to copy file from S3"
        return 1
    fi

    # Verify file was copied
    log_message "Verifying copied file..."
    if [ ! -f "/opt/UnityLicensingServer/${license_server_name}.zip" ]; then
        log_message "File not found in local directory after copy"
        return 1
    fi

    # Run the import script and capture output
    log_message "Running import script..."
    cd /opt/UnityLicensingServer
    OUTPUT=$(./daemon_setup_expect.exp 2>&1)
    IMPORT_STATUS=$?

    # Capture all relevant logs
    {
        log_message "--- Import Execution Output ---"
        echo "$OUTPUT"
        log_message "--- Unity Import Log ---"
        cat /tmp/unity_import.log
        log_message "--- Current Directory Contents ---"
        ls -la
    } >> /tmp/import_debug.log

    # Check for timeout or specific error conditions
    if [ $IMPORT_STATUS -eq 2 ] || echo "$OUTPUT" | grep -q "TIMEOUT_ERROR"; then
        log_message "Import timed out"
        IMPORT_STATUS=1
    elif echo "$OUTPUT" | grep -q "UNEXPECTED_EOF"; then
        log_message "Import ended unexpectedly"
        IMPORT_STATUS=1
    fi

    # Verify success condition
    if [ $IMPORT_STATUS -eq 0 ] && echo "$OUTPUT" | grep -q "IMPORT_SUCCESSFUL"; then
        log_message "License import successful"

        # Restart the Unity License Server
        log_message "Restarting Unity License Server..."
        sudo systemctl restart unity-license-server

        # Move the processed file to a 'processed' folder
        mkdir -p /mnt/s3/processed
        mv /mnt/s3/${license_server_name}.zip /mnt/s3/processed/${license_server_name}.zip.$(date +%Y%m%d_%H%M%S)

        # Copy debug logs to S3
        cp /tmp/import_debug.log /mnt/s3/processed/import_debug.$(date +%Y%m%d_%H%M%S).log

        # Create success flag file
        log_message "Import completed successfully and server restarted at $(date)" > /mnt/s3/import_success.txt

        # Stop the watch service
        sudo systemctl stop unity-license-watch
        return 0
    else
        log_message "License import failed"
        # Move the file to a 'failed' folder
        mkdir -p /mnt/s3/failed
        mv /mnt/s3/${license_server_name}.zip /mnt/s3/failed/${license_server_name}.zip.$(date +%Y%m%d_%H%M%S)

        # Copy debug logs to S3
        cp /tmp/import_debug.log /mnt/s3/failed/import_debug.$(date +%Y%m%d_%H%M%S).log

        # Create error flag file
        log_message "Import failed at $(date). Exit code: $IMPORT_STATUS" > /mnt/s3/import_error.txt
        return 1
    fi
}

# Initial refresh of the mount
refresh_s3fs_mount

# Main watch loop combining inotify and periodic checks
(
    # Watch for file system events
    inotifywait -m -e create,moved_to /mnt/s3 &
    INOTIFY_PID=$!

    while true; do
        # Refresh the mount before checking
        refresh_s3fs_mount

        # Check if file exists (periodic check)
        if [ -f "/mnt/s3/${license_server_name}.zip" ]; then
            log_message "File found through periodic check"
            process_license_file
            if [ $? -eq 0 ]; then
                kill $INOTIFY_PID
                exit 0
            fi
        fi

        sleep 10
    done
) &

# Wait for either inotify events or periodic checks
while read -r directory events filename; do
    log_message "Event '$events' detected on file: $filename"

    # Refresh the mount when an event is detected
    refresh_s3fs_mount

    if [ "$filename" = "${license_server_name}.zip" ]; then
        log_message "Target file detected through inotify"
        process_license_file
        if [ $? -eq 0 ]; then
            exit 0
        fi
    fi
done < <(inotifywait -m -e create,moved_to /mnt/s3)
