import Foundation
import Testing
@testable import OpenCodeRemoteManagerCore

struct PersistentDesiredStateStoreTests {
    @Test
    func separateStoreInstancesMergeDesiredStateThroughSharedFile() async throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("desired-state.json")

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let firstStore = PersistentDesiredStateStore(fileURL: fileURL)
        let secondStore = PersistentDesiredStateStore(fileURL: fileURL)
        let thirdStore = PersistentDesiredStateStore(fileURL: fileURL)

        await firstStore.setDesiredState(.running, for: .go)
        await secondStore.setDesiredState(.running, for: .java)

        let states = await thirdStore.allDesiredStates()
        #expect(states[.go] == .running)
        #expect(states[.java] == .running)
    }
}
