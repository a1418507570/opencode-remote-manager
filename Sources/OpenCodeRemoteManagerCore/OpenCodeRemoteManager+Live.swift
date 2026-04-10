import Foundation

public extension OpenCodeRemoteManager {
    static func live(
        desiredStateStore: DesiredStateStore = PersistentDesiredStateStore(),
        remoteConfigurationStore: RemoteConfigurationStore = PersistentRemoteConfigurationStore(seededConnections: OpenCodeRemoteDefaults.connections)
    ) -> OpenCodeRemoteManager {
        let connections = remoteConfigurationStore.loadConnections()

        return OpenCodeRemoteManager(
            connections: connections,
            desiredStateStore: desiredStateStore,
            remoteServiceController: SSHRemoteServiceController(processExecutor: SystemProcessExecutor(), connections: connections),
            tunnelController: SSHTunnelController(processExecutor: SystemProcessExecutor()),
            healthChecker: URLSessionHTTPHealthChecker()
        )
    }
}
