import Foundation

public protocol TunnelControlling: Sendable {
    func start(_ connection: OpenCodeRemoteConnection) async throws
    func stop(_ connection: OpenCodeRemoteConnection) async throws
    func restart(_ connection: OpenCodeRemoteConnection) async throws
    func state(for connection: OpenCodeRemoteConnection) async throws -> TunnelState
}

public struct SSHTunnelController: TunnelControlling {
    private let processExecutor: ProcessExecuting
    private let fileManager: FileManaging
    private let homeDirectoryURL: URL

    public init(
        processExecutor: ProcessExecuting,
        fileManager: FileManaging = FoundationFileManager(),
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.processExecutor = processExecutor
        self.fileManager = fileManager
        self.homeDirectoryURL = homeDirectoryURL
    }

    public func start(_ connection: OpenCodeRemoteConnection) async throws {
        try ensureControlSocketDirectoryExists()
        if try await managedTunnelIsRunningOrClearStaleControlSocket(for: connection) {
            return
        }

        let result = try await processExecutor.run(
            ProcessExecutionRequest(
                executableURL: URL(fileURLWithPath: "/usr/bin/env"),
                arguments: sshTunnelStartArguments(for: connection)
            )
        )

        if result.exitCode != 0 {
            throw OpenCodeRemoteManagerError.processFailure(
                "Failed to start tunnel for \(connection.id.rawValue): \(result.standardError.isEmpty ? result.standardOutput : result.standardError)"
            )
        }
    }

    public func stop(_ connection: OpenCodeRemoteConnection) async throws {
        guard let controlSocket = try await activeControlSocketURL(for: connection) else {
            return
        }

        let result = try await processExecutor.run(controlCommandRequest(for: connection, command: "exit", controlSocketURL: controlSocket))
        if result.exitCode == 0 {
            try? fileManager.removeItem(at: controlSocket)
            return
        }

        let checkResult = try await processExecutor.run(controlCommandRequest(for: connection, command: "check", controlSocketURL: controlSocket))
        if checkResult.exitCode != 0 {
            try? fileManager.removeItem(at: controlSocket)
            return
        }

        throw OpenCodeRemoteManagerError.processFailure(
            "Failed to stop tunnel for \(connection.id.rawValue): \(result.standardError.isEmpty ? result.standardOutput : result.standardError)"
        )
    }

    public func restart(_ connection: OpenCodeRemoteConnection) async throws {
        try await stop(connection)
        try await start(connection)
    }

    public func state(for connection: OpenCodeRemoteConnection) async throws -> TunnelState {
        if let controlSocket = try await activeControlSocketURL(for: connection) {
            let result = try await processExecutor.run(controlCommandRequest(for: connection, command: "check", controlSocketURL: controlSocket))
            if result.exitCode == 0 {
                return .running
            }

            try? fileManager.removeItem(at: controlSocket)
        }

        return .stopped
    }

    private func sshTunnelStartArguments(for connection: OpenCodeRemoteConnection) -> [String] {
        [
            "ssh",
            "-f",
            "-N",
            "-M",
            "-S",
            controlSocketURL(for: connection).path,
            "-o",
            "BatchMode=yes",
            "-o",
            "ExitOnForwardFailure=yes",
            "-o",
            "ServerAliveInterval=60",
            "-o",
            "ServerAliveCountMax=3",
            "-L",
            "\(connection.localPort):127.0.0.1:\(connection.remotePort)",
            connection.sshAlias,
        ]
    }

    private func controlSocketDirectoryURL() -> URL {
        homeDirectoryURL.appendingPathComponent("Library/Application Support/OpenCodeRemoteManager/Tunnels", isDirectory: true)
    }

    private func controlSocketURL(for connection: OpenCodeRemoteConnection) -> URL {
        controlSocketDirectoryURL().appendingPathComponent("\(connection.id.storageIdentifier).sock")
    }

    private func legacyControlSocketURL(for connection: OpenCodeRemoteConnection) -> URL? {
        let rawValue = connection.id.rawValue
        let isLegacySafe = rawValue.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil
        guard isLegacySafe, rawValue.contains("..") == false else {
            return nil
        }

        let legacyName = "\(connection.id.rawValue).sock"
        let currentName = "\(connection.id.storageIdentifier).sock"
        guard legacyName != currentName else {
            return nil
        }

        return controlSocketDirectoryURL().appendingPathComponent(legacyName)
    }

    private func ensureControlSocketDirectoryExists() throws {
        try fileManager.createDirectory(at: controlSocketDirectoryURL())
    }

    private func managedTunnelIsRunningOrClearStaleControlSocket(for connection: OpenCodeRemoteConnection) async throws -> Bool {
        for controlSocket in candidateControlSocketURLs(for: connection) {
            guard fileManager.fileExists(at: controlSocket) else {
                continue
            }

            let result = try await processExecutor.run(controlCommandRequest(for: connection, command: "check", controlSocketURL: controlSocket))
            if result.exitCode == 0 {
                return true
            }

            try? fileManager.removeItem(at: controlSocket)
        }
        return false
    }

    private func activeControlSocketURL(for connection: OpenCodeRemoteConnection) async throws -> URL? {
        for controlSocket in candidateControlSocketURLs(for: connection) {
            guard fileManager.fileExists(at: controlSocket) else {
                continue
            }

            let result = try await processExecutor.run(controlCommandRequest(for: connection, command: "check", controlSocketURL: controlSocket))
            if result.exitCode == 0 {
                return controlSocket
            }

            try? fileManager.removeItem(at: controlSocket)
        }

        return nil
    }

    private func candidateControlSocketURLs(for connection: OpenCodeRemoteConnection) -> [URL] {
        [controlSocketURL(for: connection), legacyControlSocketURL(for: connection)].compactMap { $0 }
    }

    private func controlCommandRequest(
        for connection: OpenCodeRemoteConnection,
        command: String,
        controlSocketURL: URL
    ) -> ProcessExecutionRequest {
        ProcessExecutionRequest(
            executableURL: URL(fileURLWithPath: "/usr/bin/env"),
            arguments: [
                "ssh",
                "-S",
                controlSocketURL.path,
                "-O",
                command,
                connection.sshAlias,
            ]
        )
    }
}
