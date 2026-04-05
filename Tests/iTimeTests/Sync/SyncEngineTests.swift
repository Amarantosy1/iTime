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
