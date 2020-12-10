//
//  BeaconPayloadDataSupplierTests.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class BeaconPayloadDataSupplierTests: XCTestCase {

    func testBasicFormat() throws {
        let beacon = ConcreteBeaconPayloadDataSupplierV1(countryCode: 0xDDEE, stateCode: 0x11FF, code: 0xAABBCCDD)
        let expected : Data = Data.init(base64Encoded: "MN3uEf+qu8zd")! // Hex = "30EEDD11FFAABBCCDD"
        let beaconPayload : Data? = beacon.payload(device: nil)
        XCTAssertNotNil(beaconPayload)
        XCTAssertEqual(expected.base64EncodedString(), beaconPayload!.base64EncodedString())
    }
}