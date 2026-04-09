import Testing
@testable import OpenCodeRemoteManagerCore

struct OpenCodeRemoteDefaultsTests {
    @Test
    func fixedConnectionsMatchExpectedDefaults() {
        #expect(OpenCodeRemoteDefaults.connections.map(\.id) == [.go, .java])

        let go = OpenCodeRemoteDefaults.connection(for: .go)
        #expect(go.sshAlias == "rubyxguo")
        #expect(go.localURL.absoluteString == "http://127.0.0.1:14096")
        #expect(go.localPort == 14_096)

        let java = OpenCodeRemoteDefaults.connection(for: .java)
        #expect(java.sshAlias == "nullguo")
        #expect(java.localURL.absoluteString == "http://127.0.0.1:24096")
        #expect(java.localPort == 24_096)
    }
}
