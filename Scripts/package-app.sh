#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
APP_NAME="OpenCode Remote Manager.app"
APP_ROOT="${APP_ROOT:-${HOME}/Applications}"
APP_DEST="${APP_ROOT}/${APP_NAME}"
BUILD_BINARY="${PROJECT_ROOT}/.build/release/OpenCodeRemoteManagerApp"
INFO_PLIST="${PROJECT_ROOT}/Resources/Info.plist"

"${SCRIPT_DIR}/build-app.sh"

mkdir -p "${APP_DEST}/Contents/MacOS" "${APP_DEST}/Contents/Resources"
install -m 755 "${BUILD_BINARY}" "${APP_DEST}/Contents/MacOS/OpenCodeRemoteManagerApp"
cp "${INFO_PLIST}" "${APP_DEST}/Contents/Info.plist"

printf '%s\n' "${APP_DEST}"
