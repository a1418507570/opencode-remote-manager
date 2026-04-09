import Foundation

public struct OpenCodeRemoteConnection: Codable, Hashable, Sendable, Identifiable {
    public let id: OpenCodeRemoteConnectionID
    public let sshAlias: String
    public let localURL: URL
    public let localPort: Int
    public let remotePort: Int

    public init(
        id: OpenCodeRemoteConnectionID,
        sshAlias: String,
        localURL: URL,
        localPort: Int,
        remotePort: Int = 4096
    ) {
        self.id = id
        self.sshAlias = sshAlias
        self.localURL = localURL
        self.localPort = localPort
        self.remotePort = remotePort
    }
}
