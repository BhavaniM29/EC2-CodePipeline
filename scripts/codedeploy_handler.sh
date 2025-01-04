#!/bin/bash
set -e
set -x

LOG_FILE="/var/log/codedeploy.log"
APP_DIR="/var/www/myapp"
DEPLOY_ROOT="/opt/codedeploy-agent/deployment-root"
LIFECYCLE_EVENT=$1

echo "Deployment started for event: $LIFECYCLE_EVENT" >> "$LOG_FILE"

if [ "$LIFECYCLE_EVENT" == "BeforeInstall" ]; then
    # Locate the latest deployment-archive path based on modification time
    DEPLOY_DIR=$(find "$DEPLOY_ROOT" -type d -name "deployment-archive" -exec stat --format '%Y %n' {} + | sort -nr | head -n 1 | awk '{print $2}')
    if [ -z "$DEPLOY_DIR" ]; then
        echo "Error: Deployment directory not found" >> "$LOG_FILE"
        exit 1
    fi
    APP_ZIP="$DEPLOY_DIR/app.zip"

    echo "Located latest deployment directory: $DEPLOY_DIR" >> "$LOG_FILE"

    # Ensure application directory exists and clean it
    echo "Clearing old application files..." >> "$LOG_FILE"
    sudo rm -rf "$APP_DIR"/*
    sudo mkdir -p "$APP_DIR"
    sudo chown -R ec2-user:ec2-user "$APP_DIR"
    sudo chmod -R 755 "$APP_DIR"

    # Extract application files
    if [ -f "$APP_ZIP" ]; then
        echo "Extracting $APP_ZIP to $APP_DIR..." >> "$LOG_FILE"
        sudo unzip -o "$APP_ZIP" -d "$APP_DIR" >> "$LOG_FILE" || { echo "Error: Extraction failed"; exit 1; }
    else
        echo "Error: app.zip not found at $APP_ZIP" >> "$LOG_FILE"
        exit 1
    fi

    echo "BeforeInstall completed successfully." >> "$LOG_FILE"

elif [ "$LIFECYCLE_EVENT" == "AfterInstall" ]; then
    echo "Restarting application..." >> "$LOG_FILE"
    APP_PID=$(lsof -ti :8080)
    [ -n "$APP_PID" ] && sudo kill -9 "$APP_PID"

    source "$APP_DIR/venv/bin/activate"
    nohup python3 "$APP_DIR/app.py" >> "$LOG_FILE" 2>&1 &
    deactivate

    echo "Application started successfully on port 8080." >> "$LOG_FILE"
fi

echo "Deployment completed for event: $LIFECYCLE_EVENT" >> "$LOG_FILE"
exit 0
