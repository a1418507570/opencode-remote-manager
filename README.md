# OpenCode Remote Manager

OpenCode Remote Manager is a native macOS menu bar utility for managing two fixed OpenCode remote connections and keeping the Desktop-facing localhost remotes healthy.

## Current scope

This repository currently targets a concrete two-remote setup:

- `go` → `rubyxguo` → `http://127.0.0.1:14096`
- `java` → `nullguo` → `http://127.0.0.1:24096`

The code is structured so the control plane is reusable, but the shipped v1 behavior is intentionally opinionated and focused.

## What it manages

- remote `opencode serve` bootstrap persistence via SSH + `crontab @reboot`
- local SSH tunnel lifecycle and health checks managed by the menu bar app itself
- a menu bar app that surfaces remote / tunnel / HTTP health separately
- login-time auto-start for the menu bar app through a single LaunchAgent

## Project layout

- `Sources/OpenCodeRemoteManagerCore` — orchestration, diagnostics, SSH/tunnel control
- `Sources/OpenCodeRemoteManagerApp` — AppKit menu bar shell
- `Sources/OpenCodeRemoteManagerCLI` — diagnostics and operator commands
- `Scripts/` — packaging and LaunchAgent installation helpers

## Requirements

- macOS 14+
- Swift 6.3+
- SSH access to the remote environments
- `opencode` installed on the remote hosts

## Build and test

```bash
swift build
DYLD_FRAMEWORK_PATH="/Library/Developer/CommandLineTools/Library/Developer/Frameworks" \
DYLD_LIBRARY_PATH="/Library/Developer/CommandLineTools/Library/Developer/usr/lib" \
swift test -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/Frameworks \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib
```

## Common commands

```bash
swift run OpenCodeRemoteManagerCLI diagnose --json
swift run OpenCodeRemoteManagerCLI bootstrap-remote
./Scripts/package-app.sh
./Scripts/package-release.sh
./Scripts/install-launch-agent.sh
```

## Release packaging

`./Scripts/package-release.sh` creates a zipped macOS app artifact in `dist/OpenCodeRemoteManager-macOS.zip`.

## Open source project files

- `LICENSE` — Apache-2.0
- `CONTRIBUTING.md` — contribution workflow
- `CODE_OF_CONDUCT.md` — contributor behavior expectations
- `SECURITY.md` — vulnerability reporting guidance
- `CHANGELOG.md` — release notes history

## Recovery notes

- Reinstall remote persistence:
  - `swift run OpenCodeRemoteManagerCLI bootstrap-remote`
- Repackage the app:
  - `./Scripts/package-app.sh`
- Reinstall login auto-start:
  - `./Scripts/install-launch-agent.sh`
- Remove login auto-start:
  - `./Scripts/uninstall-launch-agent.sh`

## License

Apache-2.0
