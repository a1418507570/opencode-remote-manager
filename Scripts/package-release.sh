#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
DIST_DIR="${PROJECT_ROOT}/dist"
APP_PATH=$("${SCRIPT_DIR}/package-app.sh")
ARCHIVE_PATH="${DIST_DIR}/OpenCodeRemoteManager-macOS.zip"

mkdir -p "${DIST_DIR}"
rm -f "${ARCHIVE_PATH}"
ditto -c -k --keepParent "${APP_PATH}" "${ARCHIVE_PATH}"

printf '%s\n' "${ARCHIVE_PATH}"
