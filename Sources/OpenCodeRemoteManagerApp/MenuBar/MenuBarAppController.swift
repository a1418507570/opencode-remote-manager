import AppKit
import Foundation
import OpenCodeRemoteManagerCore

@MainActor
final class MenuBarAppController {
    typealias SleepHandler = @Sendable (UInt64) async -> Void

    private enum Constants {
        static let reconcileIntervalNanoseconds: UInt64 = 30_000_000_000
    }

    enum MenuAction {
        case start
        case stop
        case restart
        case repair
        case copyURL
        case openURL
        case refresh
        case refreshAll
        case bootstrapRemote
        case quit
    }

    private let gateway: ConnectionShellGateway
    private let reconcileIntervalNanoseconds: UInt64
    private let sleeper: SleepHandler
    private(set) var orderedSnapshots: [ConnectionSnapshot] = []
    var onChange: (() -> Void)?

    private var lastMessage: String?
    private var lastError: String?
    private var reconcileTask: Task<Void, Never>?

    init(
        gateway: ConnectionShellGateway,
        reconcileIntervalNanoseconds: UInt64 = Constants.reconcileIntervalNanoseconds,
        sleeper: @escaping SleepHandler = MenuBarAppController.defaultSleep
    ) {
        self.gateway = gateway
        self.reconcileIntervalNanoseconds = reconcileIntervalNanoseconds
        self.sleeper = sleeper
    }

    deinit {
        reconcileTask?.cancel()
    }

    var statusItemSymbolName: String {
        if orderedSnapshots.allSatisfy(\.isHealthy), !orderedSnapshots.isEmpty {
            return "bolt.horizontal.circle.fill"
        }

        if orderedSnapshots.contains(where: \.hasAttentionState) || lastError != nil {
            return "exclamationmark.triangle.fill"
        }

        if orderedSnapshots.contains(where: { !$0.isStopped }) {
            return "bolt.horizontal.circle"
        }

        return "bolt.horizontal.circle"
    }

    var statusItemToolTip: String {
        var lines = orderedSnapshots.map { "\($0.descriptor.displayName): \($0.overallStatusText)" }

        if let footerMessage {
            lines.append(footerMessage)
        }

        return lines.joined(separator: "\n")
    }

    var footerMessage: String? {
        lastError ?? lastMessage
    }

    func loadInitialState() {
        Task {
            orderedSnapshots = await gateway.loadSnapshots()
            onChange?()

            orderedSnapshots = await gateway.reconcileDesiredConnections()
            lastMessage = "Reconciled desired connection state."
            onChange?()
        }

        startBackgroundReconcileLoop()
    }

    func perform(_ action: MenuAction, for connectionID: OpenCodeRemoteConnectionID?) {
        switch action {
        case .copyURL:
            copyURL(for: connectionID)
        case .openURL:
            openURL(for: connectionID)
        case .quit:
            NSApplication.shared.terminate(nil)
        default:
            Task { await handleAsyncAction(action, connectionID: connectionID) }
        }
    }

    func canPerform(_ action: MenuAction, on snapshot: ConnectionSnapshot) -> Bool {
        switch action {
        case .start:
            return !snapshot.isHealthy
        case .stop:
            return !snapshot.isStopped
        case .restart, .repair, .copyURL, .openURL, .refresh:
            return true
        case .refreshAll, .bootstrapRemote, .quit:
            return true
        }
    }

    func stopBackgroundReconcileLoop() {
        reconcileTask?.cancel()
        reconcileTask = nil
    }

    static func defaultSleep(nanoseconds: UInt64) async {
        try? await Task.sleep(nanoseconds: nanoseconds)
    }
}

private extension MenuBarAppController {
    func handleAsyncAction(_ action: MenuAction, connectionID: OpenCodeRemoteConnectionID?) async {
        do {
            switch action {
            case .start:
                orderedSnapshots = try await replacingSnapshot(action: .start, for: connectionID)
                lastMessage = "Started \(displayName(for: connectionID) ?? "connection")."
            case .stop:
                orderedSnapshots = try await replacingSnapshot(action: .stop, for: connectionID)
                lastMessage = "Stopped \(displayName(for: connectionID) ?? "connection")."
            case .restart:
                orderedSnapshots = try await replacingSnapshot(action: .restart, for: connectionID)
                lastMessage = "Restarted \(displayName(for: connectionID) ?? "connection")."
            case .repair:
                orderedSnapshots = try await replacingSnapshot(action: .repair, for: connectionID)
                lastMessage = "Repair completed for \(displayName(for: connectionID) ?? "connection")."
            case .refresh:
                orderedSnapshots = try await replacingSnapshot(action: .refresh, for: connectionID)
                lastMessage = nil
            case .refreshAll:
                orderedSnapshots = await gateway.loadSnapshots()
                lastMessage = nil
            case .bootstrapRemote:
                _ = try await gateway.bootstrapRemote()
                orderedSnapshots = await gateway.loadSnapshots()
                lastMessage = "Installed remote bootstrap persistence."
            case .copyURL, .openURL, .quit:
                break
            }

            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }

        onChange?()
    }

    func replacingSnapshot(action: ConnectionCommand, for connectionID: OpenCodeRemoteConnectionID?) async throws -> [ConnectionSnapshot] {
        guard let connectionID else {
            return await gateway.loadSnapshots()
        }

        let next = try await gateway.send(action, to: connectionID)
        return orderedSnapshots.map { $0.descriptor.id == connectionID ? next : $0 }
    }

    func copyURL(for connectionID: OpenCodeRemoteConnectionID?) {
        guard let snapshot = snapshot(for: connectionID) else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(snapshot.descriptor.fixedURL.absoluteString, forType: .string)
        lastMessage = "Copied \(snapshot.descriptor.displayName) URL."
        lastError = nil
        onChange?()
    }

    func openURL(for connectionID: OpenCodeRemoteConnectionID?) {
        guard let snapshot = snapshot(for: connectionID) else {
            return
        }

        NSWorkspace.shared.open(snapshot.descriptor.fixedURL)
        lastMessage = "Opened \(snapshot.descriptor.displayName) endpoint."
        lastError = nil
        onChange?()
    }

    func snapshot(for connectionID: OpenCodeRemoteConnectionID?) -> ConnectionSnapshot? {
        guard let connectionID else {
            return nil
        }

        return orderedSnapshots.first(where: { $0.descriptor.id == connectionID })
    }

    func displayName(for connectionID: OpenCodeRemoteConnectionID?) -> String? {
        guard let connectionID else {
            return nil
        }

        return orderedSnapshots.first(where: { $0.descriptor.id == connectionID })?.descriptor.displayName
    }

    func startBackgroundReconcileLoop() {
        reconcileTask?.cancel()
        reconcileTask = Task { [weak self] in
            guard let self else {
                return
            }

            while Task.isCancelled == false {
                await sleeper(reconcileIntervalNanoseconds)
                if Task.isCancelled {
                    return
                }

                orderedSnapshots = await gateway.reconcileDesiredConnections()
                onChange?()
            }
        }
    }
}
