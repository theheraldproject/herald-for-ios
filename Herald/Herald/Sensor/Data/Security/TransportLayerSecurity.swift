//
//  TransportLayerSecurity.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Transport layer security (TLS) based on one-time secret agreed via key exchange
/// Expected sequence of events:
/// - Alice obtains Bob's public key (Bob calls `readPublicKey` to generate the key pair)
/// - Alice derives shared key using Bob's public key and encrypts data for Bob (Alice calls `writeEncryptedData` to establish session and encrypt data)
/// - Alice writes encrypted data to Bob (Bob calls `receiveEncryptedData` to decode the message, establish session and decrypt data)
/// - Alice optionally reads encrypted data from Bob (Bob calls `readEncryptedData` to generate encrypted data)
/// - Alice decrypts data from Bob (Alice calls `receiveEncryptedData` to decode the message and decrypt data)
public protocol TransportLayerSecurity {

    /// Alice reads public key from Bob. Bob calls this function to generate a new key pair and provides the public key
    func readPublicKey() -> KeyExchangePublicKey
    
    /// Alice uses Bob's public key to establish a shared encyption key, and uses the key to encrypt data for Bob. Alice calls this function to generate an encoded message
    /// containing the session ID (derived from Bob's public key), data encrypted using the shared key, and Alice's own public key for Bob. Alice writes this message to Bob.
    func writeEncryptedData(peerPublicKey: KeyExchangePublicKey, data: Data) -> Data?
    
    /// Bob receives encoded message from Alice. The message is decoded to obtain the session ID (derived from Bob's public key), data encrypted by Alice, and
    /// Alice's public key. Given Alice's publc key, Bob can now complete the key exchange and derive the same shared key. The key is then used to decrypt the
    /// encrypted data from Alice. The function returns the established session ID (derived from Bob's public key) and decrypted data.
    func receiveEncryptedData(_ data: Data) -> (TransportLayerSecuritySessionID, Data)?
    
    /// Alice may optionally request encrypted data from Bob, e.g. to securely read Bob's payload. Bob calls this function to generate the encrypted data using
    /// the shared key associated with a session ID (derived from Bob's public key). This function will generate an encoded message containing the session ID
    /// (derived from Alice's public key, note Alice's session ID, not Bob's), and the encrypted data. Bob's public key is omitted from this message as the session is
    /// already established. Alice reads this message from Bob, then Alice calls `receiveEncryptedData` to decode and decrypt the message using the
    /// shared key associated with the encoded session ID.
    func readEncryptedData(sessionId: TransportLayerSecuritySessionID, data: Data) -> Data?
}

/// Session identifier derived from SHA hash of public key
public typealias TransportLayerSecuritySessionID = UInt32

/// Single use session between Alice and Bob to derive shared key via key exchange and using the key to encrypt/decrypt data.
public class TransportLayerSecuritySession {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Data.Security.TransportLayerSecuritySession")
    // Security primitives
    private let keyExchange: KeyExchange
    private let integrity: Integrity
    private let encryption: Encryption
    // Own key pair and session ID derived from public key
    public let ownId: TransportLayerSecuritySessionID
    public let ownPublicKey: KeyExchangePublicKey
    private let ownPrivateKey: KeyExchangePrivateKey
    // Peer public key and peer session ID derived from peer public key
    public var peerId: TransportLayerSecuritySessionID?
    private var peerPublicKey: KeyExchangePublicKey?
    // Shared key derived from key exchange
    private var sharedKey: EncryptionKey?
    // Session expiry criteria
    private let timestamp = Date()
    private var encryptCounter: UInt8 = 0
    public var expired: Bool { get {
        return encryptCounter > 0 || TimeInterval(Date().secondsSinceUnixEpoch - timestamp.secondsSinceUnixEpoch) > (TimeInterval.minute * 5)
    }}
    
    public init(keyExchange: KeyExchange, integrity: Integrity, encryption: Encryption) {
        self.keyExchange = keyExchange
        self.integrity = integrity
        self.encryption = encryption
        (self.ownPrivateKey, self.ownPublicKey) = keyExchange.keyPair()
        self.ownId = TransportLayerSecuritySessionID(integrity.hash(self.ownPublicKey).uint32(0)!)
    }
    
