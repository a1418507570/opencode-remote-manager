import AppKit

@MainActor
final class OpenCodeRemoteManagerAppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarStatusController: MenuBarStatusController?
    private let legacyLaunchAgentCleaner = LegacyTunnelLaunchAgentCleaner()

    func applicationDidFinishLaunching(_ notification: Notification) {
        legacyLaunchAgentCleaner.cleanup()

        let gateway = CoreConnectionShellGateway()
        let controller = MenuBarAppController(gateway: gateway)
        let statusController = MenuBarStatusController(appController: controller)

        statusController.install()
        controller.loadInitialState()
        menuBarStatusController = statusController
    }
}
