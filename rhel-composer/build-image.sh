#!/bin/bash
set -e

# Configuration
BLUEPRINT="rhel-baseline.toml"
NAME="rhel-baseline"
DISTRO="rhel-9"
IMAGE_TYPE="qcow2"

echo "Starting composer-server container..."
docker-compose up -d composer-server

echo "Waiting for service socket to become available..."
until docker-compose exec -T composer-server ls /run/weldr/api.socket >/dev/null 2>&1; do
  sleep 2
done

echo "Pushing blueprint: $BLUEPRINT"
docker-compose run --rm composer-cli blueprints push "$BLUEPRINT"

echo "Starting $DISTRO $IMAGE_TYPE build..."
# Capture the UUID from the command output
BUILD_ID=$(docker-compose run --rm composer-cli compose start "$NAME" "$IMAGE_TYPE" --distro "$DISTRO" | awk '{print $2}')

if [ -z "$BUILD_ID" ]; then
    echo "Error: Failed to start the compose process."
    exit 1
fi

echo "Build started with ID: $BUILD_ID"
echo "Monitoring status (Press Ctrl+C to exit monitor; build will continue in background)"

while true; do
    STATUS=$(docker-compose run --rm composer-cli compose status | grep "$BUILD_ID" | awk '{print $2}')
    TIME=$(date +%Y-%m-%d\ %H:%M:%S)
    
    echo "[$TIME] Current Status: $STATUS"
    
    if [ "$STATUS" == "FINISHED" ]; then
        echo "Build completed successfully."
        break
    elif [ "$STATUS" == "FAILED" ]; then
        echo "Build failed. Check 'composer-cli compose log $BUILD_ID' for details."
        exit 1
    fi
    sleep 30
done

echo "Process finished. Image file is located in the ./output directory."