import Foundation

public extension OpenCodeRemoteManager {
    static func live(desiredStateStore: DesiredStateStore = PersistentDesiredStateStore()) -> OpenCodeRemoteManager {
        let connections = OpenCodeRemoteDefaults.connections

        return OpenCodeRemoteManager(
            connections: connections,
            desiredStateStore: desiredStateStore,
            remoteServiceController: SSHRemoteServiceController(processExecutor: SystemProcessExecutor(), connections: connections),
            tunnelController: SSHTunnelController(processExecutor: SystemProcessExecutor()),
            healthChecker: URLSessionHTTPHealthChecker()
        )
    }
}
