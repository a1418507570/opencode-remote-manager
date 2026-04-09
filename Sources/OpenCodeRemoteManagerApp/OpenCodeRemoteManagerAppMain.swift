import AppKit

@main
enum OpenCodeRemoteManagerAppMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let appDelegate = OpenCodeRemoteManagerAppDelegate()

        application.setActivationPolicy(.accessory)
        application.delegate = appDelegate

        withExtendedLifetime(appDelegate) {
            application.run()
        }
    }
}
