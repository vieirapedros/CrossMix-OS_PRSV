#!/bin/sh
# Device scope for this CrossMix-OS fork.

CROSSMIX_DEVICE="trimui_smart_pro"
CROSSMIX_DEVICE_NAME="TrimUI Smart Pro"

assert_supported_device() {
    if [ "${CROSSMIX_DEVICE}" != "trimui_smart_pro" ]; then
        log_error "Unsupported device: ${CROSSMIX_DEVICE}"
        return 1
    fi
}
