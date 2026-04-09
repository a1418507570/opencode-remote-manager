import Foundation

public protocol RemoteServiceControlling: Sendable {
    func start(_ connection: OpenCodeRemoteConnection) async throws
    func stop(_ connection: OpenCodeRemoteConnection) async throws
    func restart(_ connection: OpenCodeRemoteConnection) async throws
    func state(for connection: OpenCodeRemoteConnection) async throws -> RemoteServiceState
    func bootstrapRemote(dryRun: Bool) async throws -> [String]
}

public struct SSHRemoteServiceController: RemoteServiceControlling {
    public struct RemoteShellCommandSet: Sendable {
        public let bootstrap: @Sendable (OpenCodeRemoteConnection) -> String
        public let start: @Sendable (OpenCodeRemoteConnection) -> String
        public let stop: @Sendable (OpenCodeRemoteConnection) -> String
        public let restart: @Sendable (OpenCodeRemoteConnection) -> String
        public let status: @Sendable (OpenCodeRemoteConnection) -> String

        public init(
            bootstrap: @escaping @Sendable (OpenCodeRemoteConnection) -> String,
            start: @escaping @Sendable (OpenCodeRemoteConnection) -> String,
            stop: @escaping @Sendable (OpenCodeRemoteConnection) -> String,
            restart: @escaping @Sendable (OpenCodeRemoteConnection) -> String,
            status: @escaping @Sendable (OpenCodeRemoteConnection) -> String
        ) {
            self.bootstrap = bootstrap
            self.start = start
            self.stop = stop
            self.restart = restart
            self.status = status
        }

        public static let `default` = RemoteShellCommandSet(
            bootstrap: { connection in
                let wrapperPath = wrapperScriptPath(for: connection)
                let resolvedPathPath = resolvedBinaryPathFilePath(for: connection)
                let cronLine = "@reboot \(wrapperPath) # OCRM \(connection.id.rawValue)"

                return """
                mkdir -p ~/.opencode-remote-manager
                RESOLVED_OPENCODE_PATH="$(command -v opencode 2>/dev/null || true)"
                if [ -z "$RESOLVED_OPENCODE_PATH" ] && [ -x /root/.npm/node_modules/bin/opencode ]; then RESOLVED_OPENCODE_PATH=/root/.npm/node_modules/bin/opencode; fi
                if [ ! -x "$RESOLVED_OPENCODE_PATH" ]; then echo 'opencode not found' >&2; exit 1; fi
                printf '%s\n' "$RESOLVED_OPENCODE_PATH" > "\(resolvedPathPath)"
                cat > "\(wrapperPath)" <<'EOF'
                \(remoteWrapperScript(for: connection))
                EOF
                chmod +x "\(wrapperPath)"
                { crontab -l 2>/dev/null | grep -v 'OCRM \(connection.id.rawValue)' || true; printf '%s\\n' \(shellQuoted(cronLine)); } | crontab -
                printf '%s\\n' "\(wrapperPath)"
                """
            },
            start: { connection in
                let wrapperPath = wrapperScriptPath(for: connection)
                return """
                if [ -x "\(wrapperPath)" ]; then
                  "\(wrapperPath)"
                else
                \(fallbackStartCommand(for: connection))
                fi
                """
            },
            stop: { connection in
                "pkill -f 'opencode serve --hostname 127.0.0.1 --port \(connection.remotePort)' || true"
            },
            restart: { connection in
                let wrapperPath = wrapperScriptPath(for: connection)
                return """
                pkill -f 'opencode serve --hostname 127.0.0.1 --port \(connection.remotePort)' || true
                if [ -x "\(wrapperPath)" ]; then
                  "\(wrapperPath)"
                else
                \(fallbackStartCommand(for: connection))
                fi
                """
            },
            status: { connection in
                "curl -fsS http://127.0.0.1:\(connection.remotePort)/global/health >/dev/null"
            }
        )
    }

    private let processExecutor: ProcessExecuting
    private let commandSet: RemoteShellCommandSet

    public init(processExecutor: ProcessExecuting, commandSet: RemoteShellCommandSet = .default) {
        self.processExecutor = processExecutor
        self.commandSet = commandSet
    }

    public func start(_ connection: OpenCodeRemoteConnection) async throws {
        _ = try await runSSH(connection: connection, remoteCommand: commandSet.start(connection), allowNonZeroExit: false)
    }

