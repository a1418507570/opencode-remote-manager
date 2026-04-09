#!/bin/sh
set -eu

PLIST_PATH="${HOME}/Library/LaunchAgents/com.ruby.opencode-remote-manager.plist"

launchctl bootout "gui/$(id -u)" "${PLIST_PATH}" >/dev/null 2>&1 || true
rm -f "${PLIST_PATH}"

printf '%s\n' "${PLIST_PATH}"
