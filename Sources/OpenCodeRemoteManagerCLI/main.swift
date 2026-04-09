import Foundation
import OpenCodeRemoteManagerCore

@main
struct OpenCodeRemoteManagerCLI {
    static func main() async {
        do {
            let cli = CLIApplication()
            try await cli.run(arguments: Array(CommandLine.arguments.dropFirst()))
        } catch {
            fputs("\((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)\n", stderr)
            Foundation.exit(1)
        }
    }
}

struct CLIApplication {
    private let manager: OpenCodeRemoteManager
    private let encoder: JSONEncoder

    init(
        manager: OpenCodeRemoteManager = .live()
    ) {
        self.manager = manager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    func run(arguments: [String]) async throws {
        guard let command = arguments.first else {
            throw OpenCodeRemoteManagerError.invalidCommand(usage)
        }

        switch command {
        case "diagnose":
            let json = arguments.contains("--json")
            let report = try await manager.diagnose()
            if json {
                try printJSON(report)
            } else {
                printHuman(report)
            }
        case "start":
            let snapshot = try await manager.start(parseConnectionID(arguments: arguments))
            try printJSON(snapshot)
        case "stop":
            let snapshot = try await manager.stop(parseConnectionID(arguments: arguments))
            try printJSON(snapshot)
        case "restart":
            let snapshot = try await manager.restart(parseConnectionID(arguments: arguments))
            try printJSON(snapshot)
        case "repair":
            let snapshot = try await manager.repair(parseConnectionID(arguments: arguments))
            try printJSON(snapshot)
        case "bootstrap-remote":
            let commands = try await manager.bootstrapRemote(dryRun: arguments.contains("--dry-run"))
            try printJSON(commands)
        default:
            throw OpenCodeRemoteManagerError.invalidCommand(usage)
        }
    }

    private func parseConnectionID(arguments: [String]) throws -> OpenCodeRemoteConnectionID {
        guard arguments.count >= 2 else {
            throw OpenCodeRemoteManagerError.invalidCommand(usage)
        }

        guard let identifier = OpenCodeRemoteConnectionID(rawValue: arguments[1]) else {
            throw OpenCodeRemoteManagerError.unknownConnection(arguments[1])
        }

        return identifier
    }

    private func printJSON<T: Encodable>(_ value: T) throws {
        let data = try encoder.encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw OpenCodeRemoteManagerError.invalidCommand("Failed to encode JSON output.")
        }
        Swift.print(string)
    }

    private func printHuman(_ report: OpenCodeDiagnosticsReport) {
        for connection in report.connections {
            let snapshot = connection.snapshot
            Swift.print("[\(snapshot.connection.id.rawValue)] \(snapshot.connection.localURL.absoluteString)")
            Swift.print("  desired: \(snapshot.state.desiredState.rawValue)")
            Swift.print("  remote:  \(snapshot.state.remoteServiceState.rawValue)")
            Swift.print("  tunnel:  \(snapshot.state.tunnelState.rawValue)")
            Swift.print("  health:  \(snapshot.state.httpHealthState.rawValue)")
            for action in connection.recommendedActions where action != "no action needed" {
                Swift.print("  action:  \(action)")
            }
        }
    }

    private var usage: String {
        """
        Usage:
          diagnose [--json]
          start <id>
          stop <id>
          restart <id>
          repair <id>
          bootstrap-remote [--dry-run]

        Connection IDs: go, java
        """
    }
}
