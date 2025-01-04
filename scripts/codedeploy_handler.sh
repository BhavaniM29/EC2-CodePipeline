#!/bin/bash
set -e  # Exit immediately if a command fails
set -x  # Print commands and their arguments as they are executed

LOG_FILE="/var/log/codedeploy.log"
APP_DIR="/var/www/myapp"
DEPLOY_ROOT="/opt/codedeploy-agent/deployment-root"
LIFECYCLE_EVENT=$1

echo "Deployment started for event: $LIFECYCLE_EVENT" >> "$LOG_FILE"

if [ "$LIFECYCLE_EVENT" == "BeforeInstall" ]; then
    # Locate deployment archive dynamically
    DEPLOY_DIR=$(find "$DEPLOY_ROOT" -type d -name "deployment-archive" | head -n 1)
    if [ -z "$DEPLOY_DIR" ]; then
        echo "Error: Deployment directory not found" >> "$LOG_FILE"
        exit 1
    fi
    APP_ZIP="$DEPLOY_DIR/app.zip"

    # Ensure application directory exists
    [ ! -d "$APP_DIR" ] && sudo mkdir -p "$APP_DIR"
    sudo chown -R ec2-user:ec2-user "$APP_DIR"
    sudo chmod -R 755 "$APP_DIR"

    # Extract application files
    if [ -f "$APP_ZIP" ]; then
        sudo unzip -o "$APP_ZIP" -d "$APP_DIR" >> "$LOG_FILE"
    else
        echo "Error: app.zip not found" >> "$LOG_FILE"
        exit 1
    fi

    # Set up virtual environment
    if [ ! -d "$APP_DIR/venv" ]; then
        python3 -m venv "$APP_DIR/venv" >> "$LOG_FILE" || { echo "Error: Virtual environment creation failed"; exit 1; }
    fi
    source "$APP_DIR/venv/bin/activate"

    # Upgrade pip and install dependencies
    pip install --upgrade pip >> "$LOG_FILE"
    if [ -s "$APP_DIR/requirements.txt" ]; then
        pip install -r "$APP_DIR/requirements.txt" >> "$LOG_FILE"
    fi
    deactivate

    echo "BeforeInstall completed successfully." >> "$LOG_FILE"

elif [ "$LIFECYCLE_EVENT" == "AfterInstall" ]; then
    # Restart application
    echo "Restarting application..." >> "$LOG_FILE"
    APP_PID=$(lsof -ti :8080)
    [ -n "$APP_PID" ] && sudo kill -9 "$APP_PID"

    nohup python3 "$APP_DIR/app.py" >> "$LOG_FILE" 2>&1 &
    echo "Application started successfully on port 8080." >> "$LOG_FILE"
fi

echo "Deployment completed for event: $LIFECYCLE_EVENT" >> "$LOG_FILE"
exit 0
