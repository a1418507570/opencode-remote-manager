import Foundation
import Testing
@testable import OpenCodeRemoteManagerApp
import OpenCodeRemoteManagerCore

@MainActor
struct MenuBarAppControllerTests {
    @Test
    func backgroundReconcileLoopRefreshesSnapshotsWithoutMenuInteraction() async throws {
        let initialSnapshot = makeSnapshot(id: .go, desiredState: .running, tunnel: .failed(reason: "stopped"))
        let healthySnapshot = makeSnapshot(id: .go, desiredState: .running, tunnel: .healthy)
        let gateway = TestConnectionShellGateway(loadSnapshots: [initialSnapshot], reconcileSnapshots: [healthySnapshot])

        let controller = MenuBarAppController(
            gateway: gateway,
            reconcileIntervalNanoseconds: 1_000_000,
            sleeper: { _ in try? await Task.sleep(nanoseconds: 1_000_000) }
        )

        controller.loadInitialState()
        try await Task.sleep(nanoseconds: 30_000_000)
        controller.stopBackgroundReconcileLoop()

        #expect(await gateway.reconcileCallCount >= 2)
        #expect(controller.orderedSnapshots.first?.tunnel == .healthy)
    }

    private func makeSnapshot(
        id: RemoteConnectionID,
        desiredState: DesiredConnectionState,
        tunnel: ConnectionHealthState
    ) -> ConnectionSnapshot {
        ConnectionSnapshot(
            descriptor: ConnectionDescriptor(
                id: id,
                fixedURL: OpenCodeRemoteDefaults.connection(for: id.coreID).localURL
            ),
            desiredState: desiredState,
            remote: .healthy,
            tunnel: tunnel,
            http: .healthy,
            observedAt: Date()
        )
    }
}

@MainActor
private final class TestConnectionShellGateway: ConnectionShellGateway {
    private let loadSnapshotsValue: [ConnectionSnapshot]
    private let reconcileSnapshotsValue: [ConnectionSnapshot]
    private(set) var reconcileCallCount = 0

    init(loadSnapshots: [ConnectionSnapshot], reconcileSnapshots: [ConnectionSnapshot]) {
        self.loadSnapshotsValue = loadSnapshots
        self.reconcileSnapshotsValue = reconcileSnapshots
    }

    func loadSnapshots() async -> [ConnectionSnapshot] {
        loadSnapshotsValue
    }

    func reconcileDesiredConnections() async -> [ConnectionSnapshot] {
        reconcileCallCount += 1
        return reconcileSnapshotsValue
    }

    func send(_ command: ConnectionCommand, to connectionID: RemoteConnectionID) async throws -> ConnectionSnapshot {
        reconcileSnapshotsValue[0]
    }

    func bootstrapRemote() async throws -> [String] {
        []
    }
}
