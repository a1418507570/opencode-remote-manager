import Foundation
import OpenCodeRemoteManagerCore

@MainActor
final class LegacyTunnelLaunchAgentCleaner {
    private let homeDirectoryURL: URL
    private let fileManager: FileManaging
    private let launchctlRunner: @Sendable ([String]) -> Int32

    init(
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
        fileManager: FileManaging = FoundationFileManager(),
        launchctlRunner: @escaping @Sendable ([String]) -> Int32 = LegacyTunnelLaunchAgentCleaner.defaultLaunchctlRunner
    ) {
        self.homeDirectoryURL = homeDirectoryURL
        self.fileManager = fileManager
        self.launchctlRunner = launchctlRunner
    }

    func cleanup() {
        let launchAgentsDirectory = homeDirectoryURL.appendingPathComponent("Library/LaunchAgents", isDirectory: true)

        for connection in OpenCodeRemoteDefaults.connections {
            let plistURL = launchAgentsDirectory.appendingPathComponent("com.opencode.remote-manager.\(connection.id.rawValue).plist")
            guard fileManager.fileExists(at: plistURL) else {
                continue
            }

            _ = launchctlRunner(["bootout", "gui/\(getuid())", plistURL.path])
            try? fileManager.removeItem(at: plistURL)
        }
    }

    @discardableResult
    nonisolated static func defaultLaunchctlRunner(arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}
