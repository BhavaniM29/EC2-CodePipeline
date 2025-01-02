#!/bin/bash

LOG_FILE="/var/log/codedeploy_dependencies.log"
APP_DIR="/var/www/myapp"
DEPLOY_ROOT="/opt/codedeploy-agent/deployment-root"

echo "Starting deployment process..." >> "$LOG_FILE"

# Locate deployment-archive
DEPLOY_DIR=$(find "$DEPLOY_ROOT" -type d -name "deployment-archive" | head -n 1)
if [ -z "$DEPLOY_DIR" ]; then
    echo "Error: Deployment directory (deployment-archive) not found under $DEPLOY_ROOT." >> "$LOG_FILE"
    exit 1
fi

APP_ZIP="$DEPLOY_DIR/app.zip"

# Cleanup target application directory
if [ -d "$APP_DIR" ]; then
    echo "Clearing old files in $APP_DIR..." >> "$LOG_FILE"
    sudo rm -rf "$APP_DIR"/* >> "$LOG_FILE" 2>&1
else
    echo "Creating application directory: $APP_DIR" >> "$LOG_FILE"
    sudo mkdir -p "$APP_DIR"
    sudo chown ec2-user:ec2-user "$APP_DIR"
    sudo chmod 755 "$APP_DIR"
fi

# Extract application zip
if [ -f "$APP_ZIP" ]; then
    echo "Extracting application files from $APP_ZIP to $APP_DIR..." >> "$LOG_FILE"
    sudo unzip -o "$APP_ZIP" -d "$APP_DIR" >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to extract $APP_ZIP to $APP_DIR." >> "$LOG_FILE"
        exit 1
    fi
else
    echo "Error: app.zip not found at $APP_ZIP." >> "$LOG_FILE"
    exit 1
fi

echo "Application deployed successfully to $APP_DIR." >> "$LOG_FILE"
exit 0
