#!/bin/bash

LOG_FILE="/var/log/codedeploy_dependencies.log"
APP_DIR="/var/www/myapp"
APP_ZIP="$APP_DIR/app.zip"

echo "Starting dependency installation..." >> "$LOG_FILE"

# Ensure application directory exists
if [ ! -d "$APP_DIR" ]; then
    echo "Creating application directory: $APP_DIR" >> "$LOG_FILE"
    sudo mkdir -p "$APP_DIR"
fi
sudo chown -R ec2-user:ec2-user "$APP_DIR"
sudo chmod -R 755 "$APP_DIR"

# Verify the existence of app.zip
if [ ! -f "$APP_ZIP" ]; then
    echo "Error: app.zip not found at $APP_ZIP" >> "$LOG_FILE"
    exit 1
fi

# Extract application files
echo "Extracting application files from $APP_ZIP to $APP_DIR..." >> "$LOG_FILE"
sudo unzip -o "$APP_ZIP" -d "$APP_DIR" >> "$LOG_FILE" 2>&1 || { echo "Error: Failed to extract $APP_ZIP"; exit 1; }

# Setup and activate virtual environment
echo "Setting up virtual environment..." >> "$LOG_FILE"
if [ ! -d "$APP_DIR/venv" ]; then
    python3 -m venv "$APP_DIR/venv" >> "$LOG_FILE" 2>&1 || { echo "Error: Failed to create virtual environment"; exit 1; }
else
    echo "Virtual environment already exists. Skipping creation..." >> "$LOG_FILE"
fi
source "$APP_DIR/venv/bin/activate" || { echo "Error: Failed to activate virtual environment"; exit 1; }

# Upgrade pip
pip install --upgrade pip >> "$LOG_FILE" 2>&1 || { echo "Error: Failed to upgrade pip"; exit 1; }

# Install dependencies
REQ_FILE="$APP_DIR/requirements.txt"
if [ -s "$REQ_FILE" ]; then
    echo "Installing dependencies from $REQ_FILE..." >> "$LOG_FILE"
    pip install -r "$REQ_FILE" >> "$LOG_FILE" 2>&1 || { echo "Error: Failed to install dependencies"; exit 1; }
else
    echo "Error: requirements.txt is empty or missing" >> "$LOG_FILE"
    exit 1
fi

deactivate
echo "Dependency installation completed successfully." >> "$LOG_FILE"
exit 0
