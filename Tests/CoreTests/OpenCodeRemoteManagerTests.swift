import Foundation
import Testing
@testable import OpenCodeRemoteManagerCore

struct OpenCodeRemoteManagerTests {
    @Test
    func diagnoseReflectsSeparatedStatesAndSuggestedActions() async throws {
        let manager = makeManager(
            remoteController: MockRemoteServiceController(states: [.go: .stopped, .java: .running]),
            tunnelController: MockTunnelController(states: [.go: .running, .java: .running]),
            healthChecker: MockHealthChecker(results: [.go: .init(state: .unreachable), .java: .init(state: .healthy)]),
            dateProvider: FixedDateProvider(now: Date(timeIntervalSince1970: 1_234))
        )

        let report = try await manager.diagnose()
        #expect(report.connections.count == 2)

        let goReport = try #require(report.connections.first { $0.snapshot.connection.id == .go })
        #expect(goReport.snapshot.state.desiredState == .stopped)
        #expect(goReport.snapshot.state.remoteServiceState == .stopped)
        #expect(goReport.snapshot.state.tunnelState == .running)
        #expect(goReport.snapshot.state.httpHealthState == .unreachable)
        #expect(goReport.recommendedActions.contains("start the remote service"))
        #expect(goReport.recommendedActions.contains("run a repair or inspect the forwarded localhost endpoint"))
    }

    @Test
    func startRunsRemoteThenTunnelAndPersistsDesiredState() async throws {
        let remoteController = MockRemoteServiceController(states: [.go: .running])
        let tunnelController = MockTunnelController(states: [.go: .running])
        let manager = makeManager(
            remoteController: remoteController,
            tunnelController: tunnelController,
            healthChecker: MockHealthChecker(results: [.go: .init(state: .healthy)]),
            dateProvider: FixedDateProvider(now: .distantPast)
        )

        let snapshot = try await manager.start(.go)

        #expect(snapshot.state.desiredState == .running)
        #expect(await remoteController.operations == ["start:go", "state:go"])
        #expect(await tunnelController.operations == ["start:go", "state:go"])
    }

    @Test
    func repairStartsMissingRemoteAndTunnel() async throws {
        let remoteController = MockRemoteServiceController(states: [.java: .stopped])
        let tunnelController = MockTunnelController(states: [.java: .stopped])
        let manager = makeManager(
            remoteController: remoteController,
            tunnelController: tunnelController,
            healthChecker: MockHealthChecker(results: [.java: .init(state: .healthy)]),
            dateProvider: FixedDateProvider(now: .distantPast)
        )

        let snapshot = try await manager.repair(.java)

        #expect(snapshot.state.desiredState == .running)
        #expect(await remoteController.operations == ["state:java", "start:java", "state:java"])
        #expect(await tunnelController.operations == ["state:java", "start:java", "state:java"])
    }

    @Test
    func snapshotPreservesDesiredStateWhenStatusChecksThrow() async throws {
        let manager = OpenCodeRemoteManager(
            connections: OpenCodeRemoteDefaults.connections,
            desiredStateStore: InMemoryDesiredStateStore(initialStates: [.go: .running]),
            remoteServiceController: ThrowingRemoteServiceController(),
            tunnelController: ThrowingTunnelController(),
            healthChecker: MockHealthChecker(results: [.go: .init(state: .unknown)]),
            dateProvider: FixedDateProvider(now: .distantPast)
        )

        let snapshot = try await manager.snapshot(for: .go)

        #expect(snapshot.state.desiredState == .running)
        #expect(snapshot.state.remoteServiceState == .unknown)
        #expect(snapshot.state.tunnelState == .unknown)
    }

    @Test
    func repairTreatsProbeFailuresAsNeedingRepair() async throws {
        let remoteController = ProbeFailingRemoteServiceController()
        let tunnelController = ProbeFailingTunnelController()
        let manager = OpenCodeRemoteManager(
            connections: OpenCodeRemoteDefaults.connections,
            desiredStateStore: InMemoryDesiredStateStore(initialStates: [.go: .running]),
            remoteServiceController: remoteController,
            tunnelController: tunnelController,
            healthChecker: MockHealthChecker(results: [.go: .init(state: .healthy)]),
            dateProvider: FixedDateProvider(now: .distantPast)
        )

        let snapshot = try await manager.repair(.go)

        #expect(snapshot.state.desiredState == .running)
        #expect(await remoteController.operations == ["state:go", "start:go", "state:go"])
        #expect(await tunnelController.operations == ["state:go", "start:go", "state:go"])
    }

    @Test
    func startThrowsUnknownConnectionForUnconfiguredID() async throws {
        let manager = OpenCodeRemoteManager(
            connections: [OpenCodeRemoteDefaults.connection(for: .go)],
            desiredStateStore: InMemoryDesiredStateStore(),
            remoteServiceController: MockRemoteServiceController(states: [.go: .running]),
            tunnelController: MockTunnelController(states: [.go: .running]),
            healthChecker: MockHealthChecker(results: [.go: .init(state: .healthy)]),
            dateProvider: FixedDateProvider(now: .distantPast)
        )

        do {
            _ = try await manager.start(OpenCodeRemoteConnectionID(rawValue: "missing"))
            Issue.record("Expected unknown connection error for unconfigured ID")
        } catch let error as OpenCodeRemoteManagerError {
            #expect(error.errorDescription == "Unknown connection: missing")
        } catch {
            Issue.record("Unexpected error type: \(error.localizedDescription)")
        }
    }

