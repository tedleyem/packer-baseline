#!/bin/bash
# Quick command to use packer to build out specific images based on flags 
usage() {
    echo "Usage: $0 [--ubuntu | --rhel | --dsl | --debian]"
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

# Parse the flags 
case "$1" in
    --ubuntu)
        DISTRO="ubuntu"
        ;;
    --rhel)
        DISTRO="rhel-9"
        ;;
    --rhel-9)
        DISTRO="rhel-9"
        ;;
    --rhel-10)
        DISTRO="rhel-10"
        ;;
    --dsl)
        DISTRO="dsl"
        ;;
    --debian)
        DISTRO="debian"
        ;;
    *)
        echo "Error: Invalid option '$1'"
        usage
        ;;
esac

# required variables 
PKR_FILE="baseline-${DISTRO}.pkr.hcl"
DEST_PATH="output-iso/${DISTRO}/"

# check if packer file exists
if [ ! -f "$PKR_FILE" ]; then
    echo "Error: File $PKR_FILE not found in the current directory."
    exit 1
fi

echo "Building $DISTRO image..."
echo "Target: $DEST_PATH"

# run the Packer build
PACKER_LOG=1 packer build -var "destination_path=${DEST_PATH}" "$PKR_FILE"