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

        let customA = OpenCodeRemoteConnectionID(rawValue: "alpha")
        let customB = OpenCodeRemoteConnectionID(rawValue: "beta")

        await firstStore.setDesiredState(.running, for: customA)
        await secondStore.setDesiredState(.running, for: customB)

        let states = await thirdStore.allDesiredStates()
        #expect(states[customA] == .running)
        #expect(states[customB] == .running)
    }

    @Test
    func loadsLegacyDesiredStateArrayFormat() async throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("desired-state.json")

        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let legacyJSON = #"{"states":["go","running","java","stopped"]}"#
        try legacyJSON.data(using: .utf8)?.write(to: fileURL)

        let store = PersistentDesiredStateStore(fileURL: fileURL)
        let states = await store.allDesiredStates()

        #expect(states[.go] == .running)
        #expect(states[.java] == .stopped)
    }
}
