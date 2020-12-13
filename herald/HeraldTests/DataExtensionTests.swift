//
//  DataExtensionTests.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class DataExtensionTests: XCTestCase {
    /// MARK:- Basic class functionality tests
    
    func testUInt16Only() throws {
        var data = Data()
        let value = UInt16(826)
        data.append(UInt8(value & 0x00FF).bigEndian)
        data.append(UInt8(value >> 8).bigEndian)
        XCTAssertEqual(UInt16(826),data.uint16(0))
    }
    
    func testUInt16BiDirectional() throws {
        var data = Data()
        data.append(UInt16(12345))
        XCTAssertEqual(2,data.count)
        XCTAssertEqual(12345,data.uint16(0))
    }
    
    func testUInt32BiDirectional() throws {
        var data = Data()
        data.append(UInt32(1234567))
        XCTAssertEqual(4,data.count)
        XCTAssertEqual(1234567,data.uint32(0))
    }
    
    func testUInt64BiDirectional() throws {
        var data = Data()
        data.append(UInt64(1234567890000))
        XCTAssertEqual(8,data.count)
        XCTAssertEqual(1234567890000,data.uint64(0))
    }
}
