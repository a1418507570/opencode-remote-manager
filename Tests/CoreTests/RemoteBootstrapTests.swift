import Foundation
import Testing
@testable import OpenCodeRemoteManagerCore

struct RemoteBootstrapTests {
    @Test
    func bootstrapRemoteWritesStableBinaryPathFilesAndWrappers() async throws {
        let controller = SSHRemoteServiceController(processExecutor: BootstrapRecordingProcessExecutor())

        let commands = try await controller.bootstrapRemote(dryRun: true)

        let goCommand = try #require(commands.first(where: { $0.contains("rubyxguo") }))
        let javaCommand = try #require(commands.first(where: { $0.contains("nullguo") }))

        #expect(goCommand.contains("go-opencode-path"))
        #expect(goCommand.contains("cat $HOME/.opencode-remote-manager/go-opencode-path"))
        #expect(javaCommand.contains("java-opencode-path"))
        #expect(javaCommand.contains("cat $HOME/.opencode-remote-manager/java-opencode-path"))
    }
}

private actor BootstrapRecordingProcessExecutor: ProcessExecuting {
    func run(_ request: ProcessExecutionRequest) async throws -> ProcessExecutionResult {
        .init(exitCode: 0)
    }
}
