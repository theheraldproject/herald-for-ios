//
//  BLEAdvertParserTests.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class BLEAdvertParserTests: XCTestCase {

    // MARK: Low level individual parsing functions

    func testDataSubsetBigEndian() throws {
        let data = Data([0,1,5,6,7,8,12,13,14])
        XCTAssertEqual(5, data[2])
        XCTAssertEqual(6, data[3])
        XCTAssertEqual(7, data[4])
        XCTAssertEqual(8, data[5])
        let result = BLEAdvertParser.subDataBigEndian(data,2,4)
        XCTAssertEqual(4, result.count)
        XCTAssertEqual(5, result[0])
        XCTAssertEqual(6, result[1])
        XCTAssertEqual(7, result[2])
        XCTAssertEqual(8, result[3])
    }

    func testDataSubsetLittleEndian() throws {
        let data = Data([0,1,5,6,7,8,12,13,14])
        let result = BLEAdvertParser.subDataLittleEndian(data,2,4)
        XCTAssertEqual(4, result.count)
        XCTAssertEqual(8, result[0])
        XCTAssertEqual(7, result[1])
        XCTAssertEqual(6, result[2])
        XCTAssertEqual(5, result[3])
    }

    func testDataSubsetBigEndianOverflow() throws {
        let data = Data([0,1,5,6,7])
        let result = BLEAdvertParser.subDataBigEndian(data,2,4)
        XCTAssertEqual(0, result.count)
    }

    func testDataSubsetLittleEndianOverflow() throws {
        let data = Data([0,1,5,6,7])
        let result = BLEAdvertParser.subDataLittleEndian(data,2,4)
        XCTAssertEqual(0, result.count)
    }

    func testDataSubsetBigEndianLowIndex() throws {
        let data = Data([0,1,5,6,7])
        let result = BLEAdvertParser.subDataBigEndian(data,-1,4)
        XCTAssertEqual(0, result.count)
    }

    func testDataSubsetLittleEndianLowIndex() throws {
        let data = Data([0,1,5,6,7])
        let result = BLEAdvertParser.subDataLittleEndian(data,-1,4)
        XCTAssertEqual(0, result.count)
    }

    func testDataSubsetBigEndianHighIndex() throws {
        let data = Data([0,1,5,6,7])
        let result = BLEAdvertParser.subDataBigEndian(data,5,4)
        XCTAssertEqual(0, result.count)
    }

    func testDataSubsetLittleEndianHighIndex() throws {
        let data = Data([0,1,5,6,7])
        let result = BLEAdvertParser.subDataLittleEndian(data,5,4)
        XCTAssertEqual(0, result.count)
    }

    func testDataSubsetBigEndianLargeLength() throws {
        let data = Data([0,1,5,6,7])
        let result = BLEAdvertParser.subDataBigEndian(data,2,4)
        XCTAssertEqual(0, result.count)
    }

    func testDataSubsetLittleEndianLargeLength() throws {
        let data = Data([0,1,5,6,7])
        let result = BLEAdvertParser.subDataLittleEndian(data,2,4)
        XCTAssertEqual(0, result.count)
    }

    func testDataSubsetBigEndianEmptyData() throws {
        let data = Data()
        let result = BLEAdvertParser.subDataBigEndian(data,0,1)
        XCTAssertEqual(0, result.count)
    }

    func testDataSubsetLittleEndianEmptyData() throws {
        let data = Data()
        let result = BLEAdvertParser.subDataLittleEndian(data,0,1)
        XCTAssertEqual(0, result.count)
    }
    
    func testExtractMessages_iPhoneX_F() throws {
        let raw = Data(hexEncodedString:
            "02011A020A0C0BFF4C001006071EA3DD89E014FF4C00010000000000000000" +
            "00002000000000000000000000000000000000000000000000000000000000")!
        let segments = BLEAdvertParser.extractSegments(raw, 0)
        print(segments.map({ $0.description }))
        let manufacturerDataSegments = BLEAdvertParser.extractManufacturerData(segments: segments)
        print(manufacturerDataSegments.map({ $0.description }))
        XCTAssertEqual("1006071EA3DD89E0", manufacturerDataSegments[0].data.hexEncodedString)
        XCTAssertEqual("0100000000000000000000200000000000", manufacturerDataSegments[1].data.hexEncodedString)
    }

}
