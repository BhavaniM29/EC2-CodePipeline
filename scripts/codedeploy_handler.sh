#!/bin/bash
set -e
set -x

LOG_FILE="/var/log/codedeploy.log"
APP_DIR="/var/www/myapp"
DEPLOY_ROOT="/opt/codedeploy-agent/deployment-root"
LIFECYCLE_EVENT=$1

echo "Deployment started for event: $LIFECYCLE_EVENT" >> "$LOG_FILE"

if [ "$LIFECYCLE_EVENT" == "BeforeInstall" ]; then
    # Locate the latest deployment-archive path
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

    # Set up virtual environment
    echo "Setting up virtual environment..." >> "$LOG_FILE"
    if [ ! -d "$APP_DIR/venv" ]; then
        python3 -m venv "$APP_DIR/venv" >> "$LOG_FILE" || { echo "Error: Virtual environment creation failed"; exit 1; }
    fi

elif [ "$LIFECYCLE_EVENT" == "AfterInstall" ]; then
    # Activate virtual environment and install dependencies
    echo "Activating virtual environment and installing dependencies..." >> "$LOG_FILE"
    source "$APP_DIR/venv/bin/activate" || { echo "Error: Failed to activate virtual environment"; exit 1; }

    echo "Upgrading pip..." >> "$LOG_FILE"
    pip install --upgrade pip >> "$LOG_FILE"

    REQ_FILE="$APP_DIR/requirements.txt"
    if [ -f "$REQ_FILE" ]; then
        echo "Installing dependencies from $REQ_FILE..." >> "$LOG_FILE"
        pip install -r "$REQ_FILE" >> "$LOG_FILE" || { echo "Error: Failed to install dependencies"; deactivate; exit 1; }
    else
        echo "No requirements.txt found. Installing Flask and Gunicorn as fallback..." >> "$LOG_FILE"
        pip install flask gunicorn >> "$LOG_FILE" || { echo "Error: Failed to install Flask or Gunicorn"; deactivate; exit 1; }
    fi

    deactivate

    # Restart application
    echo "Restarting application..." >> "$LOG_FILE"
    APP_PID=$(lsof -ti :8080)
    [ -n "$APP_PID" ] && sudo kill -9 "$APP_PID"

    nohup python3 "$APP_DIR/app.py" >> "$LOG_FILE" 2>&1 &

    echo "Application started successfully on port 8080." >> "$LOG_FILE"
fi

echo "Deployment completed for event: $LIFECYCLE_EVENT" >> "$LOG_FILE"
exit 0
