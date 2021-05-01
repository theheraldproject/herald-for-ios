//
//  PseudoDeviceAddressTests.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//



import XCTest
@testable import Herald

class PseudoDeviceAddressTests: XCTestCase {

    func testCrossPlatform() throws {
        // Zero, Min, Max
        // Values in range
        var csv = "value,data\n"
        var i:Int64 = 1
        while i <= (Int64.max / 7) {
            let dataPositive = BLEPseudoDeviceAddress(value: i)
            XCTAssertEqual(dataPositive.address, BLEPseudoDeviceAddress(data: dataPositive.data)?.address)
            csv.append("\(i),\(dataPositive.data.base64EncodedString())\n")
            let dataNegative = BLEPseudoDeviceAddress(value: -i)
            XCTAssertEqual(dataNegative.address, BLEPseudoDeviceAddress(data: dataNegative.data)?.address)
            csv.append("\(-i),\(dataNegative.data.base64EncodedString())\n")
            i *= 7
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "pseudoDeviceAddress.csv"
        add(attachment)
    }
}
