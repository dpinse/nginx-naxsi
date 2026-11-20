#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 1 ] || [ -z "$1" ]; then
  echo "Usage: $0 <naxsi_version>" >&2
  exit 1
fi

NAXSI_VERSION="$1"
TARGET_DIR="${2:-naxsi}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Try exact version first, then v-prefixed tag if needed
ARCHIVE_URL=""
for candidate in "$NAXSI_VERSION" "v${NAXSI_VERSION#v}"; do
  url="https://github.com/wargio/naxsi/archive/refs/tags/${candidate}.tar.gz"
  if curl -fsSI "$url" >/dev/null 2>&1; then
    ARCHIVE_URL="$url"
    break
  fi
done

if [ -z "$ARCHIVE_URL" ]; then
  echo "Could not find release archive for NAXSI version '${NAXSI_VERSION}' on wargio/naxsi" >&2
  exit 1
fi

curl -fsSL "$ARCHIVE_URL" -o "$TMP_DIR/naxsi.tar.gz"
tar -xzf "$TMP_DIR/naxsi.tar.gz" -C "$TMP_DIR" --strip-components=1 "*/naxsi_rules"

SRC_RULES_DIR="$TMP_DIR/naxsi_rules"
if [ ! -d "$SRC_RULES_DIR" ]; then
  echo "Expected naxsi_rules directory inside archive for ${NAXSI_VERSION}" >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"

# Replace only upstream-managed paths so custom rule files remain intact
for item in naxsi_core.rules blocking whitelists; do
  rm -rf "${TARGET_DIR:?}/${item}"
  if [ -e "${SRC_RULES_DIR}/${item}" ]; then
    cp -r "${SRC_RULES_DIR}/${item}" "${TARGET_DIR}/"
  fi
done