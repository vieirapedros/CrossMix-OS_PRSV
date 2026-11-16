#!/bin/sh
# Update CrossMix-OS from the latest GitHub release.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "${SCRIPT_DIR}/../../lib/crossmix-env.sh"
. "${SCRIPT_DIR}/../../lib/device.sh"
. "${CROSSMIX_SYSTEM_DIR}/usr/trimui/etc/crossmix-update.conf"

DOWNLOAD_DIR="${CROSSMIX_SDCARD}/.update-cache"
BACKUP_DIR="${CROSSMIX_SDCARD}/Backups/pre-update-$(date '+%Y%m%d-%H%M%S')"

mkdir -p "$DOWNLOAD_DIR" "$BACKUP_DIR"

fetch() {
    url="$1"
    destination="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -L --fail --connect-timeout "$CROSSMIX_UPDATE_TIMEOUT" -o "$destination" "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -T "$CROSSMIX_UPDATE_TIMEOUT" -O "$destination" "$url"
    else
        log_error "Neither curl nor wget is available"
        return 1
    fi
}

log_info "Checking for CrossMix updates"

RELEASE_JSON="${DOWNLOAD_DIR}/latest-release.json"
fetch "$CROSSMIX_UPDATE_API" "$RELEASE_JSON" || {
    log_error "Unable to reach GitHub or no network connection"
    exit 1
}

PACKAGE_URL=$(sed -n 's/.*"browser_download_url": "\([^"]*\)".*/\1/p' "$RELEASE_JSON" | grep "${CROSSMIX_UPDATE_PACKAGE_PREFIX}" | head -n 1)

if [ -z "$PACKAGE_URL" ]; then
    log_error "No CrossMix update package found in the latest release"
    exit 1
fi

PACKAGE_NAME=$(basename "$PACKAGE_URL")
PACKAGE_FILE="${DOWNLOAD_DIR}/${PACKAGE_NAME}"
CHECKSUM_FILE="${PACKAGE_FILE}.sha256"
CHECKSUM_URL="${PACKAGE_URL}.sha256"

log_info "Downloading update package: $PACKAGE_NAME"
fetch "$PACKAGE_URL" "$PACKAGE_FILE" || {
    log_error "Failed to download $PACKAGE_URL"
    exit 1
}

fetch "$CHECKSUM_URL" "$CHECKSUM_FILE" || {
    log_error "Failed to download checksum file $CHECKSUM_URL"
    exit 1
}

EXPECTED_SHA256=$(cut -d' ' -f1 "$CHECKSUM_FILE")
ACTUAL_SHA256=$(sha256sum "$PACKAGE_FILE" | cut -d' ' -f1)

if [ "$EXPECTED_SHA256" != "$ACTUAL_SHA256" ]; then
    log_error "Checksum mismatch for $PACKAGE_NAME"
    rm -f "$PACKAGE_FILE" "$CHECKSUM_FILE"
    exit 1
fi

log_info "Checksum verified for $PACKAGE_NAME"

if [ -d "${CROSSMIX_SDCARD}/Data" ]; then
    tar -czf "${BACKUP_DIR}/crossmix-data.tar.gz" \
        -C "${CROSSMIX_SDCARD}" Data \
        2>>"${CROSSMIX_LOG_DIR}/crossmix.log"
fi

if [ -d "${CROSSMIX_SDCARD}/RetroArch/config" ]; then
    tar -czf "${BACKUP_DIR}/retroarch-config.tar.gz" \
        -C "${CROSSMIX_SDCARD}/RetroArch" config \
        2>>"${CROSSMIX_LOG_DIR}/crossmix.log"
fi

log_info "Applying update package: $PACKAGE_NAME"
tar -xzf "$PACKAGE_FILE" -C "$CROSSMIX_SDCARD" \
    2>>"${CROSSMIX_LOG_DIR}/crossmix.log"

if [ $? -ne 0 ]; then
    log_error "Failed to apply update package $PACKAGE_NAME"
    exit 1
fi

rm -f "$PACKAGE_FILE" "$CHECKSUM_FILE" "$RELEASE_JSON"
log_info "CrossMix update applied successfully: $PACKAGE_NAME"
printf 'CrossMix update applied successfully.\n'
