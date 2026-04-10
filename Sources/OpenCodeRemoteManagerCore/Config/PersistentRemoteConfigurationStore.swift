import Foundation
import Darwin

public protocol RemoteConfigurationStore: Sendable {
    func loadConnections() -> [OpenCodeRemoteConnection]
}

public protocol MutableRemoteConfigurationStore: RemoteConfigurationStore {
    func saveConnections(_ connections: [OpenCodeRemoteConnection]) throws
}

public struct PersistentRemoteConfigurationStore: MutableRemoteConfigurationStore, Sendable {
    public struct Payload: Codable, Equatable {
        public let connections: [OpenCodeRemoteConnection]

        public init(connections: [OpenCodeRemoteConnection]) {
            self.connections = connections
        }
    }

    private let fileURL: URL
    private let seededConnections: [OpenCodeRemoteConnection]

    public init(
        fileURL: URL = defaultRemoteConfigurationStoreFileURL(),
        seededConnections: [OpenCodeRemoteConnection] = []
    ) {
        self.fileURL = fileURL
        self.seededConnections = seededConnections
    }

    public func loadConnections() -> [OpenCodeRemoteConnection] {
        ensureParentDirectoryExists()

        return withFileLock(at: fileURL) {
            if let data = try? Data(contentsOf: fileURL),
               let payload = try? JSONDecoder().decode(Payload.self, from: data),
               validate(payload.connections) {
                return payload.connections
            }

            if FileManager.default.fileExists(atPath: fileURL.path) {
                NSLog("Falling back to seeded remote configuration because persisted configuration is invalid at %@", fileURL.path)
                return seededConnections
            }

            persistSeededConnections()
            return seededConnections
        } ?? seededConnections
    }

    public func saveConnections(_ connections: [OpenCodeRemoteConnection]) throws {
        guard validate(connections) else {
            throw OpenCodeRemoteManagerError.fileSystemFailure("Remote configuration contains duplicate connection IDs.")
        }

        ensureParentDirectoryExists()

        do {
            try withFileLockThrowing(at: fileURL) {
                let payload = Payload(connections: connections)
                let data = try JSONEncoder().encode(payload)
                try data.write(to: fileURL, options: .atomic)
            }
        } catch let error as OpenCodeRemoteManagerError {
            throw error
        } catch {
            throw OpenCodeRemoteManagerError.fileSystemFailure("Failed to save remote configuration: \(error.localizedDescription)")
        }
    }
}

private extension PersistentRemoteConfigurationStore {
    func ensureParentDirectoryExists() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            NSLog("Failed to create remote configuration directory: %@", error.localizedDescription)
        }
    }

    func validate(_ connections: [OpenCodeRemoteConnection]) -> Bool {
        let ids = connections.map(\.id)
        return Set(ids).count == ids.count
    }

    func persistSeededConnections() {
        let payload = Payload(connections: seededConnections)

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Failed to persist seeded remote configuration: %@", error.localizedDescription)
        }
    }

    func withFileLock<T>(at fileURL: URL, body: () throws -> T) -> T? {
        let lockURL = fileURL.appendingPathExtension("lock")
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            return nil
        }

        defer {
            flock(descriptor, LOCK_UN)
            close(descriptor)
        }

        guard flock(descriptor, LOCK_EX) == 0 else {
            return nil
        }

        return try? body()
    }

    func withFileLockThrowing(at fileURL: URL, body: () throws -> Void) throws {
        let lockURL = fileURL.appendingPathExtension("lock")
        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            throw OpenCodeRemoteManagerError.fileSystemFailure("Failed to open remote configuration lock file at \(lockURL.path)")
        }

        defer {
            flock(descriptor, LOCK_UN)
            close(descriptor)
        }

        guard flock(descriptor, LOCK_EX) == 0 else {
            throw OpenCodeRemoteManagerError.fileSystemFailure("Failed to acquire remote configuration lock at \(lockURL.path)")
        }

        try body()
    }
}

public func defaultRemoteConfigurationStoreFileURL() -> URL {
    let baseDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/OpenCodeRemoteManager", isDirectory: true)
    return baseDirectory.appendingPathComponent("connections.json")
}