    private func makeManager(
        remoteController: MockRemoteServiceController,
        tunnelController: MockTunnelController,
        healthChecker: MockHealthChecker,
        dateProvider: FixedDateProvider
    ) -> OpenCodeRemoteManager {
        OpenCodeRemoteManager(
            connections: OpenCodeRemoteDefaults.connections,
            desiredStateStore: InMemoryDesiredStateStore(),
            remoteServiceController: remoteController,
            tunnelController: tunnelController,
            healthChecker: healthChecker,
            dateProvider: dateProvider
        )
    }
}

private actor ThrowingRemoteServiceController: RemoteServiceControlling {
    func start(_ connection: OpenCodeRemoteConnection) async throws {}
    func stop(_ connection: OpenCodeRemoteConnection) async throws {}
    func restart(_ connection: OpenCodeRemoteConnection) async throws {}
    func state(for connection: OpenCodeRemoteConnection) async throws -> RemoteServiceState {
        throw OpenCodeRemoteManagerError.processFailure("remote probe failed")
    }
    func bootstrapRemote(dryRun: Bool) async throws -> [String] { [] }
}

private actor ThrowingTunnelController: TunnelControlling {
    func start(_ connection: OpenCodeRemoteConnection) async throws {}
    func stop(_ connection: OpenCodeRemoteConnection) async throws {}
    func restart(_ connection: OpenCodeRemoteConnection) async throws {}
    func state(for connection: OpenCodeRemoteConnection) async throws -> TunnelState {
        throw OpenCodeRemoteManagerError.processFailure("tunnel probe failed")
    }
}

private actor ProbeFailingRemoteServiceController: RemoteServiceControlling {
    private(set) var operations: [String] = []

    func start(_ connection: OpenCodeRemoteConnection) async throws {
        operations.append("start:\(connection.id.rawValue)")
    }

    func stop(_ connection: OpenCodeRemoteConnection) async throws {}
    func restart(_ connection: OpenCodeRemoteConnection) async throws {}

    func state(for connection: OpenCodeRemoteConnection) async throws -> RemoteServiceState {
        operations.append("state:\(connection.id.rawValue)")
        if operations.count == 1 {
            throw OpenCodeRemoteManagerError.processFailure("remote probe failed")
        }
        return .running
    }

    func bootstrapRemote(dryRun: Bool) async throws -> [String] { [] }
}

private actor ProbeFailingTunnelController: TunnelControlling {
    private(set) var operations: [String] = []

    func start(_ connection: OpenCodeRemoteConnection) async throws {
        operations.append("start:\(connection.id.rawValue)")
    }

    func stop(_ connection: OpenCodeRemoteConnection) async throws {}
    func restart(_ connection: OpenCodeRemoteConnection) async throws {}

    func state(for connection: OpenCodeRemoteConnection) async throws -> TunnelState {
        operations.append("state:\(connection.id.rawValue)")
        if operations.count == 1 {
            throw OpenCodeRemoteManagerError.processFailure("tunnel probe failed")
        }
        return .running
    }
}

private actor MockRemoteServiceController: RemoteServiceControlling {
    private var states: [OpenCodeRemoteConnectionID: RemoteServiceState]
    private(set) var operations: [String] = []

    init(states: [OpenCodeRemoteConnectionID: RemoteServiceState]) {
        self.states = states
    }

    func start(_ connection: OpenCodeRemoteConnection) async throws {
        operations.append("start:\(connection.id.rawValue)")
        states[connection.id] = .running
    }

    func stop(_ connection: OpenCodeRemoteConnection) async throws {
        operations.append("stop:\(connection.id.rawValue)")
        states[connection.id] = .stopped
    }

    func restart(_ connection: OpenCodeRemoteConnection) async throws {
        operations.append("restart:\(connection.id.rawValue)")
        states[connection.id] = .running
    }

    func state(for connection: OpenCodeRemoteConnection) async throws -> RemoteServiceState {
        operations.append("state:\(connection.id.rawValue)")
        return states[connection.id] ?? .unknown
    }

    func bootstrapRemote(dryRun: Bool) async throws -> [String] {
        [dryRun ? "dry-run" : "run"]
    }
}

private actor MockTunnelController: TunnelControlling {
    private var states: [OpenCodeRemoteConnectionID: TunnelState]
    private(set) var operations: [String] = []

    init(states: [OpenCodeRemoteConnectionID: TunnelState]) {
        self.states = states
    }

    func start(_ connection: OpenCodeRemoteConnection) async throws {
        operations.append("start:\(connection.id.rawValue)")
        states[connection.id] = .running
    }

    func stop(_ connection: OpenCodeRemoteConnection) async throws {
        operations.append("stop:\(connection.id.rawValue)")
        states[connection.id] = .stopped
    }

    func restart(_ connection: OpenCodeRemoteConnection) async throws {
        operations.append("restart:\(connection.id.rawValue)")
        states[connection.id] = .running
    }

    func state(for connection: OpenCodeRemoteConnection) async throws -> TunnelState {
        operations.append("state:\(connection.id.rawValue)")
        return states[connection.id] ?? .unknown
    }
}

private struct MockHealthChecker: HTTPHealthChecking {
    let results: [OpenCodeRemoteConnectionID: HTTPHealthCheckResult]

    func check(connection: OpenCodeRemoteConnection) async -> HTTPHealthCheckResult {
        results[connection.id] ?? .init(state: .unknown)
    }
}

private struct FixedDateProvider: DateProviding {
    let now: Date
}
