import Foundation
import Testing
@testable import iTime

@Test func syncMessageRoundTripsManifestAndPatch() throws {
    let now = Date(timeIntervalSince1970: 1_710_000_000)
    let manifest = SyncManifest(
        archiveVersion: 3,
        preferencesVersion: 7,
        apiKeyFingerprintByServiceID: ["openai": "sha256:abc"],
        generatedAt: now
    )
    let message = SyncMessage.manifest(manifest)
    let data = try JSONEncoder().encode(message)
    let decoded = try JSONDecoder().decode(SyncMessage.self, from: data)
    #expect(decoded == message)
}

@Test func syncEngineUsesLWWForRecordConflicts() {
    let old = SyncRecord(
        recordID: "summary-1",
        value: "old",
        updatedAt: .init(timeIntervalSince1970: 10),
        deletedAt: nil,
        version: 1
    )
    let new = SyncRecord(
        recordID: "summary-1",
        value: "new",
        updatedAt: .init(timeIntervalSince1970: 20),
        deletedAt: nil,
        version: 2
    )
    let merged = SyncEngine.merge(local: [old], remote: [new])
    #expect(merged.count == 1)
    #expect(merged.first?.value == "new")
}

@Test func syncEnginePrefersNewerTombstoneOverOlderValue() {
    let local = SyncRecord<String>(
        recordID: "session-1",
        value: "alive",
        updatedAt: .init(timeIntervalSince1970: 30),
        deletedAt: nil,
        version: 3
    )
    let remote = SyncRecord<String>(
        recordID: "session-1",
        value: nil,
        updatedAt: .init(timeIntervalSince1970: 40),
        deletedAt: .init(timeIntervalSince1970: 40),
        version: 4
    )
    let merged = SyncEngine.merge(local: [local], remote: [remote])
    #expect(merged.first?.isDeleted == true)
}
