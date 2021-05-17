//
//  SecurityTests.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class SecurityTests: XCTestCase {

    public func test_diffieHellman() {

        let alicePrivateKey = Security.diffieHellmanPrivateKey()!
        print("alice private key bits: \(alicePrivateKey.bitLength())")
        print("alice private key = \(alicePrivateKey.hexEncodedString)")
        let alicePublicKey = Security.diffieHellmanPublicKey(alicePrivateKey)
        print("alice public key bits: \(alicePublicKey.bitLength())")
        print("alice public key = \(alicePublicKey.hexEncodedString)")

        let bobPrivateKey = Security.diffieHellmanPrivateKey()!
        print("bob private key bits: \(bobPrivateKey.bitLength())")
        print("bob private key = \(bobPrivateKey.hexEncodedString)")
        let bobPublicKey = Security.diffieHellmanPublicKey(bobPrivateKey)
        print("bob public key bits: \(bobPublicKey.bitLength())")
        print("bob public key = \(bobPublicKey.hexEncodedString)")

        let aliceSharedKey = Security.diffieHellmanSharedKey(alicePrivateKey, bobPublicKey)
        print("alice shared key bits: \(aliceSharedKey.bitLength())")
        print("alice shared key = \(aliceSharedKey.hexEncodedString)")
        let bobSharedKey = Security.diffieHellmanSharedKey(bobPrivateKey, alicePublicKey)
        print("bob shared key bits: \(bobSharedKey.bitLength())")
        print("bob shared key = \(bobSharedKey.hexEncodedString)")

        XCTAssertEqual(aliceSharedKey, bobSharedKey)
    }
}
