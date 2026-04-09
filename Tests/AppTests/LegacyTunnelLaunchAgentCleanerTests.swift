import Foundation
import Testing
@testable import OpenCodeRemoteManagerApp
import OpenCodeRemoteManagerCore

@MainActor
struct LegacyTunnelLaunchAgentCleanerTests {
    @Test
    func cleanupRemovesLegacyTunnelPlistsAndBootsThemOut() throws {
        let homeDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let launchAgentsDirectory = homeDirectoryURL.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        try FileManager.default.createDirectory(at: launchAgentsDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: homeDirectoryURL) }

        let goURL = launchAgentsDirectory.appendingPathComponent("com.opencode.remote-manager.go.plist")
        let javaURL = launchAgentsDirectory.appendingPathComponent("com.opencode.remote-manager.java.plist")
        try Data().write(to: goURL)
        try Data().write(to: javaURL)

        let recorder = LaunchctlRecorder()
        let cleaner = LegacyTunnelLaunchAgentCleaner(
            homeDirectoryURL: homeDirectoryURL,
            launchctlRunner: { arguments in
                recorder.calls.append(arguments)
                return 0
            }
        )

        cleaner.cleanup()

        #expect(FileManager.default.fileExists(atPath: goURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: javaURL.path) == false)
        #expect(recorder.calls.count == 2)
        #expect(recorder.calls.allSatisfy { $0.first == "bootout" })
    }
}

private final class LaunchctlRecorder: @unchecked Sendable {
    var calls: [[String]] = []
}
