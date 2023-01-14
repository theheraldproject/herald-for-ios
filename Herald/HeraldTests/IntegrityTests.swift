//
//  IntegrityTests.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class IntegrityTests: XCTestCase {

    public func testHash() {
        let integrity: Integrity = SHA256()
        for i in 0...99 {
            let hashA = integrity.hash(Data(repeating: UInt8(i), count: i))
            let hashB = integrity.hash(Data(repeating: UInt8(i), count: i))
            XCTAssertEqual(hashA, hashB)
        }
    }

    public func testCrossPlatform() {
        let integrity: Integrity = SHA256()
        var csv = "key,value\n"
        for i in 0...99 {
            let hashA = integrity.hash(Data(repeating: UInt8(i), count: i))
            let hashB = integrity.hash(Data(repeating: UInt8(i), count: i))
            XCTAssertEqual(hashA, hashB)
            csv.append("\(i),\(hashA.hexEncodedString)\n")
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "integrity.csv"
        add(attachment)
    }
}
