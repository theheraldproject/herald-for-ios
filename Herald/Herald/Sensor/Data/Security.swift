//
//  Security.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Cross-platform security primitives
public class Security {
    /// Secure random source for security functions
    public static var secureRandom = RandomSource(method: .SecureRandom)
    
    // MARK: - Diffie-Hellman Key Agreement
    
    /// Generate a random private key
    public static func diffieHellmanPrivateKey(_ parameters: DiffieHellmanParameters = .modpGroup1) -> UIntBig? {
        return UIntBig(bitLength: parameters.p.bitLength() - 2, random: Security.secureRandom)
    }
    
    /// Derive a public key from the given private key
    public static func diffieHellmanPublicKey(_ privateKey: UIntBig, _ parameters: DiffieHellmanParameters = .modpGroup1) -> UIntBig {
        return parameters.g.modPow(privateKey, parameters.p)
    }

    /// Derive a shared key from own private key and peer public key
    public static func diffieHellmanSharedKey(_ privateKey: UIntBig, _ publicKey: UIntBig, _ parameters: DiffieHellmanParameters = .modpGroup1) -> UIntBig {
        return publicKey.modPow(privateKey, parameters.p)
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
