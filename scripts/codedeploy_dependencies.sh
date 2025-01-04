#!/bin/bash

LOG_FILE="/var/log/codedeploy_dependencies.log"
APP_DIR="/var/www/myapp"
DEPLOY_ROOT="/opt/codedeploy-agent/deployment-root"
PORT=8080

echo "Starting dependency installation..." >> "$LOG_FILE"

# Ensure the application directory exists with correct permissions
if [ ! -d "$APP_DIR" ]; then
    echo "Creating application directory: $APP_DIR" >> "$LOG_FILE"
    sudo mkdir -p "$APP_DIR"
fi
sudo chown -R ec2-user:ec2-user "$APP_DIR"
sudo chmod -R 755 "$APP_DIR"

# Check if the port is in use and stop the process
PID=$(sudo lsof -t -i:$PORT)
if [ -n "$PID" ]; then
    echo "Port $PORT is in use by PID $PID. Stopping the process..." >> "$LOG_FILE"
    sudo kill -9 $PID
fi

# Locate and validate deployment archive
APP_ZIP="$DEPLOY_ROOT/deployment-archive/app.zip"
if [ ! -f "$APP_ZIP" ]; then
    echo "Error: app.zip not found at $APP_ZIP." >> "$LOG_FILE"
    exit 1
fi

# Extract application files
echo "Extracting application files from $APP_ZIP to $APP_DIR..." >> "$LOG_FILE"
sudo unzip -o "$APP_ZIP" -d "$APP_DIR" >> "$LOG_FILE" 2>&1

# Setup and activate virtual environment
echo "Setting up virtual environment..." >> "$LOG_FILE"
if [ ! -d "$APP_DIR/venv" ]; then
    python3 -m venv "$APP_DIR/venv" >> "$LOG_FILE" 2>&1
fi
source "$APP_DIR/venv/bin/activate"

# Upgrade pip and install dependencies
echo "Installing dependencies..." >> "$LOG_FILE"
pip install --upgrade pip >> "$LOG_FILE" 2>&1
REQ_FILE="$APP_DIR/requirements.txt"
if [ -f "$REQ_FILE" ]; then
    pip install -r "$REQ_FILE" >> "$LOG_FILE" 2>&1
else
    echo "No requirements.txt found. Installing Flask as fallback..." >> "$LOG_FILE"
    pip install flask >> "$LOG_FILE" 2>&1
fi

deactivate
echo "Dependency installation completed." >> "$LOG_FILE"
exit 0
