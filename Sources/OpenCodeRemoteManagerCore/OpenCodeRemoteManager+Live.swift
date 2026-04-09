import Foundation

public extension OpenCodeRemoteManager {
    static func live(desiredStateStore: DesiredStateStore = PersistentDesiredStateStore()) -> OpenCodeRemoteManager {
        OpenCodeRemoteManager(
            desiredStateStore: desiredStateStore,
            remoteServiceController: SSHRemoteServiceController(processExecutor: SystemProcessExecutor()),
            tunnelController: SSHTunnelController(processExecutor: SystemProcessExecutor()),
            healthChecker: URLSessionHTTPHealthChecker()
        )
    }
}