    public func establishSession(with peerPublicKey: KeyExchangePublicKey) -> TransportLayerSecuritySessionID? {
        guard let sharedKey = keyExchange.sharedKey(own: ownPrivateKey, peer: peerPublicKey) else {
            logger.fault("establishSession failed, cannot derive shared key (ownPrivateKeyCount=\(ownPrivateKey.count),peerPublicKeyCount=\(peerPublicKey.count))")
            return nil
        }
        guard let peerId = integrity.hash(peerPublicKey).uint32(0) else {
            logger.fault("establishSession failed, cannot derive peer ID (peerPublicKeyCount=\(peerPublicKey.count))")
            return nil

        }
        self.peerId = TransportLayerSecuritySessionID(peerId)
        self.peerPublicKey = peerPublicKey
        self.sharedKey = EncryptionKey(sharedKey)
        return peerId
    }
    
    public func encrypt(_ data: Data) -> Data? {
        guard let encryptionKey = sharedKey else {
            logger.fault("encrypt failed, missing shared encryption key")
            return nil
        }
        // Encrypt data using shared key
        guard let encryptedData = encryption.encrypt(data: data, with: encryptionKey) else {
            logger.fault("encrypt failed, cannot encrypt data with shared encryption key (dataCount=\(data.count),encryptionKeyCount=\(encryptionKey.count))")
            return nil
        }
        // Update usage count to prevent over use of the same encryption key
        encryptCounter += 1
        return encryptedData
    }
    
    public func decrypt(_ data: Data) -> Data? {
        guard let encryptionKey = sharedKey else {
            logger.fault("decrypt failed, missing shared encryption key")
            return nil
        }
        // Decrypt data using shared key
        guard let decryptedData = encryption.decrypt(data: data, with: encryptionKey) else {
            logger.fault("decrypt failed, cannot decrypt data with shared encryption key (dataCount=\(data.count),encryptionKeyCount=\(encryptionKey.count))")
            return nil
        }
        return decryptedData
    }
}

/// Implementation of TLS based on Diffie-Hellman-Merkle key exchange and AES encryption.
public class ConcreteTransportLayerSecurity: TransportLayerSecurity {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Data.Security.ConcreteTransportLayerSecurity")
    /// Limitation : Public key is < 256 bytes
    private let encodingForPublicKeyCount: DataLengthEncodingOption = .UINT8
    /// Limitation : Encrypted data is < 65536 bytes
    private let encodingForEncryptedDataCount: DataLengthEncodingOption = .UINT16
    private let keyExchange: KeyExchange
    private let integrity: Integrity = SHA256()
    private let encryption: Encryption
    private var sessions: [TransportLayerSecuritySessionID:TransportLayerSecuritySession] = [:]

    init(keyExchangeParameters: DiffieHellmanParameters = .modpGroup14, random: PseudoRandomFunction = SecureRandomFunction()) {
        self.keyExchange = DiffieHellmanMerkle(keyExchangeParameters, random: random)
        self.encryption = AES128(random)
    }
    
    /// Alice reads public key from Bob. This function is called by Bob to create a new session for Alice and provide the public key.
    public func readPublicKey() -> KeyExchangePublicKey {
        let bobSession = TransportLayerSecuritySession(keyExchange: keyExchange, integrity: integrity, encryption: encryption)
        sessions[bobSession.ownId] = bobSession
        return bobSession.ownPublicKey
    }
        
    /// Receive encoded data from peer.
    /// This function is called by Bob to establish a new session with Alice and decrypt the encrypted data from Alice.
    /// This function is also called by Alice to decrypt the optional encrypted data from Bob for an established session.
    public func receiveEncryptedData(_ data: Data) -> (TransportLayerSecuritySessionID, Data)? {
        guard let (sessionId, encryptedData, peerPublicKey) = decode(data) else {
            logger.fault("receiveEncryptedData failed, cannot decode message")
            return nil
        }
        guard let session = sessions[sessionId] else {
            logger.fault("receiveEncryptedData failed, unknown session (sessionId=\(sessionId))")
            return nil
        }
        // Establish session if public key has been provided and session is not already established
        if let peerPublicKey = peerPublicKey {
            guard session.peerId == nil, let _ = session.establishSession(with: peerPublicKey) else {
                logger.fault("receiveEncryptedData failed, cannot establish session (peerPublicKeyCount=\(peerPublicKey.count))")
                return nil
            }
        }
        // Decrypt data using shared key
        guard let decryptedData = session.decrypt(encryptedData) else {
            logger.fault("receiveEncryptedData failed, cannot decrypt data")
            return nil
        }
        return (sessionId, decryptedData)
    }

