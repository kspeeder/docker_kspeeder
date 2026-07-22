#!/bin/sh

PLATFORM=$1
if [ -z "$PLATFORM" ]; then
    KSPEEDER_FILE="iStoreEnhance-linux.amd64"
else
    case "$PLATFORM" in
        linux/amd64)
            KSPEEDER_FILE="iStoreEnhance-linux.amd64"
            ;;
        linux/arm/v6|linux/arm/v7)
            KSPEEDER_FILE="iStoreEnhance-linux.arm"
            ;;
        linux/arm64|linux/arm64/v8)
            KSPEEDER_FILE="iStoreEnhance-linux.arm64"
            ;;
        *)
            KSPEEDER_FILE=""
            ;;
    esac
fi
[ -z "${KSPEEDER_FILE}" ] && echo "Error: Not supported OS Architecture" && exit 1
[ ! -f "/dest/${KSPEEDER_FILE}" ] && echo "Error: Missing /dest/${KSPEEDER_FILE}" && exit 1

cp /dest/${KSPEEDER_FILE} /usr/bin/kspeeder

chmod +x /usr/bin/kspeeder
