import Foundation
import Testing
@testable import OpenCodeRemoteManagerCore

struct OpenCodeRemoteManagerLiveTests {
    @Test
    func liveManagerSeedsDefaultsWhenRemoteConfigIsMissing() async throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let remoteConfigURL = directoryURL.appendingPathComponent("connections.json")
        let desiredStateURL = directoryURL.appendingPathComponent("desired-state.json")

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let manager = OpenCodeRemoteManager.live(
            desiredStateStore: PersistentDesiredStateStore(fileURL: desiredStateURL),
            remoteConfigurationStore: PersistentRemoteConfigurationStore(fileURL: remoteConfigURL)
        )

        #expect(manager.connections() == OpenCodeRemoteDefaults.connections)
        #expect(FileManager.default.fileExists(atPath: remoteConfigURL.path))
    }

    @Test
    func liveManagerUsesPersistedRemoteConfigurationWhenPresent() async throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let remoteConfigURL = directoryURL.appendingPathComponent("connections.json")
        let desiredStateURL = directoryURL.appendingPathComponent("desired-state.json")

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let persistedConnections = [
            OpenCodeRemoteConnection(
                id: OpenCodeRemoteConnectionID(rawValue: "alpha"),
                sshAlias: "alpha-host",
                localURL: URL(string: "http://127.0.0.1:34096")!,
                localPort: 34_096,
                remotePort: 4_196
            ),
        ]
        let payload = PersistentRemoteConfigurationStore.Payload(connections: persistedConnections)
        try JSONEncoder().encode(payload).write(to: remoteConfigURL)

        let manager = OpenCodeRemoteManager.live(
            desiredStateStore: PersistentDesiredStateStore(fileURL: desiredStateURL),
            remoteConfigurationStore: PersistentRemoteConfigurationStore(fileURL: remoteConfigURL)
        )

        #expect(manager.connections() == persistedConnections)
    }

    @Test
    func liveManagerPreservesDesiredStateForSeededGoAndJavaIDs() async throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let remoteConfigURL = directoryURL.appendingPathComponent("connections.json")
        let desiredStateURL = directoryURL.appendingPathComponent("desired-state.json")

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let desiredJSON = #"{"states":{"go":"running","java":"stopped"}}"#
        try desiredJSON.data(using: .utf8)?.write(to: desiredStateURL)

        let manager = OpenCodeRemoteManager.live(
            desiredStateStore: PersistentDesiredStateStore(fileURL: desiredStateURL),
            remoteConfigurationStore: PersistentRemoteConfigurationStore(fileURL: remoteConfigURL)
        )

        let running = await manager.desiredConnectionIDs(requiring: .running)
        let stopped = await manager.desiredState(for: .java)

        #expect(running == [.go])
        #expect(stopped == .stopped)
    }
}