    /// Alice receives public key from Bob. This function is called by Alice to establish a new session and pass encrypted data to Bob.
    public func writeEncryptedData(peerPublicKey: KeyExchangePublicKey, data: Data) -> Data? {
        let aliceSession = TransportLayerSecuritySession(keyExchange: keyExchange, integrity: integrity, encryption: encryption)
        sessions[aliceSession.ownId] = aliceSession
        guard let bobSessionId = aliceSession.establishSession(with: peerPublicKey) else {
            logger.fault("writeEncryptedData failed, cannot establish session (peerPublicKeyCount=\(peerPublicKey.count))")
            return nil
        }
        // Encrypt data using shared key
        guard let encryptedData = aliceSession.encrypt(data) else {
            logger.fault("writeEncryptedData failed, cannot encrypt data")
            return nil
        }
        // Build encodedData = peerId + encryptedData + ownPublicKey
        guard let encodedData = encode(id: bobSessionId, encrypted: encryptedData, key: aliceSession.ownPublicKey) else {
            logger.fault("writeEncryptedData failed, cannot encode message")
            return nil
        }
        return encodedData
    }
    
    /// Alice can optionally read encrypted data from Bob. This function is called by Bob to generate encrypted data for Alice using an established session.
    public func readEncryptedData(sessionId: TransportLayerSecuritySessionID, data: Data) -> Data? {
        guard let bobSession = sessions[sessionId] else {
            logger.fault("readEncryptedData failed, unknown session (sessionId=\(sessionId))")
            return nil
        }
        // Encrypt data using shared key
        guard let encryptedData = bobSession.encrypt(data) else {
            logger.fault("readEncryptedData failed, cannot encrypt data")
            return nil
        }
        // Build encodedData = peerId + encryptedData
        // (omitting public key as this is an established session)
        guard let aliceSessionId = bobSession.peerId,
              let encodedData = encode(id: aliceSessionId, encrypted: encryptedData) else {
            logger.fault("readEncryptedData failed, cannot encode message")
            return nil
        }
        return encodedData
    }
    
    // MARK: - Encode/decode message
    
    private func encode(id: TransportLayerSecuritySessionID, encrypted: Data, key: KeyExchangePublicKey? = nil) -> Data? {
        var data = Data()
        data.append(UInt32(id))
        guard data.append(encrypted, encodingForEncryptedDataCount) else {
            logger.fault("encode failed, encrypted data is too long (encryptedDataCount=\(encrypted.count))")
            return nil
        }
        guard let key = key else {
            return data
        }
        guard data.append(key, encodingForPublicKeyCount) else {
            logger.fault("encode failed, public key is too long (keyCount=\(key.count))")
            return nil
        }
        return data
    }
    
    private func decode(_ data: Data) -> (TransportLayerSecuritySessionID, Data, KeyExchangePublicKey?)? {
        guard let id = data.uint32(0) else {
            logger.fault("decode failed, cannot read id (dataCount=\(data.count))")
            return nil
        }
        guard let (encrypted, _, encryptedEnd) = data.data(4, encodingForEncryptedDataCount) else {
            logger.fault("decode failed, cannot read encrypted data (dataCount=\(data.count))")
            return nil
        }
        if encryptedEnd == data.count {
            return (TransportLayerSecuritySessionID(id), encrypted, nil)
        }
        guard let (key, _, _) = data.data(encryptedEnd, encodingForPublicKeyCount) else {
            logger.fault("decode failed, cannot read public key (dataCount=\(data.count),encryptedEnd=\(encryptedEnd))")
            return nil
        }
        return (TransportLayerSecuritySessionID(id), encrypted, key)
    }
}
