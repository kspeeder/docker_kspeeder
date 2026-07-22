#!/bin/sh

set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
ROOT_DIR="$(CDPATH= cd -- "${SCRIPT_DIR}/.." && pwd)"

IMAGE_REPOSITORY="linkease/kspeeder"
PLATFORMS="${PLATFORMS:-linux/amd64,linux/arm/v6,linux/arm/v7,linux/arm64}"
BUILDER_NAME="${BUILDER_NAME:-kspeeder-release-builder}"
DOCKER_USERNAME="${DOCKER_USERNAME:-${DOCKERHUB_USERNAME:-}}"
DOCKER_PAT="${DOCKER_PAT:-${DOCKER_PASSWORD:-${DOCKERHUB_TOKEN:-}}}"

cd "$ROOT_DIR"

./prepare-dl.sh

. ./dest/release.env

if [ -z "${VERSION:-}" ]; then
  echo "VERSION is missing from dest/release.env" >&2
  exit 1
fi

if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PAT" ]; then
  echo "DOCKER_USERNAME and DOCKER_PAT are required for Docker Hub release" >&2
  exit 1
fi

printf '%s' "$DOCKER_PAT" | docker login --username "$DOCKER_USERNAME" --password-stdin

if docker buildx inspect "$BUILDER_NAME" >/dev/null 2>&1; then
  docker buildx use "$BUILDER_NAME"
else
  docker buildx create --name "$BUILDER_NAME" --driver docker-container --use
fi

docker buildx inspect --bootstrap

docker buildx build \
  --platform "$PLATFORMS" \
  -t "${IMAGE_REPOSITORY}:${VERSION}" \
  -t "${IMAGE_REPOSITORY}:latest" \
  -f ./Dockerfile.architecture \
  --push \
  .
