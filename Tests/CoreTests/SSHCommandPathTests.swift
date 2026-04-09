import Foundation
import Testing
@testable import OpenCodeRemoteManagerCore

struct SSHCommandPathTests {
    @Test
    func remoteStartUsesSSHWithAliasAndShellCommand() async throws {
        let executor = RecordingProcessExecutor(result: .init(exitCode: 0))
        let controller = SSHRemoteServiceController(processExecutor: executor)

        try await controller.start(OpenCodeRemoteDefaults.connection(for: .go))

        let request = try #require(await executor.requests.first)
        #expect(request.executableURL.path == "/usr/bin/env")
        #expect(Array(request.arguments.prefix(5)) == ["ssh", "-o", "BatchMode=yes", "-o", "ConnectTimeout=12"])
        #expect(request.arguments[5] == "rubyxguo")
        #expect(request.arguments.count == 7)
        #expect(request.arguments.last?.contains("bash -lc '") == true)
        #expect(request.arguments.last?.contains("opencode serve --hostname 127.0.0.1 --port 4096") == true)
    }

    @Test
    func tunnelStartUsesExpectedLocalForwardingArguments() async throws {
        let executor = SequencedRecordingProcessExecutor(results: [.init(exitCode: 0), .init(exitCode: 0)])
        let controller = SSHTunnelController(
            processExecutor: executor,
            fileManager: StubFileManager(),
            homeDirectoryURL: URL(fileURLWithPath: "/Users/tester")
        )

        try await controller.start(OpenCodeRemoteDefaults.connection(for: .java))

        let requests = await executor.requests
        #expect(requests.count == 1)
        let request = try #require(requests.first)
        #expect(request.executableURL.path == "/usr/bin/env")
        #expect(request.arguments == [
            "ssh",
            "-f",
            "-N",
            "-M",
            "-S",
            "/Users/tester/Library/Application Support/OpenCodeRemoteManager/Tunnels/java.sock",
            "-o",
            "BatchMode=yes",
            "-o",
            "ExitOnForwardFailure=yes",
            "-o",
            "ServerAliveInterval=60",
            "-o",
            "ServerAliveCountMax=3",
            "-L",
            "24096:127.0.0.1:4096",
            "nullguo",
        ])
    }

    @Test
    func tunnelStopUsesManagedControlSocketExitCommand() async throws {
        let executor = SequencedRecordingProcessExecutor(results: [.init(exitCode: 0)])
        let fileManager = StubFileManager(existingPaths: ["/Users/tester/Library/Application Support/OpenCodeRemoteManager/Tunnels/go.sock"])
        let controller = SSHTunnelController(
            processExecutor: executor,
            fileManager: fileManager,
            homeDirectoryURL: URL(fileURLWithPath: "/Users/tester")
        )

        try await controller.stop(OpenCodeRemoteDefaults.connection(for: .go))

        let request = try #require((await executor.requests).first)
        #expect(request.arguments == [
            "ssh",
            "-S",
            "/Users/tester/Library/Application Support/OpenCodeRemoteManager/Tunnels/go.sock",
            "-O",
            "exit",
            "rubyxguo",
        ])
    }

    @Test
    func tunnelStateUsesManagedControlSocketCheckCommand() async throws {
        let executor = SequencedRecordingProcessExecutor(results: [.init(exitCode: 0)])
        let fileManager = StubFileManager(existingPaths: ["/Users/tester/Library/Application Support/OpenCodeRemoteManager/Tunnels/go.sock"])
        let controller = SSHTunnelController(
            processExecutor: executor,
            fileManager: fileManager,
            homeDirectoryURL: URL(fileURLWithPath: "/Users/tester")
        )

        let state = try await controller.state(for: OpenCodeRemoteDefaults.connection(for: .go))

        #expect(state == .running)
        let request = try #require((await executor.requests).first)
        #expect(request.arguments == [
            "ssh",
            "-S",
            "/Users/tester/Library/Application Support/OpenCodeRemoteManager/Tunnels/go.sock",
            "-O",
            "check",
            "rubyxguo",
        ])
    }

    @Test
    func tunnelStartNoopsWhenManagedControlSocketAlreadyExists() async throws {
        let executor = SequencedRecordingProcessExecutor(results: [.init(exitCode: 0)])
        let fileManager = StubFileManager(existingPaths: ["/Users/tester/Library/Application Support/OpenCodeRemoteManager/Tunnels/go.sock"])
        let controller = SSHTunnelController(
            processExecutor: executor,
            fileManager: fileManager,
            homeDirectoryURL: URL(fileURLWithPath: "/Users/tester")
        )

        try await controller.start(OpenCodeRemoteDefaults.connection(for: .go))

        let requests = await executor.requests
        #expect(requests.count == 1)
        #expect(requests[0].arguments == [
            "ssh",
            "-S",
            "/Users/tester/Library/Application Support/OpenCodeRemoteManager/Tunnels/go.sock",
            "-O",
            "check",
            "rubyxguo",
        ])
    }
}

private actor RecordingProcessExecutor: ProcessExecuting {
    private(set) var requests: [ProcessExecutionRequest] = []
    private let result: ProcessExecutionResult

    init(result: ProcessExecutionResult) {
        self.result = result
    }

    func run(_ request: ProcessExecutionRequest) async throws -> ProcessExecutionResult {
        requests.append(request)
        return result
    }
}

private actor SequencedRecordingProcessExecutor: ProcessExecuting {
    private(set) var requests: [ProcessExecutionRequest] = []
    private var results: [ProcessExecutionResult]

    init(results: [ProcessExecutionResult]) {
        self.results = results
    }

    func run(_ request: ProcessExecutionRequest) async throws -> ProcessExecutionResult {
        requests.append(request)
        if results.isEmpty {
            return .init(exitCode: 0)
        }

        return results.removeFirst()
    }
}

private final class StubFileManager: FileManaging, @unchecked Sendable {
    private var existingPaths: Set<String>

    init(existingPaths: Set<String> = []) {
        self.existingPaths = existingPaths
    }

    func createDirectory(at url: URL) throws {
        existingPaths.insert(url.path)
    }

    func removeItem(at url: URL) throws {
        existingPaths.remove(url.path)
    }

    func fileExists(at url: URL) -> Bool {
        existingPaths.contains(url.path)
    }
}
