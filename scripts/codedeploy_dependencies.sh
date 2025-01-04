#!/bin/bash
set -e  # Exit immediately if a command fails
set -x  # Print commands and their arguments as they are executed

LOG_FILE="/var/log/codedeploy_dependencies.log"
APP_DIR="/var/www/myapp"
DEPLOY_ROOT="/opt/codedeploy-agent/deployment-root"

echo "Starting dependency installation..." >> "$LOG_FILE"

# Locate deployment archive dynamically
DEPLOY_DIR=$(find "$DEPLOY_ROOT" -type d -name "deployment-archive" | head -n 1)
if [ -z "$DEPLOY_DIR" ]; then
    echo "Error: Deployment directory (deployment-archive) not found under $DEPLOY_ROOT." >> "$LOG_FILE"
    exit 1
fi

APP_ZIP="$DEPLOY_DIR/app.zip"
echo "Resolved deployment directory: $DEPLOY_DIR" >> "$LOG_FILE"
echo "Resolved APP_ZIP path: $APP_ZIP" >> "$LOG_FILE"

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

# Verify Flask and Gunicorn installations
python3 -c "import flask" >> "$LOG_FILE" 2>&1 || { echo "Error: Flask module is not installed."; exit 1; }
if [ ! -f "$APP_DIR/venv/bin/gunicorn" ]; then
    echo "Error: Gunicorn is not installed correctly." >> "$LOG_FILE"
    exit 1
fi

deactivate
echo "Dependency installation completed successfully." >> "$LOG_FILE"
exit 0
