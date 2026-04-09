import Foundation

public struct ProcessExecutionRequest: Sendable, Equatable {
    public let executableURL: URL
    public let arguments: [String]
    public let environment: [String: String]

    public init(executableURL: URL, arguments: [String] = [], environment: [String: String] = [:]) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.environment = environment
    }
}

public struct ProcessExecutionResult: Sendable, Equatable {
    public let exitCode: Int32
    public let standardOutput: String
    public let standardError: String

    public init(exitCode: Int32, standardOutput: String = "", standardError: String = "") {
        self.exitCode = exitCode
        self.standardOutput = standardOutput
        self.standardError = standardError
    }
}

public protocol ProcessExecuting: Sendable {
    func run(_ request: ProcessExecutionRequest) async throws -> ProcessExecutionResult
}

public protocol FileManaging: Sendable {
    func createDirectory(at url: URL) throws
    func removeItem(at url: URL) throws
    func fileExists(at url: URL) -> Bool
}

public struct FoundationFileManager: FileManaging {
    public init() {}

    public func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func removeItem(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
    }

    public func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}

public protocol DateProviding: Sendable {
    var now: Date { get }
}

public struct SystemDateProvider: DateProviding {
    public init() {}

    public var now: Date { Date() }
}

public enum OpenCodeRemoteManagerError: Error, LocalizedError, Sendable {
    case unknownConnection(String)
    case invalidCommand(String)
    case processFailure(String)
    case fileSystemFailure(String)

    public var errorDescription: String? {
        switch self {
        case .unknownConnection(let value):
            "Unknown connection: \(value)"
        case .invalidCommand(let value):
            value
        case .processFailure(let value):
            value
        case .fileSystemFailure(let value):
            value
        }
    }
}
