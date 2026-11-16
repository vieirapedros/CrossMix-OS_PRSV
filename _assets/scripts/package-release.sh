#!/usr/bin/env bash
# Create a CrossMix-OS Smart Pro release package and SHA-256 checksum.
# Run this on a Linux PC, NAS or CI runner — not on the TrimUI console.

set -euo pipefail

usage() {
    echo "Usage: $0 <source-directory> <version> [output-directory]"
    echo "Example: $0 /home/user/CrossMix-OS 1.0.1 /home/user/releases"
}

if [[ $# -lt 2 || $# -gt 3 ]]; then
    usage
    exit 1
fi

SOURCE_DIR=$(realpath "$1")
VERSION="$2"
OUTPUT_DIR=${3:-$(pwd)}

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "Source directory not found: $SOURCE_DIR" >&2
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR=$(realpath "$OUTPUT_DIR")

PACKAGE_NAME="crossmix-smart-pro-${VERSION}.tar.gz"
PACKAGE_PATH="${OUTPUT_DIR}/${PACKAGE_NAME}"
CHECKSUM_PATH="${PACKAGE_PATH}.sha256"

EXCLUDES=(
    --exclude='./.git'
    --exclude='./.github'
    --exclude='./.Trash'
    --exclude='./Backups'
    --exclude='./Logs'
    --exclude='./Roms'
    --exclude='./.update-cache'
)

echo "Creating package: $PACKAGE_PATH"
tar -czf "$PACKAGE_PATH" \
    -C "$SOURCE_DIR" \
    "${EXCLUDES[@]}" \
    .

echo "Creating checksum: $CHECKSUM_PATH"
sha256sum "$PACKAGE_PATH" | awk '{print $1 "  " $2}' > "$CHECKSUM_PATH"

echo "Release package created successfully."
echo "Package: $PACKAGE_PATH"
echo "Checksum: $CHECKSUM_PATH"
