#!/bin/bash

LOG_FILE="/var/log/codedeploy_dependencies.log"
APP_DIR="/var/www/myapp"

echo "Starting deployment process..." >> "$LOG_FILE"

# Ensure proper permissions
sudo chown -R ec2-user:ec2-user "$APP_DIR"
sudo chmod -R 755 "$APP_DIR"

# Restart application
echo "Restarting application..." >> "$LOG_FILE"
APP_PID=$(lsof -ti :8080)
if [ -n "$APP_PID" ]; then
    sudo kill -9 "$APP_PID"
fi
nohup python3 "$APP_DIR/app.py" >> "$LOG_FILE" 2>&1 &

echo "Deployment completed successfully." >> "$LOG_FILE"
exit 0
