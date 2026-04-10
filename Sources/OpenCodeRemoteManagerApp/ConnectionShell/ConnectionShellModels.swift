import Foundation
import OpenCodeRemoteManagerCore

struct ConnectionDescriptor: Hashable, Sendable {
    let id: OpenCodeRemoteConnectionID
    let fixedURL: URL

    var displayName: String {
        switch id.rawValue {
        case OpenCodeRemoteConnectionID.go.rawValue:
            return "Go"
        case OpenCodeRemoteConnectionID.java.rawValue:
            return "Java"
        default:
            return id.rawValue
                .split(separator: "-")
                .map { $0.capitalized }
                .joined(separator: " ")
        }
    }
}

enum ConnectionHealthState: Sendable, Equatable {
    case healthy
    case degraded(reason: String)
    case stopped
    case failed(reason: String)
    case unknown

    var title: String {
        switch self {
        case .healthy:
            return "Healthy"
        case .degraded:
            return "Degraded"
        case .stopped:
            return "Stopped"
        case .failed:
            return "Failed"
        case .unknown:
            return "Unknown"
        }
    }

    var detail: String {
        switch self {
        case .healthy:
            return "Healthy"
        case .degraded(let reason):
            return "Degraded — \(reason)"
        case .stopped:
            return "Stopped"
        case .failed(let reason):
            return "Failed — \(reason)"
        case .unknown:
            return "Unknown"
        }
    }

    var needsAttention: Bool {
        switch self {
        case .degraded, .failed:
            return true
        case .healthy, .stopped, .unknown:
            return false
        }
    }

    var isHealthy: Bool {
        self == .healthy
    }

    var isStopped: Bool {
        self == .stopped
    }
}

struct ConnectionSnapshot: Sendable, Equatable {
    let descriptor: ConnectionDescriptor
    let desiredState: DesiredConnectionState
    let remote: ConnectionHealthState
    let tunnel: ConnectionHealthState
    let http: ConnectionHealthState
    let observedAt: Date

    var overallStatusText: String {
        if isHealthy {
            return "All services healthy"
        }

        if isStopped {
            return "Stopped"
        }

        if hasAttentionState {
            return desiredState == .running ? "Needs attention" : "Partially stopped"
        }

        return "Checking status"
    }

    var isHealthy: Bool {
        remote.isHealthy && tunnel.isHealthy && http.isHealthy
    }

    var isStopped: Bool {
        desiredState == .stopped && remote.isStopped && tunnel.isStopped
    }

    var hasAttentionState: Bool {
        remote.needsAttention || tunnel.needsAttention || http.needsAttention
    }
}

enum ConnectionCommand: Sendable {
    case start
    case stop
    case restart
    case repair
    case refresh
}

extension ConnectionSnapshot {
    init(coreSnapshot: OpenCodeRemoteSnapshot) {
        let desiredState = coreSnapshot.state.desiredState

        self.init(
            descriptor: ConnectionDescriptor(
                id: coreSnapshot.connection.id,
                fixedURL: coreSnapshot.connection.localURL
            ),
            desiredState: desiredState,
            remote: Self.serviceHealth(from: coreSnapshot.state.remoteServiceState, desiredState: desiredState),
            tunnel: Self.tunnelHealth(from: coreSnapshot.state.tunnelState, desiredState: desiredState),
            http: Self.httpHealth(from: coreSnapshot.state.httpHealthState, desiredState: desiredState),
            observedAt: coreSnapshot.observedAt
        )
    }

    private static func serviceHealth(
        from value: RemoteServiceState,
        desiredState: DesiredConnectionState
    ) -> ConnectionHealthState {
        switch value {
        case .running:
            return .healthy
        case .stopped:
            return desiredState == .stopped ? .stopped : .failed(reason: "Service is not running")
        case .unknown:
            return .unknown
        }
    }

    private static func tunnelHealth(
        from value: TunnelState,
        desiredState: DesiredConnectionState
    ) -> ConnectionHealthState {
        switch value {
        case .running:
            return .healthy
        case .stopped:
            return desiredState == .stopped ? .stopped : .failed(reason: "Tunnel is not running")
        case .unknown:
            return .unknown
        }
    }

    private static func httpHealth(
        from value: HTTPHealthState,
        desiredState: DesiredConnectionState
    ) -> ConnectionHealthState {
        switch value {
        case .healthy:
            return .healthy
        case .unhealthy:
            return .degraded(reason: "Health endpoint returned a non-healthy status")
        case .unreachable:
            return desiredState == .stopped ? .stopped : .failed(reason: "`/global/health` is unreachable")
        case .unknown:
            return .unknown
        }
    }
}
