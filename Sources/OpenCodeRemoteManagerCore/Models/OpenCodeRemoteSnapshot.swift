import Foundation

public struct OpenCodeRemoteSnapshot: Codable, Sendable {
    public let connection: OpenCodeRemoteConnection
    public let state: OpenCodeRemoteState
    public let observedAt: Date

    public init(connection: OpenCodeRemoteConnection, state: OpenCodeRemoteState, observedAt: Date) {
        self.connection = connection
        self.state = state
        self.observedAt = observedAt
    }
}
