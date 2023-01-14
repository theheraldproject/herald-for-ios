//
//  DataExtensionTests.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class DataExtensionTests: XCTestCase {
    
    func testInt8() throws {
        // Zero, Min, Max
        var dataRange = Data()
        dataRange.append(Int8(0))
        dataRange.append(Int8(Int8.min))
        dataRange.append(Int8(Int8.max))
        XCTAssertEqual(Int8(0), dataRange.int8(0))
        XCTAssertEqual(Int8(Int8.min), dataRange.int8(1))
        XCTAssertEqual(Int8(Int8.max), dataRange.int8(2))
        // Values in range
        var csv = "value,data\n"
        for i in Int8.min...Int8.max {
            let value = Int8(i)
            var data = Data()
            data.append(value)
            XCTAssertEqual(value, data.int8(0))
            csv.append("\(i),\(data.base64EncodedString())\n")
        }
        // Generate CSV for comparison with Android
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "int8.csv"
        add(attachment)
    }

    func testUInt8() throws {
        // Zero, Max
        var dataRange = Data()
        dataRange.append(UInt8(0))
        dataRange.append(UInt8(UInt8.min))
        dataRange.append(UInt8(UInt8.max))
        XCTAssertEqual(UInt8(0), dataRange.uint8(0))
        XCTAssertEqual(UInt8(UInt8.min), dataRange.uint8(1))
        XCTAssertEqual(UInt8(UInt8.max), dataRange.uint8(2))
        // Values in range
        var csv = "value,data\n"
        for i in UInt8.min...UInt8.max {
            let value = UInt8(i)
            var data = Data()
            data.append(value)
            XCTAssertEqual(value, data.uint8(0))
            csv.append("\(i),\(data.base64EncodedString())\n")
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "uint8.csv"
        add(attachment)
    }

    func testInt16() throws {
        // Zero, Min, Max
        var dataRange = Data()
        dataRange.append(Int16(0))
        dataRange.append(Int16(Int16.min))
        dataRange.append(Int16(Int16.max))
        XCTAssertEqual(Int16(0), dataRange.int16(0))
        XCTAssertEqual(Int16(Int16.min), dataRange.int16(2))
        XCTAssertEqual(Int16(Int16.max), dataRange.int16(4))
        // Values in range
        var csv = "value,data\n"
        for i in Int16.min...Int16.max {
            let value = Int16(i)
            var data = Data()
            data.append(value)
            XCTAssertEqual(value, data.int16(0))
            csv.append("\(i),\(data.base64EncodedString())\n")
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "int16.csv"
        add(attachment)
    }

    func testUInt16() throws {
        // Zero, Min, Max
        var dataRange = Data()
        dataRange.append(UInt16(0))
        dataRange.append(UInt16(UInt16.min))
        dataRange.append(UInt16(UInt16.max))
        XCTAssertEqual(UInt16(0), dataRange.uint16(0))
        XCTAssertEqual(UInt16(UInt16.min), dataRange.uint16(2))
        XCTAssertEqual(UInt16(UInt16.max), dataRange.uint16(4))
        // Values in range
        var csv = "value,data\n"
        for i in UInt16.min...UInt16.max {
            let value = UInt16(i)
            var data = Data()
            data.append(value)
            XCTAssertEqual(value, data.uint16(0))
            csv.append("\(i),\(data.base64EncodedString())\n")
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "uint16.csv"
        add(attachment)
    }

    func testInt32() throws {
        // Zero, Min, Max
        var dataRange = Data()
        dataRange.append(Int32(0))
        dataRange.append(Int32(Int32.min))
        dataRange.append(Int32(Int32.max))
        XCTAssertEqual(Int32(0), dataRange.int32(0))
        XCTAssertEqual(Int32(Int32.min), dataRange.int32(4))
        XCTAssertEqual(Int32(Int32.max), dataRange.int32(8))
        // Values in range
        var csv = "value,data\n"
        var i = 1
        while i <= (Int32.max / 7) {
            var dataPositive = Data()
            dataPositive.append(Int32(i))
            XCTAssertEqual(Int32(i), dataPositive.int32(0))
            csv.append("\(i),\(dataPositive.base64EncodedString())\n")
            var dataNegative = Data()
            dataNegative.append(Int32(-i))
            XCTAssertEqual(Int32(-i), dataNegative.int32(0))
            csv.append("\(-i),\(dataNegative.base64EncodedString())\n")
            i *= 7
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "int32.csv"
        add(attachment)
    }

    func testUInt32() throws {
        // Zero, Min, Max
        var dataRange = Data()
        dataRange.append(UInt32(0))
        dataRange.append(UInt32(UInt32.min))
        dataRange.append(UInt32(UInt32.max))
        XCTAssertEqual(UInt32(0), dataRange.uint32(0))
        XCTAssertEqual(UInt32(UInt32.min), dataRange.uint32(4))
        XCTAssertEqual(UInt32(UInt32.max), dataRange.uint32(8))
        // Values in range
        var csv = "value,data\n"
        var i = 1
        while i <= (UInt32.max / 7) {
            var data = Data()
            data.append(UInt32(i))
            XCTAssertEqual(UInt32(i), data.uint32(0))
            csv.append("\(i),\(data.base64EncodedString())\n")
            i *= 7
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "uint32.csv"
        add(attachment)
    }

    func testInt64() throws {
        // Zero, Min, Max
        var dataRange = Data()
        dataRange.append(Int64(0))
        dataRange.append(Int64(Int64.min))
        dataRange.append(Int64(Int64.max))
        XCTAssertEqual(Int64(0), dataRange.int64(0))
        XCTAssertEqual(Int64(Int64.min), dataRange.int64(8))
        XCTAssertEqual(Int64(Int64.max), dataRange.int64(16))
        // Values in range
        var csv = "value,data\n"
        var i = 1
        while i <= (Int64.max / 7) {
            var dataPositive = Data()
            dataPositive.append(Int64(i))
            XCTAssertEqual(Int64(i), dataPositive.int64(0))
            csv.append("\(i),\(dataPositive.base64EncodedString())\n")
            var dataNegative = Data()
            dataNegative.append(Int64(-i))
            XCTAssertEqual(Int64(-i), dataNegative.int64(0))
            csv.append("\(-i),\(dataNegative.base64EncodedString())\n")
            i *= 7
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "int64.csv"
        add(attachment)
    }

    func testUInt64() throws {
        // Zero, Min, Max
        var dataRange = Data()
        dataRange.append(UInt64(0))
        dataRange.append(UInt64(UInt64.min))
        dataRange.append(UInt64(UInt64.max))
        XCTAssertEqual(UInt64(0), dataRange.uint64(0))
        XCTAssertEqual(UInt64(UInt64.min), dataRange.uint64(8))
        XCTAssertEqual(UInt64(UInt64.max), dataRange.uint64(16))
        // Values in range
        var csv = "value,data\n"
        var i = 1
        while i <= (UInt64.max / 7) {
            var data = Data()
            data.append(UInt64(i))
            XCTAssertEqual(UInt64(i), data.uint64(0))
            csv.append("\(i),\(data.base64EncodedString())\n")
            i *= 7
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "uint64.csv"
        add(attachment)
    }
    
    func testData() throws {
        // Zero
        var dataRange = Data()
        XCTAssertTrue(dataRange.append(Data(), .UINT8))
        XCTAssertEqual(Data(), dataRange.data(0)?.value)
        XCTAssertEqual(1, dataRange.data(0)?.start)
        XCTAssertEqual(1, dataRange.data(0)?.end)
        
        // Encoding options
        var dataEncoding = Data()
        XCTAssertTrue(dataEncoding.append(Data(repeating: 1, count: 1), .UINT8))
        XCTAssertTrue(dataEncoding.append(Data(repeating: 2, count: 2), .UINT16))
        XCTAssertTrue(dataEncoding.append(Data(repeating: 3, count: 3), .UINT32))
        XCTAssertTrue(dataEncoding.append(Data(repeating: 4, count: 4), .UINT64))
        XCTAssertEqual(Data(repeating: 1, count: 1), dataEncoding.data(0, .UINT8)?.value)
        XCTAssertEqual(1, dataEncoding.data(0, .UINT8)?.start)
        XCTAssertEqual(2, dataEncoding.data(0, .UINT8)?.end)
        XCTAssertEqual(Data(repeating: 2, count: 2), dataEncoding.data(2, .UINT16)?.value)
        XCTAssertEqual(4, dataEncoding.data(2, .UINT16)?.start)
        XCTAssertEqual(6, dataEncoding.data(2, .UINT16)?.end)
        XCTAssertEqual(Data(repeating: 3, count: 3), dataEncoding.data(6, .UINT32)?.value)
        XCTAssertEqual(10, dataEncoding.data(6, .UINT32)?.start)
        XCTAssertEqual(13, dataEncoding.data(6, .UINT32)?.end)
        XCTAssertEqual(Data(repeating: 4, count: 4), dataEncoding.data(13, .UINT64)?.value)
        XCTAssertEqual(21, dataEncoding.data(13, .UINT64)?.start)
        XCTAssertEqual(25, dataEncoding.data(13, .UINT64)?.end)
        
        // Values in range
        var csv = "value,data\n"
        for i in 0...5 {
            var data = Data()
            XCTAssertTrue(data.append(Data(repeating: UInt8(i), count: i), .UINT8))
            XCTAssertEqual(Data(repeating: UInt8(i), count: i), data.data(0)?.value)
            csv.append("\(i),\(data.base64EncodedString())\n")
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "data.csv"
        add(attachment)
    }
    
    func testString() throws {
        // Zero
        var dataRange = Data()
        _ = dataRange.append("")
        XCTAssertEqual("", dataRange.string(0)?.value)
        XCTAssertEqual(1, dataRange.string(0)?.start)
        XCTAssertEqual(1, dataRange.string(0)?.end)
        
        // Encoding options
        var dataEncoding = Data()
        _ = dataEncoding.append("a", .UINT8)
        _ = dataEncoding.append("bb", .UINT16)
        _ = dataEncoding.append("ccc", .UINT32)
        _ = dataEncoding.append("dddd", .UINT64)
        XCTAssertEqual("a", dataEncoding.string(0, .UINT8)?.value)
        XCTAssertEqual(1, dataEncoding.string(0, .UINT8)?.start)
        XCTAssertEqual(2, dataEncoding.string(0, .UINT8)?.end)
        XCTAssertEqual("bb", dataEncoding.string(2, .UINT16)?.value)
        XCTAssertEqual(4, dataEncoding.string(2, .UINT16)?.start)
        XCTAssertEqual(6, dataEncoding.string(2, .UINT16)?.end)
        XCTAssertEqual("ccc", dataEncoding.string(6, .UINT32)?.value)
        XCTAssertEqual(10, dataEncoding.string(6, .UINT32)?.start)
        XCTAssertEqual(13, dataEncoding.string(6, .UINT32)?.end)
        XCTAssertEqual("dddd", dataEncoding.string(13, .UINT64)?.value)
        XCTAssertEqual(21, dataEncoding.string(13, .UINT64)?.start)
        XCTAssertEqual(25, dataEncoding.string(13, .UINT64)?.end)
        
        // Values in range
        var csv = "value,data\n"
        for s in ["","a","bb","ccc","dddd","eeeee"] {
            var data = Data()
            _ = data.append(s)
            XCTAssertEqual(s, data.string(0)?.value)
            csv.append("\(s),\(data.base64EncodedString())\n")
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "string.csv"
        add(attachment)
    }
    
    func testHexTransform() throws {
        for i in 0...1000 {
            let expected = Data(repeating: UInt8(i % 255), count: i)
            let hex = expected.hexEncodedString
            let actual = Data(hexEncodedString: hex)
            XCTAssertEqual(expected, actual)
        }
    }
}