    public func stop(_ connection: OpenCodeRemoteConnection) async throws {
        _ = try await runSSH(connection: connection, remoteCommand: commandSet.stop(connection), allowNonZeroExit: true)
    }

    public func restart(_ connection: OpenCodeRemoteConnection) async throws {
        _ = try await runSSH(connection: connection, remoteCommand: commandSet.restart(connection), allowNonZeroExit: false)
    }

    public func state(for connection: OpenCodeRemoteConnection) async throws -> RemoteServiceState {
        let result = try await runSSH(connection: connection, remoteCommand: commandSet.status(connection), allowNonZeroExit: true)
        return result.exitCode == 0 ? .running : .stopped
    }

    public func bootstrapRemote(dryRun: Bool) async throws -> [String] {
        var renderedCommands: [String] = []

        for connection in OpenCodeRemoteDefaults.connections {
            let command = commandSet.bootstrap(connection)
            renderedCommands.append("ssh \(connection.sshAlias) sh -lc \(shellQuoted(command))")

            if dryRun == false {
                _ = try await runSSH(connection: connection, remoteCommand: command, allowNonZeroExit: false)
            }
        }

        return renderedCommands
    }

    private func runSSH(
        connection: OpenCodeRemoteConnection,
        remoteCommand: String,
        allowNonZeroExit: Bool
    ) async throws -> ProcessExecutionResult {
        let request = ProcessExecutionRequest(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: [
                "ssh",
                "-o",
                "BatchMode=yes",
                "-o",
                "ConnectTimeout=12",
                connection.sshAlias,
                "bash -lc \(shellQuoted(remoteCommand))",
            ]
        )

        let result = try await processExecutor.run(request)
        if allowNonZeroExit == false, result.exitCode != 0 {
            throw OpenCodeRemoteManagerError.processFailure(
                "SSH command failed for \(connection.id.rawValue): \(result.standardError.isEmpty ? result.standardOutput : result.standardError)"
            )
        }
        return result
    }
}

private func shellQuoted(_ value: String) -> String {
    "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
}

private func wrapperScriptPath(for connection: OpenCodeRemoteConnection) -> String {
    "$HOME/.opencode-remote-manager/\(connection.id.rawValue)-serve.sh"
}

private func resolvedBinaryPathFilePath(for connection: OpenCodeRemoteConnection) -> String {
    "$HOME/.opencode-remote-manager/\(connection.id.rawValue)-opencode-path"
}

private func fallbackStartCommand(for connection: OpenCodeRemoteConnection) -> String {
    let logPath = "$HOME/.opencode-remote-manager/\(connection.id.rawValue).log"

    return """
    mkdir -p ~/.opencode-remote-manager
    OPENCODE_PATH="$(command -v opencode 2>/dev/null || true)"
    if [ -z "$OPENCODE_PATH" ] && [ -x /root/.npm/node_modules/bin/opencode ]; then OPENCODE_PATH=/root/.npm/node_modules/bin/opencode; fi
    if [ ! -x "$OPENCODE_PATH" ]; then echo 'opencode not found' >&2; exit 1; fi
    pgrep -f 'opencode serve --hostname 127.0.0.1 --port \(connection.remotePort)' >/dev/null || nohup "$OPENCODE_PATH" serve --hostname 127.0.0.1 --port \(connection.remotePort) >> "\(logPath)" 2>&1 < /dev/null &
    """
}

private func remoteWrapperScript(for connection: OpenCodeRemoteConnection) -> String {
    let logPath = "$HOME/.opencode-remote-manager/\(connection.id.rawValue).log"
    let resolvedPathFile = resolvedBinaryPathFilePath(for: connection)

    return """
    #!/bin/sh
    set -eu
    mkdir -p "$HOME/.opencode-remote-manager"
    OPENCODE_PATH="$(cat \(resolvedPathFile) 2>/dev/null || true)"
    if [ ! -x "$OPENCODE_PATH" ]; then echo "opencode not found" >&2; exit 1; fi
    if pgrep -f 'opencode serve --hostname 127.0.0.1 --port \(connection.remotePort)' >/dev/null 2>&1; then exit 0; fi
    nohup "$OPENCODE_PATH" serve --hostname 127.0.0.1 --port \(connection.remotePort) >> \(logPath) 2>&1 < /dev/null &
    """
}
