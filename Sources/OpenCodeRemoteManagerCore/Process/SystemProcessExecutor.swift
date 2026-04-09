import Foundation

public struct SystemProcessExecutor: ProcessExecuting {
    public init() {}

    public func run(_ request: ProcessExecutionRequest) async throws -> ProcessExecutionResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            process.executableURL = request.executableURL
            process.arguments = request.arguments
            if request.environment.isEmpty == false {
                process.environment = ProcessInfo.processInfo.environment.merging(request.environment) { _, new in new }
            }
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            process.terminationHandler = { process in
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""

                continuation.resume(
                    returning: ProcessExecutionResult(
                        exitCode: process.terminationStatus,
                        standardOutput: output.trimmingCharacters(in: .whitespacesAndNewlines),
                        standardError: error.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                )
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
