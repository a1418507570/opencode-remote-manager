import Foundation

public struct HTTPHealthCheckResult: Codable, Sendable {
    public let state: HTTPHealthState
    public let statusCode: Int?
    public let detail: String?

    public init(state: HTTPHealthState, statusCode: Int? = nil, detail: String? = nil) {
        self.state = state
        self.statusCode = statusCode
        self.detail = detail
    }
}

public protocol HTTPHealthChecking: Sendable {
    func check(connection: OpenCodeRemoteConnection) async -> HTTPHealthCheckResult
}

public struct URLSessionHTTPHealthChecker: HTTPHealthChecking {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func check(connection: OpenCodeRemoteConnection) async -> HTTPHealthCheckResult {
        let healthURL = connection.localURL.appendingPathComponent("global/health")
        var request = URLRequest(url: healthURL)
        request.timeoutInterval = 2.0

        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return HTTPHealthCheckResult(state: .unhealthy, detail: "Non-HTTP response")
            }

            let state: HTTPHealthState = (200..<400).contains(httpResponse.statusCode) ? .healthy : .unhealthy
            return HTTPHealthCheckResult(state: state, statusCode: httpResponse.statusCode)
        } catch {
            return HTTPHealthCheckResult(state: .unreachable, detail: error.localizedDescription)
        }
    }
}
