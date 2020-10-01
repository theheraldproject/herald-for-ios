//
//  SonarPayloadDataSupplierTests.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import XCTest
@testable import Herald

class SonarPayloadDataSupplierTests: XCTestCase {
    
    func testSupplier() {
        for i in 0...100 {
            let expected = Int32(i)
            let supplier = MockSonarPayloadDataSupplier(identifier: expected)
            let timestamp = PayloadTimestamp()
            let payloadData = supplier.payload(timestamp)
            let dataIdentifier = MockSonarPayloadDataIdentifier()
            let source = dataIdentifier.identify(timestamp, payloadData)
            XCTAssertNotNil(source)
            XCTAssertEqual(source?.count, 4)
            let actual = dataIdentifier.identifier(source!)
            XCTAssertEqual(expected, actual)
        }
    }
}
