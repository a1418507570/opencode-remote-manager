import Foundation

public protocol DesiredStateStore: Sendable {
    func desiredState(for connectionID: OpenCodeRemoteConnectionID) async -> DesiredConnectionState
    func setDesiredState(_ state: DesiredConnectionState, for connectionID: OpenCodeRemoteConnectionID) async
    func allDesiredStates() async -> [OpenCodeRemoteConnectionID: DesiredConnectionState]
}

public actor InMemoryDesiredStateStore: DesiredStateStore {
    private var states: [OpenCodeRemoteConnectionID: DesiredConnectionState]

    public init(initialStates: [OpenCodeRemoteConnectionID: DesiredConnectionState] = [:]) {
        self.states = initialStates
    }

    public func desiredState(for connectionID: OpenCodeRemoteConnectionID) async -> DesiredConnectionState {
        states[connectionID] ?? .stopped
    }

    public func setDesiredState(_ state: DesiredConnectionState, for connectionID: OpenCodeRemoteConnectionID) async {
        states[connectionID] = state
    }

    public func allDesiredStates() async -> [OpenCodeRemoteConnectionID: DesiredConnectionState] {
        states
    }
}

public struct OpenCodeRemoteManager: Sendable {
    private let desiredStateStore: DesiredStateStore
    private let remoteServiceController: RemoteServiceControlling
    private let tunnelController: TunnelControlling
    private let healthChecker: HTTPHealthChecking
    private let dateProvider: DateProviding

    public init(
        desiredStateStore: DesiredStateStore = InMemoryDesiredStateStore(),
        remoteServiceController: RemoteServiceControlling,
        tunnelController: TunnelControlling,
        healthChecker: HTTPHealthChecking,
        dateProvider: DateProviding = SystemDateProvider()
    ) {
        self.desiredStateStore = desiredStateStore
        self.remoteServiceController = remoteServiceController
        self.tunnelController = tunnelController
        self.healthChecker = healthChecker
        self.dateProvider = dateProvider
    }

    public func connections() -> [OpenCodeRemoteConnection] {
        OpenCodeRemoteDefaults.connections
    }

    public func snapshot(for connectionID: OpenCodeRemoteConnectionID) async throws -> OpenCodeRemoteSnapshot {
        let connection = OpenCodeRemoteDefaults.connection(for: connectionID)
        let desiredState = await desiredStateStore.desiredState(for: connectionID)
        async let remoteState = safeRemoteServiceState(for: connection)
        async let tunnelState = safeTunnelState(for: connection)
        async let health = healthChecker.check(connection: connection)

        let state = OpenCodeRemoteState(
            desiredState: desiredState,
            remoteServiceState: await remoteState,
            tunnelState: await tunnelState,
            httpHealthState: await health.state
        )

        return OpenCodeRemoteSnapshot(connection: connection, state: state, observedAt: dateProvider.now)
    }

    public func diagnose() async throws -> OpenCodeDiagnosticsReport {
        var reports: [ConnectionDiagnosticReport] = []

        for connection in OpenCodeRemoteDefaults.connections {
            let snapshot = try await snapshot(for: connection.id)
            let checks = buildChecks(for: snapshot)
            let actions = buildRecommendedActions(from: snapshot.state)
            reports.append(ConnectionDiagnosticReport(snapshot: snapshot, checks: checks, recommendedActions: actions))
        }

        return OpenCodeDiagnosticsReport(generatedAt: dateProvider.now, connections: reports)
    }

    public func start(_ connectionID: OpenCodeRemoteConnectionID) async throws -> OpenCodeRemoteSnapshot {
        let connection = OpenCodeRemoteDefaults.connection(for: connectionID)
        await desiredStateStore.setDesiredState(.running, for: connectionID)
        try await remoteServiceController.start(connection)
        try await tunnelController.start(connection)
        return try await snapshot(for: connectionID)
    }

