import Foundation
import Darwin

public actor PersistentDesiredStateStore: DesiredStateStore {
    private struct Payload: Codable {
        var states: [OpenCodeRemoteConnectionID: DesiredConnectionState]
    }

    private let fileURL: URL
    private var states: [OpenCodeRemoteConnectionID: DesiredConnectionState]

    public init(fileURL: URL = defaultDesiredStateStoreFileURL()) {
        self.fileURL = fileURL
        self.states = Self.withFileLock(at: fileURL) {
            Self.load(from: fileURL)
        } ?? [:]
    }

    public func desiredState(for connectionID: OpenCodeRemoteConnectionID) async -> DesiredConnectionState {
        reloadFromDiskUnderLock()
        return states[connectionID] ?? .stopped
    }

    public func setDesiredState(_ state: DesiredConnectionState, for connectionID: OpenCodeRemoteConnectionID) async {
        Self.withFileLock(at: fileURL) {
            states = Self.load(from: fileURL)
            states[connectionID] = state
            persistUnlocked()
        }
    }

    public func allDesiredStates() async -> [OpenCodeRemoteConnectionID: DesiredConnectionState] {
        reloadFromDiskUnderLock()
        return states
    }
}

private extension PersistentDesiredStateStore {
    static func load(from fileURL: URL) -> [OpenCodeRemoteConnectionID: DesiredConnectionState] {
        guard
            let data = try? Data(contentsOf: fileURL),
            let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            return [:]
        }

        return payload.states
    }

    static func withFileLock<T>(at fileURL: URL, body: () throws -> T) -> T? {
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

    func reloadFromDiskUnderLock() {
        states = Self.withFileLock(at: fileURL) {
            Self.load(from: fileURL)
        } ?? states
    }

    func persistUnlocked() {
        let payload = Payload(states: states)

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            let data = try JSONEncoder().encode(payload)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Failed to persist desired connection state: %@", error.localizedDescription)
        }
    }
}

public func defaultDesiredStateStoreFileURL() -> URL {
    let baseDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/OpenCodeRemoteManager", isDirectory: true)
    return baseDirectory.appendingPathComponent("desired-state.json")
}
