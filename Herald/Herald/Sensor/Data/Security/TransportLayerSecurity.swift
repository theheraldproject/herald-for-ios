//
//  TransportLayerSecurity.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Transport layer security (TLS) based on one-time secret agreed via key exchange
public protocol TransportLayerSecurity {

    func readPublicKey() -> KeyExchangePublicKey
    
    func writeEncryptedData(peerPublicKey: KeyExchangePublicKey, data: Data) -> Data?
    
    func receiveEncryptedData(_ data: Data) -> Data?
}

public typealias TransportLayerSecuritySessionID = UInt32

public class TransportLayerSecuritySession {
    let id: TransportLayerSecuritySessionID
    let publicKey: KeyExchangePublicKey
    let privateKey: KeyExchangePrivateKey
    var peerId: TransportLayerSecuritySessionID?
    var sharedKey: KeyExchangeSharedKey?
    
    init(id: TransportLayerSecuritySessionID, publicKey: KeyExchangePublicKey, privateKey: KeyExchangePrivateKey) {
        self.id = id
        self.publicKey = publicKey
        self.privateKey = privateKey
    }
}

public class ConcreteTransportLayerSecurity: TransportLayerSecurity {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Data.Security.ConcreteTransportLayerSecurity")
    /// Limitation : Public key is < 256 bytes
    private let encodingForPublicKeyCount: DataLengthEncodingOption = .UINT8
    /// Limitation : Encrypted data is < 65536 bytes
    private let encodingForEncryptedDataCount: DataLengthEncodingOption = .UINT16
    private let keyExchange: KeyExchange
    private let integrity: Integrity = SHA256()
    private let encryption: Encryption = AES128()
    private var sessions: [TransportLayerSecuritySessionID:TransportLayerSecuritySession] = [:]
    private let sessionQueue = DispatchQueue(label: "Sensor.Data.Security.ConcreteTransportLayerSecurity.SessionQueue")

    init(keyExchangeParameters: DiffieHellmanParameters = .modpGroup14) {
        self.keyExchange = DiffieHellmanMerkle(keyExchangeParameters)
    }
    
    private func createSession() -> TransportLayerSecuritySession {
        let (privateKey, publicKey) = keyExchange.keyPair()
        let id = integrity.hash(publicKey).uint32(0)!
        let session = TransportLayerSecuritySession(id: id, publicKey: publicKey, privateKey: privateKey)
        sessions[session.id] = session
        return session
    }
    
    public func readPublicKey() -> KeyExchangePublicKey {
        return createSession().publicKey
    }
        
    public func writeEncryptedData(peerPublicKey: KeyExchangePublicKey, data: Data) -> Data? {
        // Session ID at peer is hash of public key
        let peerId = integrity.hash(peerPublicKey).uint32(0)!
        // Generate own public/private key pair for the session
        let (privateKey, publicKey) = keyExchange.keyPair()
        // Derive shared key from peer public key and own private key
        guard let sharedKey = keyExchange.sharedKey(own: privateKey, peer: peerPublicKey) else {
            logger.fault("writeEncryptedData failed, cannot derive shared key (privateKeyCount=\(privateKey.count),peerPublicKeyCount=\(peerPublicKey.count))")
            return nil
        }
        // Encrypt data using shared key
        guard let encryptedData = encryption.encrypt(data: data, with: EncryptionKey(sharedKey)) else {
            logger.fault("writeEncryptedData failed, cannot encrypt data with shared key (dataCount=\(data.count),sharedKeyCount=\(sharedKey.count))")
            return nil
        }
        // Build message = id + ownPublicKey + encryptedData
        var message = Data()
        message.append(peerId)
        guard message.append(publicKey, encodingForPublicKeyCount) else {
            logger.fault("writeEncryptedData failed, public key is too long (publicKeyCount=\(publicKey.count))")
            return nil
        }
        guard message.append(encryptedData, encodingForEncryptedDataCount) else {
            logger.fault("writeEncryptedData failed, encrypted data is too long (encryptedDataCount=\(encryptedData.count))")
            return nil
        }
        return message
    }
    
    public func receiveEncryptedData(_ data: Data) -> Data? {
        guard let id = data.uint32(0) else {
            logger.fault("receiveEncryptedData failed, cannot read session ID (dataCount=\(data.count))")
            return nil
        }
        guard let session = sessions[TransportLayerSecuritySessionID(id)] else {
            logger.fault("receiveEncryptedData failed, unknown session ID (id=\(id))")
            return nil
        }
        guard let (peerPublicKey, _, peerPublicKeyEnd) = data.data(4, encodingForPublicKeyCount) else {
            logger.fault("receiveEncryptedData failed, cannot read received public key (id=\(id),dataCount=\(data.count))")
            return nil
        }
        guard let (encryptedData, _, _) = data.data(peerPublicKeyEnd, encodingForEncryptedDataCount) else {
            logger.fault("receiveEncryptedData failed, cannot read received encrypted data (id=\(id),dataCount=\(data.count))")
            return nil
        }
        // Derive shared key from received public key and own private key
        guard let sharedKey = keyExchange.sharedKey(own: session.privateKey, peer: peerPublicKey) else {
            logger.fault("receiveEncryptedData failed, cannot derive shared key (privateKeyCount=\(session.privateKey.count),peerPublicKeyCount=\(peerPublicKey.count))")
            return nil
        }
        // Decrypt data using shared key
        guard let decryptedData = encryption.decrypt(data: encryptedData, with: EncryptionKey(sharedKey)) else {
            logger.fault("receiveEncryptedData failed, cannot decrypt data with shared key (encryptedDataCount=\(encryptedData.count),sharedKeyCount=\(sharedKey.count))")
            return nil
        }
        return decryptedData
    }
}
