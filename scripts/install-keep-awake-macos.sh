#!/usr/bin/env bash
set -euo pipefail

LABEL="com.samuel.mbp-inference-awake"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCE_PLIST="${REPO_ROOT}/examples/${LABEL}.plist"
DEST_DIR="${HOME}/Library/LaunchAgents"
DEST_PLIST="${DEST_DIR}/${LABEL}.plist"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "error: this script must run on macOS (Darwin)." >&2
  exit 1
fi

if [[ ! -f "${SOURCE_PLIST}" ]]; then
  echo "error: source plist not found at ${SOURCE_PLIST}" >&2
  exit 1
fi

mkdir -p "${DEST_DIR}"
cp "${SOURCE_PLIST}" "${DEST_PLIST}"
echo "installed plist -> ${DEST_PLIST}"

UID_NUM="$(id -u)"
DOMAIN="gui/${UID_NUM}"

# Unload previous instance if present (idempotent).
if launchctl print "${DOMAIN}/${LABEL}" &>/dev/null; then
  echo "unloading existing LaunchAgent ${LABEL}..."
  launchctl bootout "${DOMAIN}" "${DEST_PLIST}" 2>/dev/null || \
    launchctl unload "${DEST_PLIST}" 2>/dev/null || true
fi

echo "loading LaunchAgent ${LABEL}..."
if launchctl bootstrap "${DOMAIN}" "${DEST_PLIST}" 2>/dev/null; then
  echo "bootstrapped ${LABEL}"
else
  launchctl load "${DEST_PLIST}"
  echo "loaded ${LABEL}"
fi

if launchctl print "${DOMAIN}/${LABEL}" &>/dev/null; then
  echo "status: ${LABEL} is active (caffeinate -dims, KeepAlive)"
else
  echo "warning: ${LABEL} may not be running — check: launchctl print ${DOMAIN}/${LABEL}" >&2
  exit 1
fi

echo ""
echo "note: pmset sleep may still be 1 without sudo. See docs/KEEP-AWAKE.md for pmset options."
