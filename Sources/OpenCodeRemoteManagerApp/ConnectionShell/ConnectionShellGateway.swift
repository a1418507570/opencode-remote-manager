import Foundation
import OpenCodeRemoteManagerCore

@MainActor
protocol ConnectionShellGateway: AnyObject {
    func loadSnapshots() async -> [ConnectionSnapshot]
    func reconcileDesiredConnections() async -> [ConnectionSnapshot]
    func send(_ command: ConnectionCommand, to connectionID: RemoteConnectionID) async throws -> ConnectionSnapshot
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
        var snapshotsByID = Dictionary(uniqueKeysWithValues: await loadAllSnapshots().map { ($0.descriptor.id, $0) })
        let desiredConnectionIDs = await manager.desiredConnectionIDs()

        for connectionID in desiredConnectionIDs {
            let remoteConnectionID = RemoteConnectionID(connectionID)
            do {
                let snapshot = try await manager.repair(connectionID)
                snapshotsByID[remoteConnectionID] = ConnectionSnapshot(coreSnapshot: snapshot)
            } catch {
                let desiredState = await manager.desiredState(for: connectionID)
                snapshotsByID[remoteConnectionID] = failureSnapshot(
                    for: remoteConnectionID,
                    desiredState: desiredState,
                    error: error
                )
            }
        }

        return RemoteConnectionID.allCases.compactMap { snapshotsByID[$0] }
    }

    func send(_ command: ConnectionCommand, to connectionID: RemoteConnectionID) async throws -> ConnectionSnapshot {
        let snapshot: OpenCodeRemoteSnapshot

        switch command {
        case .start:
            snapshot = try await manager.start(connectionID.coreID)
        case .stop:
            snapshot = try await manager.stop(connectionID.coreID)
        case .restart:
            snapshot = try await manager.restart(connectionID.coreID)
        case .repair:
            snapshot = try await manager.repair(connectionID.coreID)
        case .refresh:
            snapshot = try await manager.snapshot(for: connectionID.coreID)
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

        for connectionID in RemoteConnectionID.allCases {
            do {
                let snapshot = try await manager.snapshot(for: connectionID.coreID)
                snapshots.append(ConnectionSnapshot(coreSnapshot: snapshot))
            } catch {
                let desiredState = await manager.desiredState(for: connectionID.coreID)
                snapshots.append(failureSnapshot(for: connectionID, desiredState: desiredState, error: error))
            }
        }

        return snapshots
    }

    func failureSnapshot(
        for connectionID: RemoteConnectionID,
        desiredState: DesiredConnectionState,
        error: Error
    ) -> ConnectionSnapshot {
        ConnectionSnapshot(
            descriptor: ConnectionDescriptor(
                id: connectionID,
                fixedURL: OpenCodeRemoteDefaults.connection(for: connectionID.coreID).localURL
            ),
            desiredState: desiredState,
            remote: .failed(reason: error.localizedDescription),
            tunnel: .unknown,
            http: .unknown,
            observedAt: Date()
        )
    }
}
