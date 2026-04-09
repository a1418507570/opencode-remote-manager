import Foundation

public enum OpenCodeRemoteDefaults {
    public static let connections: [OpenCodeRemoteConnection] = [
        OpenCodeRemoteConnection(
            id: .go,
            sshAlias: "rubyxguo",
            localURL: URL(string: "http://127.0.0.1:14096")!,
            localPort: 14_096
        ),
        OpenCodeRemoteConnection(
            id: .java,
            sshAlias: "nullguo",
            localURL: URL(string: "http://127.0.0.1:24096")!,
            localPort: 24_096
        ),
    ]

    public static let connectionByID: [OpenCodeRemoteConnectionID: OpenCodeRemoteConnection] = Dictionary(
        uniqueKeysWithValues: connections.map { ($0.id, $0) }
    )

    public static func connection(for id: OpenCodeRemoteConnectionID) -> OpenCodeRemoteConnection {
        guard let connection = connectionByID[id] else {
            preconditionFailure("Missing fixed connection definition for \(id.rawValue)")
        }

        return connection
    }
}
