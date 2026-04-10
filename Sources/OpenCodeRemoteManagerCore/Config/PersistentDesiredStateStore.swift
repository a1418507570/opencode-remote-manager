import Foundation
import Darwin

public actor PersistentDesiredStateStore: DesiredStateStore {
    private struct Payload: Codable {
        var states: [String: DesiredConnectionState]
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
    struct LegacyPayload: Codable {
        var states: [String]
    }

    static func load(from fileURL: URL) -> [OpenCodeRemoteConnectionID: DesiredConnectionState] {
        guard let data = try? Data(contentsOf: fileURL) else {
            return [:]
        }

        if let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            return Dictionary(uniqueKeysWithValues: payload.states.map { (OpenCodeRemoteConnectionID(rawValue: $0.key), $0.value) })
        }

        if let payload = try? JSONDecoder().decode(LegacyPayload.self, from: data) {
            return loadLegacyStates(payload.states)
        }

        return [:]
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
        let payload = Payload(states: Dictionary(uniqueKeysWithValues: states.map { ($0.key.rawValue, $0.value) }))

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

    static func loadLegacyStates(_ rawStates: [String]) -> [OpenCodeRemoteConnectionID: DesiredConnectionState] {
        guard rawStates.count.isMultiple(of: 2) else {
            return [:]
        }

        var decoded: [OpenCodeRemoteConnectionID: DesiredConnectionState] = [:]
        var index = 0
        while index < rawStates.count {
            let id = OpenCodeRemoteConnectionID(rawValue: rawStates[index])
            let value = DesiredConnectionState(rawValue: rawStates[index + 1])
            if let value {
                decoded[id] = value
            }
            index += 2
        }
        return decoded
    }
}

public func defaultDesiredStateStoreFileURL() -> URL {
    let baseDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/OpenCodeRemoteManager", isDirectory: true)
    return baseDirectory.appendingPathComponent("desired-state.json")
}
