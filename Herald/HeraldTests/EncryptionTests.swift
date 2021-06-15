//
//  EncryptionTests.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class EncryptionTests: XCTestCase {

    public func testEncryption() {
        let encryption: Encryption = AES128()
        let encryptionKey: EncryptionKey = EncryptionKey(hexEncodedString: "0800000017A6DD51E0869A46AB0DEB8D6399B942")!
        for i in 0...99 {
            let data = Data(repeating: UInt8(i), count: i)
            let encrypted = encryption.encrypt(data: data, with: encryptionKey)!
            let decrypted = encryption.decrypt(data: encrypted, with: encryptionKey)!
            XCTAssertEqual(data, decrypted)
        }
    }

    public func testCrossPlatform() {
        let encryption: Encryption = AES128(TestRandomFunction(0))
        let encryptionKey: EncryptionKey = EncryptionKey(hexEncodedString: "0800000017A6DD51E0869A46AB0DEB8D6399B942")!
        var csv = "key,encrypted,decrypted\n"
        for i in 0...99 {
            let data = Data(repeating: UInt8(i), count: i)
            let encrypted = encryption.encrypt(data: data, with: encryptionKey)!
            let decrypted = encryption.decrypt(data: encrypted, with: encryptionKey)!
            XCTAssertEqual(data, decrypted)
            csv.append("\(i),\(encrypted.hexEncodedString),\(decrypted.hexEncodedString)\n")
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "encryption.csv"
        add(attachment)
    }
}
