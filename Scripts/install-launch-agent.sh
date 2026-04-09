#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
APP_PATH="${1:-${HOME}/Applications/OpenCode Remote Manager.app}"
APP_BINARY="${APP_PATH}/Contents/MacOS/OpenCodeRemoteManagerApp"
PLIST_PATH="${HOME}/Library/LaunchAgents/com.ruby.opencode-remote-manager.plist"

for legacy_plist in "${HOME}/Library/LaunchAgents/com.opencode.remote-manager.go.plist" "${HOME}/Library/LaunchAgents/com.opencode.remote-manager.java.plist"; do
  launchctl bootout "gui/$(id -u)" "${legacy_plist}" >/dev/null 2>&1 || true
  rm -f "${legacy_plist}"
done

if [ ! -x "${APP_BINARY}" ]; then
  APP_PATH=$("${SCRIPT_DIR}/package-app.sh")
  APP_BINARY="${APP_PATH}/Contents/MacOS/OpenCodeRemoteManagerApp"
fi

mkdir -p "$(dirname "${PLIST_PATH}")"

cat > "${PLIST_PATH}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>com.ruby.opencode-remote-manager</string>
	<key>ProgramArguments</key>
	<array>
		<string>${APP_BINARY}</string>
	</array>
	<key>LimitLoadToSessionType</key>
	<string>Aqua</string>
	<key>RunAtLoad</key>
	<true/>
	<key>StandardOutPath</key>
	<string>${HOME}/Library/Logs/opencode-remote-manager.app.log</string>
	<key>StandardErrorPath</key>
	<string>${HOME}/Library/Logs/opencode-remote-manager.app.error.log</string>
</dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)" "${PLIST_PATH}" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "${PLIST_PATH}"
printf '%s\n' "${PLIST_PATH}"
