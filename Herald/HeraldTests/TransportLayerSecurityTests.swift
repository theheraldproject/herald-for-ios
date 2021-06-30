//
//  TransportLayerSecurityTests.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class TransportLayerSecurityTests: XCTestCase {

    public func testTransportLayerSecuritySession() throws {
        let keyExchangeParameters: DiffieHellmanParameters = .random128
        let alice: TransportLayerSecurity = ConcreteTransportLayerSecurity(keyExchangeParameters: keyExchangeParameters)
        let bob: TransportLayerSecurity = ConcreteTransportLayerSecurity(keyExchangeParameters: keyExchangeParameters)
        for i in 0...10 {
            print("testTransportLayerSecurity (count=\(i))")
            let data = Data(repeating: UInt8(i), count: i)
            // Alice reads public key from Bob
            let bobPublicKey = bob.readPublicKey()
            print("testTransportLayerSecurity (count=\(i),bobPublicKeyCount=\(bobPublicKey.count))")
            // Alice encrypted data for Bob
            let aliceEncryptedData = alice.writeEncryptedData(peerPublicKey: bobPublicKey, data: data)!
            print("testTransportLayerSecurity (count=\(i),aliceEncryptedDataCount=\(aliceEncryptedData.count))")
            // Bob decrypts data from Alice
            let (bobSessionId, bobDecryptedData) = bob.receiveEncryptedData(aliceEncryptedData)!
            XCTAssertEqual(data, bobDecryptedData)
            // Alice reads encrypted data from Bob
            let bobEncryptedData = bob.readEncryptedData(sessionId: bobSessionId, data: data)!
            print("testTransportLayerSecurity (count=\(i),bobEncryptedDataCount=\(bobEncryptedData.count))")
            // Alice decrypts data from Bob
            let (_, aliceDecryptedData) = alice.receiveEncryptedData(bobEncryptedData)!
            XCTAssertEqual(data, aliceDecryptedData)
        }
    }

    public func testCrossPlatform() throws {
        let keyExchangeParameters: DiffieHellmanParameters = .random128
        let pseudoRandomFunction: PseudoRandomFunction = TestRandomFunction(0)
        let alice: TransportLayerSecurity = ConcreteTransportLayerSecurity(keyExchangeParameters: keyExchangeParameters, random: pseudoRandomFunction)
        let bob: TransportLayerSecurity = ConcreteTransportLayerSecurity(keyExchangeParameters: keyExchangeParameters, random: pseudoRandomFunction)
        var csv = "key,bobPublicKey,aliceEncryptedData,bobSessionId,bobDecryptedData,bobEncryptedData,aliceSessionId,aliceDecryptedData\n"
        for i in 0...10 {
            let data = Data(repeating: UInt8(i), count: i)
            // Alice reads public key from Bob
            let bobPublicKey = bob.readPublicKey()
            // Alice encrypted data for Bob
            let aliceEncryptedData = alice.writeEncryptedData(peerPublicKey: bobPublicKey, data: data)!
            // Bob decrypts data from Alice
            let (bobSessionId, bobDecryptedData) = bob.receiveEncryptedData(aliceEncryptedData)!
            XCTAssertEqual(data, bobDecryptedData)
            // Alice reads encrypted data from Bob
            let bobEncryptedData = bob.readEncryptedData(sessionId: bobSessionId, data: data)!
            // Alice decrypts data from Bob
            let (aliceSessionId, aliceDecryptedData) = alice.receiveEncryptedData(bobEncryptedData)!
            XCTAssertEqual(data, aliceDecryptedData)
            csv.append("\(i),\(bobPublicKey.hexEncodedString),\(aliceEncryptedData.hexEncodedString),\(bobSessionId),\(bobDecryptedData.hexEncodedString),\(bobEncryptedData.hexEncodedString),\(aliceSessionId),\(aliceDecryptedData.hexEncodedString)\n")
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "transportLayerSecurity.csv"
        add(attachment)
    }
}
