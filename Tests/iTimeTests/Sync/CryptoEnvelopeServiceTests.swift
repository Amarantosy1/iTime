import CryptoKit
import Foundation
import Testing
@testable import iTime

@Test func cryptoEnvelopeEncryptsAndDecryptsAPIKeyPayload() throws {
    let service = CryptoEnvelopeService()
    let plaintext = Data("sk-test-123".utf8)
    let localPrivate = Curve25519.KeyAgreement.PrivateKey()
    let remotePrivate = Curve25519.KeyAgreement.PrivateKey()
    let sharedSecret = try service.deriveSymmetricKey(
        localPrivateKey: localPrivate,
        remotePublicKey: remotePrivate.publicKey
    )
    let sharedSecretRemote = try service.deriveSymmetricKey(
        localPrivateKey: remotePrivate,
        remotePublicKey: localPrivate.publicKey
    )
    let envelope = try service.encrypt(payload: plaintext, using: sharedSecret)
    let decrypted = try service.decrypt(envelope: envelope, using: sharedSecretRemote)
    #expect(decrypted == plaintext)
}
