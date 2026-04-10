import Foundation
import Testing
@testable import OpenCodeRemoteManagerCore

struct PersistentRemoteConfigurationStoreTests {
    @Test
    func loadsSeededDefaultsAndPersistsThemWhenConfigFileIsMissing() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("connections.json")

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let store = PersistentRemoteConfigurationStore(fileURL: fileURL)
        let connections = store.loadConnections()

        #expect(connections == OpenCodeRemoteDefaults.connections)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))

        let persisted = try JSONDecoder().decode(PersistentRemoteConfigurationStore.Payload.self, from: Data(contentsOf: fileURL))
        #expect(persisted.connections == OpenCodeRemoteDefaults.connections)
    }

    @Test
    func createsMissingParentDirectoryBeforePersistingSeededDefaults() throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let nestedDirectoryURL = rootURL.appendingPathComponent("Library/Application Support/OpenCodeRemoteManager", isDirectory: true)
        let fileURL = nestedDirectoryURL.appendingPathComponent("connections.json")

        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let store = PersistentRemoteConfigurationStore(fileURL: fileURL)
        let connections = store.loadConnections()

        #expect(connections == OpenCodeRemoteDefaults.connections)
        #expect(FileManager.default.fileExists(atPath: nestedDirectoryURL.path))
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test
    func returnsPersistedConnectionsWhenConfigFileExists() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("connections.json")

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
        try JSONEncoder().encode(payload).write(to: fileURL)

        let store = PersistentRemoteConfigurationStore(fileURL: fileURL)
        let connections = store.loadConnections()

        #expect(connections == persistedConnections)
    }

    @Test
    func preservesDynamicStringBackedIDsAcrossPersistence() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("connections.json")

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let persistedConnections = [
            OpenCodeRemoteConnection(
                id: OpenCodeRemoteConnectionID(rawValue: "review-dashboard"),
                sshAlias: "review-host",
                localURL: URL(string: "http://127.0.0.1:35096")!,
                localPort: 35_096,
                remotePort: 4_296
            ),
        ]

        let payload = PersistentRemoteConfigurationStore.Payload(connections: persistedConnections)
        try JSONEncoder().encode(payload).write(to: fileURL)

        let store = PersistentRemoteConfigurationStore(fileURL: fileURL)
        let connections = store.loadConnections()

        #expect(connections.first?.id.rawValue == "review-dashboard")
    }

    @Test
    func fallsBackToDefaultsWhenPersistedConfigHasDuplicateIDs() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("connections.json")

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let duplicateConnections = [
            OpenCodeRemoteConnection(
                id: OpenCodeRemoteConnectionID(rawValue: "go"),
                sshAlias: "alpha-host",
                localURL: URL(string: "http://127.0.0.1:34096")!,
                localPort: 34_096
            ),
            OpenCodeRemoteConnection(
                id: OpenCodeRemoteConnectionID(rawValue: "go"),
                sshAlias: "beta-host",
                localURL: URL(string: "http://127.0.0.1:44096")!,
                localPort: 44_096
            ),
        ]

        let payload = PersistentRemoteConfigurationStore.Payload(connections: duplicateConnections)
        let originalData = try JSONEncoder().encode(payload)
        try originalData.write(to: fileURL)

        let store = PersistentRemoteConfigurationStore(fileURL: fileURL)
        let connections = store.loadConnections()

        #expect(connections == OpenCodeRemoteDefaults.connections)
        #expect(try Data(contentsOf: fileURL) == originalData)
    }

    @Test
    func fallsBackToDefaultsWhenPersistedConfigIsEmpty() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("connections.json")

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let payload = PersistentRemoteConfigurationStore.Payload(connections: [])
        let originalData = try JSONEncoder().encode(payload)
        try originalData.write(to: fileURL)

        let store = PersistentRemoteConfigurationStore(fileURL: fileURL)
        let connections = store.loadConnections()

        #expect(connections == OpenCodeRemoteDefaults.connections)
        #expect(try Data(contentsOf: fileURL) == originalData)
    }

    @Test
    func fallsBackToDefaultsWhenPersistedConfigIsInvalidWithoutOverwritingFile() throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("connections.json")

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let invalidJSON = #"{"connections":"bad-shape"}"#
        try invalidJSON.data(using: .utf8)?.write(to: fileURL)

        let store = PersistentRemoteConfigurationStore(fileURL: fileURL)
        let connections = store.loadConnections()

        #expect(connections == OpenCodeRemoteDefaults.connections)
        #expect(String(data: try Data(contentsOf: fileURL), encoding: .utf8) == invalidJSON)
    }
}
