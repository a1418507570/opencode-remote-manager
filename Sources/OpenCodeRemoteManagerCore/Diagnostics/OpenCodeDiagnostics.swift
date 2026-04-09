import Foundation

public enum DiagnosticSeverity: String, Codable, Sendable {
    case info
    case warning
    case error
}

public struct DiagnosticCheck: Codable, Sendable {
    public let name: String
    public let severity: DiagnosticSeverity
    public let success: Bool
    public let summary: String

    public init(name: String, severity: DiagnosticSeverity, success: Bool, summary: String) {
        self.name = name
        self.severity = severity
        self.success = success
        self.summary = summary
    }
}

public struct ConnectionDiagnosticReport: Codable, Sendable {
    public let snapshot: OpenCodeRemoteSnapshot
    public let checks: [DiagnosticCheck]
    public let recommendedActions: [String]

    public init(snapshot: OpenCodeRemoteSnapshot, checks: [DiagnosticCheck], recommendedActions: [String]) {
        self.snapshot = snapshot
        self.checks = checks
        self.recommendedActions = recommendedActions
    }
}

public struct OpenCodeDiagnosticsReport: Codable, Sendable {
    public let generatedAt: Date
    public let connections: [ConnectionDiagnosticReport]

    public init(generatedAt: Date, connections: [ConnectionDiagnosticReport]) {
        self.generatedAt = generatedAt
        self.connections = connections
    }
}
