#!/bin/sh

set -eu

VERSION="${VERSION:-${KSPEEDER_VERSION:-}}"
DEST_DIR="${DEST_DIR:-dest}"

if [ -z "$VERSION" ]; then
  echo "VERSION is required, for example: VERSION=0.7.14 ./prepare-dl.sh" >&2
  exit 1
fi

VERSION="${VERSION#v}"
BASE_URL="${KSPEEDER_BIN_BASE_URL:-https://github.com/kspeeder/docker_kspeeder/releases/download/v${VERSION}}"
BASE_URL="${BASE_URL%/}"
VERSION_FILE="${DEST_DIR}/version.txt"

if [ -z "$DEST_DIR" ] || [ "$DEST_DIR" = "/" ]; then
  echo "Invalid DEST_DIR: ${DEST_DIR}" >&2
  exit 1
fi

download() {
  url="$1"
  output="$2"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$output"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$output" "$url"
  else
    echo "curl or wget is required" >&2
    exit 1
  fi
}

read_var() {
  key="$1"
  awk -F= -v key="$key" '$1 == key { print $2; exit }' "$VERSION_FILE" | tr -d '\r'
}

verify_sha256() {
  file="$1"
  expected="$2"

  if [ -z "$expected" ]; then
    echo "Missing sha256 for ${file}" >&2
    exit 1
  fi

  printf '%s  %s\n' "$expected" "${DEST_DIR}/${file}" | sha256sum -c -
}

rm -rf "$DEST_DIR"
mkdir -p "$DEST_DIR"

download "${BASE_URL}/version.txt" "$VERSION_FILE"

REMOTE_VERSION="$(read_var VERSION)"
SHA256_LINUX_AMD64="$(read_var SHA256_linux_amd64)"
SHA256_LINUX_ARM="$(read_var SHA256_linux_arm)"
SHA256_LINUX_ARM64="$(read_var SHA256_linux_arm64)"

if [ -z "$REMOTE_VERSION" ]; then
  echo "Missing VERSION in ${VERSION_FILE}" >&2
  exit 1
fi

if [ "$REMOTE_VERSION" != "$VERSION" ]; then
  echo "VERSION mismatch: requested ${VERSION}, remote version.txt has ${REMOTE_VERSION}" >&2
  exit 1
fi

download "${BASE_URL}/iStoreEnhance-linux.amd64" "${DEST_DIR}/iStoreEnhance-linux.amd64"
download "${BASE_URL}/iStoreEnhance-linux.arm" "${DEST_DIR}/iStoreEnhance-linux.arm"
download "${BASE_URL}/iStoreEnhance-linux.arm64" "${DEST_DIR}/iStoreEnhance-linux.arm64"

verify_sha256 "iStoreEnhance-linux.amd64" "$SHA256_LINUX_AMD64"
verify_sha256 "iStoreEnhance-linux.arm" "$SHA256_LINUX_ARM"
verify_sha256 "iStoreEnhance-linux.arm64" "$SHA256_LINUX_ARM64"

cp ./kspeeder-install.sh "${DEST_DIR}/"

cat > "${DEST_DIR}/release.env" << EOF
VERSION=${VERSION}
KSPEEDER_BIN_BASE_URL=${BASE_URL}
EOF
