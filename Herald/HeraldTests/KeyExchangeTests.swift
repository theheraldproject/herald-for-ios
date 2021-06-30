//
//  KeyExchangeTests.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class KeyExchangeTests: XCTestCase {
    
    public func testKeyPair() {
        let keyExchange = DiffieHellmanMerkle(DiffieHellmanParameters.random128)
        let (privateKey, publicKey) = keyExchange.keyPair()
        // Note: Private/Public key data always starts with 08000000 here because the first 4 bytes is the key length
        print("privateKey=\(privateKey.hexEncodedString),length=\(privateKey.count)")
        print("publicKey=\(publicKey.hexEncodedString),length=\(publicKey.count)")
        // Count = UInt32 (4 bytes) + 128-bit key (16 bytes) = 20 bytes
        XCTAssertEqual(privateKey.count, 20)
        XCTAssertEqual(publicKey.count, 20)
    }

    public func testKeyExchange() {
        let keyExchange = DiffieHellmanMerkle(DiffieHellmanParameters.random128)

        let (alicePrivateKey, alicePublicKey) = keyExchange.keyPair()
        print("alice private key bytes: \(alicePrivateKey.count)")
        print("alice private key = \(alicePrivateKey.hexEncodedString)")
        print("alice public key bytes: \(alicePublicKey.count)")
        print("alice public key = \(alicePublicKey.hexEncodedString)")

        let (bobPrivateKey, bobPublicKey) = keyExchange.keyPair()
        print("bob private key bytes: \(bobPrivateKey.count)")
        print("bob private key = \(bobPrivateKey.hexEncodedString)")
        print("bob public key bytes: \(bobPublicKey.count)")
        print("bob public key = \(bobPublicKey.hexEncodedString)")

        let aliceSharedKey = keyExchange.sharedKey(own: alicePrivateKey, peer: bobPublicKey)!
        print("alice shared key bytes: \(aliceSharedKey.count)")
        print("alice shared key = \(aliceSharedKey.hexEncodedString)")
        let bobSharedKey = keyExchange.sharedKey(own: bobPrivateKey, peer: alicePublicKey)!
        print("bob shared key bytes: \(bobSharedKey.count)")
        print("bob shared key = \(bobSharedKey.hexEncodedString)")

        XCTAssertEqual(aliceSharedKey, bobSharedKey)
    }
    
    public func testCrossPlatform() throws {
        let keyExchange = DiffieHellmanMerkle(DiffieHellmanParameters.random128)
        let alicePrivateKey = KeyExchangePrivateKey(hexEncodedString: "08000000D467F3ABF521BABDF238F07602BC6F28")!
        let alicePublicKey = KeyExchangePublicKey(hexEncodedString: "080000003BD578EC0E412261EE10F80E0C055896")!
        let bobPrivateKey = KeyExchangePrivateKey(hexEncodedString: "0800000055981B228A3030AFCB2E6CF5B0A7822F")!
        let bobPublicKey = KeyExchangePublicKey(hexEncodedString: "08000000D644A2045C53D6CCF6B5180756C85E16")!
        let aliceSharedKey = keyExchange.sharedKey(own: alicePrivateKey, peer: bobPublicKey)!
        let bobSharedKey = keyExchange.sharedKey(own: bobPrivateKey, peer: alicePublicKey)!
        XCTAssertEqual(aliceSharedKey, bobSharedKey)
        var csv = "key,value\n"
        csv.append("alicePrivate,\(alicePrivateKey.hexEncodedString)\n")
        csv.append("alicePublic,\(alicePublicKey.hexEncodedString)\n")
        csv.append("bobPrivate,\(bobPrivateKey.hexEncodedString)\n")
        csv.append("bobPublic,\(bobPublicKey.hexEncodedString)\n")
        csv.append("aliceShared,\(aliceSharedKey.hexEncodedString)\n")
        csv.append("bobShared,\(bobSharedKey.hexEncodedString)\n")
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "keyExchange.csv"
        add(attachment)
    }
}
