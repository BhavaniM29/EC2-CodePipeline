#!/bin/bash

LOG_FILE="/var/log/codedeploy_dependencies.log"
APP_DIR="/var/www/myapp"
DEPLOY_ROOT="/opt/codedeploy-agent/deployment-root"
PORT=8080

echo "Starting dependency installation..." >> "$LOG_FILE"

# Check if the port is in use and stop the process
PID=$(sudo lsof -t -i:$PORT)
if [ -n "$PID" ]; then
    echo "Port $PORT is in use by PID $PID. Stopping the process..." >> "$LOG_FILE"
    sudo kill -9 $PID
fi

# Locate deployment-archive
DEPLOY_DIR=$(find "$DEPLOY_ROOT" -type d -name "deployment-archive" | head -n 1)
if [ -z "$DEPLOY_DIR" ]; then
    echo "Error: Deployment directory (deployment-archive) not found under $DEPLOY_ROOT." >> "$LOG_FILE"
    exit 1
fi

APP_ZIP="$DEPLOY_DIR/app.zip"

# Cleanup application directory
if [ -d "$APP_DIR" ]; then
    echo "Clearing existing files in $APP_DIR..." >> "$LOG_FILE"
    sudo rm -rf "$APP_DIR"/*
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
else
    echo "Error: app.zip not found at $APP_ZIP." >> "$LOG_FILE"
    exit 1
fi

# Setup and activate virtual environment
echo "Setting up virtual environment..." >> "$LOG_FILE"
if [ ! -d "$APP_DIR/venv" ]; then
    python3 -m venv "$APP_DIR/venv" >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create virtual environment." >> "$LOG_FILE"
        exit 1
    fi
fi

source "$APP_DIR/venv/bin/activate"
if [ $? -ne 0 ]; then
    echo "Error: Failed to activate virtual environment." >> "$LOG_FILE"
    exit 1
fi

# Upgrade pip
echo "Upgrading pip..." >> "$LOG_FILE"
pip install --upgrade pip >> "$LOG_FILE" 2>&1

# Install dependencies
REQ_FILE="$APP_DIR/requirements.txt"
if [ -f "$REQ_FILE" ]; then
    echo "Installing dependencies from $REQ_FILE..." >> "$LOG_FILE"
    pip install -r "$REQ_FILE" >> "$LOG_FILE" 2>&1
    if [ $? -ne 0 ]; then
        echo "Error: Failed to install dependencies." >> "$LOG_FILE"
        deactivate
        exit 1
    fi
else
    echo "No requirements.txt found. Installing fallback dependencies..." >> "$LOG_FILE"
    pip install flask gunicorn >> "$LOG_FILE" 2>&1
fi

echo "Dependency installation completed successfully." >> "$LOG_FILE"
deactivate
exit 0