    public func stop(_ connectionID: OpenCodeRemoteConnectionID) async throws -> OpenCodeRemoteSnapshot {
        let connection = OpenCodeRemoteDefaults.connection(for: connectionID)
        await desiredStateStore.setDesiredState(.stopped, for: connectionID)
        try await tunnelController.stop(connection)
        try await remoteServiceController.stop(connection)
        return try await snapshot(for: connectionID)
    }

    public func restart(_ connectionID: OpenCodeRemoteConnectionID) async throws -> OpenCodeRemoteSnapshot {
        let connection = OpenCodeRemoteDefaults.connection(for: connectionID)
        await desiredStateStore.setDesiredState(.running, for: connectionID)
        try await remoteServiceController.restart(connection)
        try await tunnelController.restart(connection)
        return try await snapshot(for: connectionID)
    }

    public func repair(_ connectionID: OpenCodeRemoteConnectionID) async throws -> OpenCodeRemoteSnapshot {
        let connection = OpenCodeRemoteDefaults.connection(for: connectionID)
        await desiredStateStore.setDesiredState(.running, for: connectionID)

        if await safeRemoteServiceState(for: connection) != .running {
            try await remoteServiceController.start(connection)
        }

        if await safeTunnelState(for: connection) != .running {
            try await tunnelController.start(connection)
        }

        let health = await healthChecker.check(connection: connection)
        if health.state != .healthy {
            try await tunnelController.restart(connection)
        }

        return try await snapshot(for: connectionID)
    }

    public func bootstrapRemote(dryRun: Bool) async throws -> [String] {
        try await remoteServiceController.bootstrapRemote(dryRun: dryRun)
    }

    public func desiredState(for connectionID: OpenCodeRemoteConnectionID) async -> DesiredConnectionState {
        await desiredStateStore.desiredState(for: connectionID)
    }

    public func desiredConnectionIDs(requiring state: DesiredConnectionState = .running) async -> [OpenCodeRemoteConnectionID] {
        let states = await desiredStateStore.allDesiredStates()
        return OpenCodeRemoteConnectionID.allCases.filter { states[$0] == state }
    }

    private func buildChecks(for snapshot: OpenCodeRemoteSnapshot) -> [DiagnosticCheck] {
        let state = snapshot.state

        return [
            DiagnosticCheck(
                name: "desired-state",
                severity: .info,
                success: true,
                summary: "Desired state is \(state.desiredState.rawValue)."
            ),
            DiagnosticCheck(
                name: "remote-service",
                severity: state.remoteServiceState == .running ? .info : .warning,
                success: state.remoteServiceState == .running,
                summary: "Remote service is \(state.remoteServiceState.rawValue)."
            ),
            DiagnosticCheck(
                name: "tunnel",
                severity: state.tunnelState == .running ? .info : .warning,
                success: state.tunnelState == .running,
                summary: "Tunnel is \(state.tunnelState.rawValue)."
            ),
            DiagnosticCheck(
                name: "http-health",
                severity: state.httpHealthState == .healthy ? .info : .error,
                success: state.httpHealthState == .healthy,
                summary: "HTTP health is \(state.httpHealthState.rawValue)."
            ),
        ]
    }

    private func buildRecommendedActions(from state: OpenCodeRemoteState) -> [String] {
        var actions: [String] = []

        if state.remoteServiceState != .running {
            actions.append("start the remote service")
        }

        if state.tunnelState != .running {
            actions.append("start or restart the SSH tunnel")
        }

        if state.httpHealthState != .healthy {
            actions.append("run a repair or inspect the forwarded localhost endpoint")
        }

        if actions.isEmpty {
            actions.append("no action needed")
        }

        return actions
    }

    private func safeRemoteServiceState(for connection: OpenCodeRemoteConnection) async -> RemoteServiceState {
        do {
            return try await remoteServiceController.state(for: connection)
        } catch {
            return .unknown
        }
    }

    private func safeTunnelState(for connection: OpenCodeRemoteConnection) async -> TunnelState {
        do {
            return try await tunnelController.state(for: connection)
        } catch {
            return .unknown
        }
    }
}
