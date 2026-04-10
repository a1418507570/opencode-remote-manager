import Foundation
import OpenCodeRemoteManagerCore

@MainActor
protocol ConnectionShellGateway: AnyObject {
    func loadSnapshots() async -> [ConnectionSnapshot]
    func reconcileDesiredConnections() async -> [ConnectionSnapshot]
    func send(_ command: ConnectionCommand, to connectionID: OpenCodeRemoteConnectionID) async throws -> ConnectionSnapshot
    func bootstrapRemote() async throws -> [String]
}

@MainActor
final class CoreConnectionShellGateway: ConnectionShellGateway {
    private let manager: OpenCodeRemoteManager

    init(manager: OpenCodeRemoteManager = .live(desiredStateStore: PersistentDesiredStateStore())) {
        self.manager = manager
    }

    func loadSnapshots() async -> [ConnectionSnapshot] {
        await loadAllSnapshots()
    }

    func reconcileDesiredConnections() async -> [ConnectionSnapshot] {
        let configuredConnections = manager.connections()
        var snapshotsByID = Dictionary(uniqueKeysWithValues: await loadAllSnapshots().map { ($0.descriptor.id, $0) })
        let desiredConnectionIDs = await manager.desiredConnectionIDs()

        for connectionID in desiredConnectionIDs {
            do {
                let snapshot = try await manager.repair(connectionID)
                snapshotsByID[connectionID] = ConnectionSnapshot(coreSnapshot: snapshot)
            } catch {
                let desiredState = await manager.desiredState(for: connectionID)
                snapshotsByID[connectionID] = failureSnapshot(
                    for: configuredConnections.first(where: { $0.id == connectionID }),
                    desiredState: desiredState,
                    error: error
                )
            }
        }

        return configuredConnections.compactMap { snapshotsByID[$0.id] }
    }

    func send(_ command: ConnectionCommand, to connectionID: OpenCodeRemoteConnectionID) async throws -> ConnectionSnapshot {
        let snapshot: OpenCodeRemoteSnapshot

        switch command {
        case .start:
            snapshot = try await manager.start(connectionID)
        case .stop:
            snapshot = try await manager.stop(connectionID)
        case .restart:
            snapshot = try await manager.restart(connectionID)
        case .repair:
            snapshot = try await manager.repair(connectionID)
        case .refresh:
            snapshot = try await manager.snapshot(for: connectionID)
        }

        return ConnectionSnapshot(coreSnapshot: snapshot)
    }

    func bootstrapRemote() async throws -> [String] {
        try await manager.bootstrapRemote(dryRun: false)
    }
}

private extension CoreConnectionShellGateway {
    func loadAllSnapshots() async -> [ConnectionSnapshot] {
        var snapshots: [ConnectionSnapshot] = []

        for connection in manager.connections() {
            do {
                let snapshot = try await manager.snapshot(for: connection.id)
                snapshots.append(ConnectionSnapshot(coreSnapshot: snapshot))
            } catch {
                let desiredState = await manager.desiredState(for: connection.id)
                snapshots.append(failureSnapshot(for: connection, desiredState: desiredState, error: error))
            }
        }

        return snapshots
    }

    func failureSnapshot(
        for connection: OpenCodeRemoteConnection?,
        desiredState: DesiredConnectionState,
        error: Error
    ) -> ConnectionSnapshot {
        let descriptor = ConnectionDescriptor(
            id: connection?.id ?? OpenCodeRemoteConnectionID(rawValue: "unknown"),
            fixedURL: connection?.localURL ?? URL(string: "http://127.0.0.1")!
        )

        return ConnectionSnapshot(
            descriptor: descriptor,
            desiredState: desiredState,
            remote: .failed(reason: error.localizedDescription),
            tunnel: .unknown,
            http: .unknown,
            observedAt: Date()
        )
    }
}
