import CryptoKit
import Foundation

public struct EncryptedSecretPayload: Codable, Equatable, Sendable {
    public let nonceBase64: String
    public let ciphertextBase64: String
    public let tagBase64: String

    public init(nonceBase64: String, ciphertextBase64: String, tagBase64: String) {
        self.nonceBase64 = nonceBase64
        self.ciphertextBase64 = ciphertextBase64
        self.tagBase64 = tagBase64
    }
}

public enum CryptoEnvelopeError: Error {
    case invalidBase64Payload
}

public struct CryptoEnvelopeService {
    public init() {}

    public func deriveSymmetricKey(
        localPrivateKey: Curve25519.KeyAgreement.PrivateKey,
        remotePublicKey: Curve25519.KeyAgreement.PublicKey
    ) throws -> SymmetricKey {
        let sharedSecret = try localPrivateKey.sharedSecretFromKeyAgreement(with: remotePublicKey)
        return sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: Data("itime.sync".utf8),
            outputByteCount: 32
        )
    }

    public func encrypt(payload: Data, using key: SymmetricKey) throws -> EncryptedSecretPayload {
        let nonce = AES.GCM.Nonce()
        let sealedBox = try AES.GCM.seal(payload, using: key, nonce: nonce)
        return EncryptedSecretPayload(
            nonceBase64: Data(nonce).base64EncodedString(),
            ciphertextBase64: sealedBox.ciphertext.base64EncodedString(),
            tagBase64: sealedBox.tag.base64EncodedString()
        )
    }

    public func decrypt(envelope: EncryptedSecretPayload, using key: SymmetricKey) throws -> Data {
        guard
            let nonceData = Data(base64Encoded: envelope.nonceBase64),
            let ciphertext = Data(base64Encoded: envelope.ciphertextBase64),
            let tag = Data(base64Encoded: envelope.tagBase64)
        else {
            throw CryptoEnvelopeError.invalidBase64Payload
        }

        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealedBox, using: key)
    }
}
