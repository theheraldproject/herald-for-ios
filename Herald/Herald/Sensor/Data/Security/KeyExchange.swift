//
//  KeyExchange.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Cryptographically secure key exchange
public protocol KeyExchange {

    /// Generate a random key pair for key exchange with peer
    func keyPair() -> (KeyExchangePrivateKey, KeyExchangePublicKey)
    
    /// Generate shared key by combining own private key and peer public key
    func sharedKey(own: KeyExchangePrivateKey, peer: KeyExchangePublicKey) -> KeyExchangeSharedKey?
}

public typealias KeyExchangePrivateKey = Data
public typealias KeyExchangePublicKey = Data
public typealias KeyExchangeSharedKey = Data


/// Diffie-Hellman-Merkle key exchange using NCSC Foundation Profile MODP group 14 (2048-bit) by default
public class DiffieHellmanMerkle: KeyExchange {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Data.Security.DiffieHellmanMerkle")
    private let random: PseudoRandomFunction

    /// Parameters for Diffie-Hellman key agreement
    /// NCSC Foundation Profile for TLS requires key exchange using
    /// DH Group 14 (2048-bit MODP Group) - which is RFC3526 MODP Group 14
    private let parameters: DiffieHellmanParameters
    
    public init(_ parameters: DiffieHellmanParameters = .modpGroup14, random: PseudoRandomFunction = SecureRandomFunction()) {
        self.parameters = parameters
        self.random = random
    }
    
    // MARK: - KeyExchange
    
    public func keyPair() -> (KeyExchangePrivateKey, KeyExchangePublicKey) {
        let privateKey = UIntBig(bitLength: parameters.p.bitLength() - 2, random: random)
        let privateKeyData = KeyExchangePrivateKey(privateKey.data)
        // publicKey = (base ^ exponent) % modulus = (g ^ privateKey) % p
        let base = parameters.g
        let exponent = privateKey
        let modulus = parameters.p
        let publicKey = base.modPow(exponent, modulus)
        let publicKeyData = KeyExchangePublicKey(publicKey.data)
        return (privateKeyData, publicKeyData)
    }
    
    public func sharedKey(own: KeyExchangePrivateKey, peer: KeyExchangePublicKey) -> KeyExchangeSharedKey? {
        // sharedKey = (base ^ exponent) % modulus = (peerPublicKey ^ ownPrivateKey) % p
        guard let base = UIntBig(peer),
              let exponent = UIntBig(own) else {
            return nil
        }
        let modulus = parameters.p
        let sharedKey = base.modPow(exponent, modulus)
        let sharedKeyData = KeyExchangeSharedKey(sharedKey.data)
        return sharedKeyData
    }
        
    // MARK: - Optional in-situ test functions
    
    /// Run performance test on phone hardware
    /// Note : Use release build for performance tests as it is over 40x faster than debug build
    public func performanceTest(_ samples: UInt64 = 100) {
        var timeKeyPair = UInt64(0)
        var timeSharedKey = UInt64(0)
        var timeRoundtrip = UInt64(0)
        for _ in 0...samples {
            // Roundtrip key generation and exchange
            let t0 = DispatchTime.now().uptimeNanoseconds
            let (alicePrivateKey, alicePublicKey) = keyPair()
            let t1 = DispatchTime.now().uptimeNanoseconds
            let (bobPrivateKey, bobPublicKey) = keyPair()
            let t2 = DispatchTime.now().uptimeNanoseconds
            let aliceSharedKey = sharedKey(own: alicePrivateKey, peer: bobPublicKey)
            let t3 = DispatchTime.now().uptimeNanoseconds
            let bobSharedKey = sharedKey(own: bobPrivateKey, peer: alicePublicKey)
            let t4 = DispatchTime.now().uptimeNanoseconds
            guard aliceSharedKey == bobSharedKey else {
                logger.fault("performanceTest, shared key mismatch")
                continue
            }
            // Update time counters
            timeKeyPair += (t1-t0)
            timeKeyPair += (t2-t1)
            timeSharedKey += (t3-t2)
            timeSharedKey += (t4-t3)
            timeRoundtrip += (t4-t0)
        }
        logger.debug("performanceTest (samples=\(samples),roundTrip=\(timeRoundtrip / samples)ns,keyPair=\(timeKeyPair / (samples * 2))ns,sharedKey=\(timeSharedKey / (samples * 2))ns)")
    }

}

