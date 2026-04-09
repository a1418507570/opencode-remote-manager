#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
DIST_DIR="${PROJECT_ROOT}/dist"
STAGING_ROOT="${DIST_DIR}/release-root"
ARCHIVE_PATH="${DIST_DIR}/OpenCodeRemoteManager-macOS.zip"

mkdir -p "${DIST_DIR}"
rm -rf "${STAGING_ROOT}"
rm -f "${ARCHIVE_PATH}"
APP_PATH=$(APP_ROOT="${STAGING_ROOT}" "${SCRIPT_DIR}/package-app.sh")
ditto -c -k --keepParent "${APP_PATH}" "${ARCHIVE_PATH}"
rm -rf "${STAGING_ROOT}"

printf '%s\n' "${ARCHIVE_PATH}"
