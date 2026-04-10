import Foundation

public struct OpenCodeRemoteConnectionID: Hashable, Sendable, RawRepresentable, Codable, ExpressibleByStringLiteral {
    public let rawValue: String

    public static let go = OpenCodeRemoteConnectionID(rawValue: "go")
    public static let java = OpenCodeRemoteConnectionID(rawValue: "java")

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: StringLiteralType) {
        self.init(rawValue: value)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var storageIdentifier: String {
        let hasOnlyPortableCharacters = rawValue.range(of: #"^[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil
        if hasOnlyPortableCharacters, rawValue.contains("..") == false {
            return "raw-\(rawValue)"
        }

        let hex = rawValue.utf8.map { String(format: "%02x", $0) }.joined()
        return "hex-\(hex)"
    }
}