/// Common Diffie-Hellman parameters
public class DiffieHellmanParameters {
    public var p: UIntBig
    public var g: UIntBig
    
    public init?(p pHexEncodedString: String, g gHexEncodedString: String) {
        guard let pValue = UIntBig(pHexEncodedString.replacingOccurrences(of: " ", with: "")),
              let gValue = UIntBig(gHexEncodedString.replacingOccurrences(of: " ", with: "")) else {
            return nil
        }
        self.p = pValue
        self.g = gValue
    }
    
    /// OpenSSL generated safe prime : 128-bits
    public static let random128 = DiffieHellmanParameters(p:
                                        "C8132E2C84B73BE9D9AD805E228E5F87", g: "2")!
    
    /// OpenSSL generated safe prime : 256-bits
    public static let random256 = DiffieHellmanParameters(p:
                                        "D6E86C6CA81EFFA45AF8921B1D2C1E5F" +
                                        "1B644A7DBCDC528D3B31E46EE367F877", g: "2")!
    
    /// OpenSSL generated safe prime : 512-bits
    public static let random512 = DiffieHellmanParameters(p:
                                        "F8D1E3F7C41D8E20525045E9CFFD2886" +
                                        "C10E795649C57A59E30D0A764B14AA69" +
                                        "B9CC2651419C71384D33BBD47705A6FB" +
                                        "60F599C548C442E55EC7F457AA355C17", g: "2")!
    
    /// RFC 2409 MODP Group 1 : 768-bits : First Oakley Group : Generator = 2
    public static let modpGroup1 = DiffieHellmanParameters(p:
                                        "FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1" +
                                        "29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD" +
                                        "EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245" +
                                        "E485B576 625E7EC6 F44C42E9 A63A3620 FFFFFFFF FFFFFFFF",
                                    g:  "2")!
    /// RFC 2409 MODP Group 2 : 1024-bits : Second Oakley Group : Generator = 2
    public static let modpGroup2 = DiffieHellmanParameters(p:
                                        "FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1" +
                                        "29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD" +
                                        "EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245" +
                                        "E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED" +
                                        "EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE65381" +
                                        "FFFFFFFF FFFFFFFF",
                                    g:  "2")!
    /// RFC3526 MODP Group 5 : 1536-bits : Generator = 2
    public static let modpGroup5 = DiffieHellmanParameters(p:
                                        "FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1" +
                                        "29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD" +
                                        "EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245" +
                                        "E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED" +
                                        "EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE45B3D" +
                                        "C2007CB8 A163BF05 98DA4836 1C55D39A 69163FA8 FD24CF5F" +
                                        "83655D23 DCA3AD96 1C62F356 208552BB 9ED52907 7096966D" +
                                        "670C354E 4ABC9804 F1746C08 CA237327 FFFFFFFF FFFFFFFF",
                                    g:  "2")!
    /// RFC3526 MODP Group 14 : 2048-bits : Generator = 2
    /// Satisfies NCSC Foundation Profile for TLS standard
    public static let modpGroup14 = DiffieHellmanParameters(p:
                                        "FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1" +
                                        "29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD" +
                                        "EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245" +
                                        "E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED" +
                                        "EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE45B3D" +
                                        "C2007CB8 A163BF05 98DA4836 1C55D39A 69163FA8 FD24CF5F" +
                                        "83655D23 DCA3AD96 1C62F356 208552BB 9ED52907 7096966D" +
                                        "670C354E 4ABC9804 F1746C08 CA18217C 32905E46 2E36CE3B" +
                                        "E39E772C 180E8603 9B2783A2 EC07A28F B5C55DF0 6F4C52C9" +
                                        "DE2BCBF6 95581718 3995497C EA956AE5 15D22618 98FA0510" +
                                        "15728E5A 8AACAA68 FFFFFFFF FFFFFFFF",
                                     g: "2")!
}
