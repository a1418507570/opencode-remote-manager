import Foundation

public enum DesiredConnectionState: String, Codable, Sendable {
    case stopped
    case running
}

public enum RemoteServiceState: String, Codable, Sendable {
    case unknown
    case stopped
    case running
}

public enum TunnelState: String, Codable, Sendable {
    case unknown
    case stopped
    case running
}

public enum HTTPHealthState: String, Codable, Sendable {
    case unknown
    case healthy
    case unreachable
    case unhealthy
}

public struct OpenCodeRemoteState: Codable, Sendable {
    public let desiredState: DesiredConnectionState
    public let remoteServiceState: RemoteServiceState
    public let tunnelState: TunnelState
    public let httpHealthState: HTTPHealthState

    public init(
        desiredState: DesiredConnectionState,
        remoteServiceState: RemoteServiceState,
        tunnelState: TunnelState,
        httpHealthState: HTTPHealthState
    ) {
        self.desiredState = desiredState
        self.remoteServiceState = remoteServiceState
        self.tunnelState = tunnelState
        self.httpHealthState = httpHealthState
    }
}
