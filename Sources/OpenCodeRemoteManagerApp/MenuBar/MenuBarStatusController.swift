import AppKit

@MainActor
final class MenuBarStatusController: NSObject, NSMenuDelegate {
    private let appController: MenuBarAppController
    private let statusItem: NSStatusItem
    private let menu: NSMenu

    init(appController: MenuBarAppController) {
        self.appController = appController
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.menu = NSMenu()

        super.init()

        menu.delegate = self
        appController.onChange = { [weak self] in
            self?.rebuildMenu()
        }
    }

    func install() {
        statusItem.menu = menu
        updateStatusButton()
        rebuildMenu()
    }

    func menuWillOpen(_ menu: NSMenu) {
        appController.perform(.refreshAll, for: nil)
        rebuildMenu()
    }
}

private extension MenuBarStatusController {
    func updateStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        let image = NSImage(
            systemSymbolName: appController.statusItemSymbolName,
            accessibilityDescription: "OpenCode Remote Manager"
        )

        image?.isTemplate = true

        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = appController.statusItemToolTip
    }

    func rebuildMenu() {
        menu.removeAllItems()

        let snapshots = appController.orderedSnapshots

        for index in snapshots.indices {
            appendSection(for: snapshots[index])

            if index < snapshots.index(before: snapshots.endIndex) {
                menu.addItem(.separator())
            }
        }

        if !snapshots.isEmpty {
            menu.addItem(.separator())
        }

        if let footerMessage = appController.footerMessage {
            menu.addItem(makeInfoItem(title: footerMessage))
            menu.addItem(.separator())
        }

        menu.addItem(makeActionItem(title: "Bootstrap Remote Persistence", action: .bootstrapRemote, connectionID: nil))
        menu.addItem(makeActionItem(title: "Refresh All", action: .refreshAll, connectionID: nil))
        menu.addItem(makeActionItem(title: "Quit", action: .quit, connectionID: nil))

        updateStatusButton()
    }

    func appendSection(for snapshot: ConnectionSnapshot) {
        menu.addItem(makeHeaderItem(for: snapshot))
        menu.addItem(makeInfoItem(title: "URL: \(snapshot.descriptor.fixedURL.absoluteString)"))
        menu.addItem(makeInfoItem(title: "Remote: \(snapshot.remote.detail)"))
        menu.addItem(makeInfoItem(title: "Tunnel: \(snapshot.tunnel.detail)"))
        menu.addItem(makeInfoItem(title: "HTTP: \(snapshot.http.detail)"))
        menu.addItem(.separator())

        let connectionID = snapshot.descriptor.id
        let actions: [(String, MenuBarAppController.MenuAction)] = [
            ("Start", .start),
            ("Stop", .stop),
            ("Restart", .restart),
            ("Repair", .repair),
            ("Copy URL", .copyURL),
            ("Open URL", .openURL),
            ("Refresh", .refresh),
        ]

        for (title, action) in actions {
            let menuItem = makeActionItem(title: title, action: action, connectionID: connectionID)
            menuItem.isEnabled = appController.canPerform(action, on: snapshot)
            menu.addItem(menuItem)
        }
    }

    func makeHeaderItem(for snapshot: ConnectionSnapshot) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let title = "\(snapshot.descriptor.id.displayName) — \(snapshot.overallStatusText)"

        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
            ]
        )
        item.isEnabled = false
        return item
    }

    func makeInfoItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    func makeActionItem(
        title: String,
        action: MenuBarAppController.MenuAction,
        connectionID: RemoteConnectionID?
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(handleMenuAction(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = MenuCommandPayload(action: action, connectionID: connectionID)
        return item
    }

    @objc
    func handleMenuAction(_ sender: NSMenuItem) {
        guard let command = sender.representedObject as? MenuCommandPayload else {
            return
        }

        appController.perform(command.action, for: command.connectionID)
        rebuildMenu()
    }
}

private final class MenuCommandPayload: NSObject {
    let action: MenuBarAppController.MenuAction
    let connectionID: RemoteConnectionID?

    init(action: MenuBarAppController.MenuAction, connectionID: RemoteConnectionID?) {
        self.action = action
        self.connectionID = connectionID
    }
}
