//
//  ExtendedData.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import Accelerate

/// ExtendedData - could be empty
public protocol ExtendedData {
    func hasData() -> Bool
    func addSection(code: ExtendedDataSegmentCode, value: UInt8)
    func addSection(code: ExtendedDataSegmentCode, value: UInt16)
    @available(iOS 14.0, *)
    func addSection(code: ExtendedDataSegmentCode, value: Float16)
    func addSection(code: ExtendedDataSegmentCode, value: Float32)
    func addSection(code: ExtendedDataSegmentCode, value: String)
    /// Catch-all for all other or future types
    func addSection(code: ExtendedDataSegmentCode, value: Data)
    
    func payload() -> PayloadData?
}

public typealias ExtendedDataSegmentCode = UInt8

/// CURRENT complete list, across all version, with CURRENT names
public enum ExtendedDataSegmentCodes : UInt8 {
    case TextPremises = 0x10
    case TextLocation = 0x11
    case TextArea = 0x12
    case LocationUrl = 0x13
}

/// V1 codes, with names and codes at the time
public enum ExtendedDataSegmentCodesV1 : UInt8 {
    case TextPremises = 0x10
    case TextLocation = 0x11
    case TextArea = 0x12
    case LocationUrl = 0x13
}

public class ConcreteExtendedDataSectionV1 {
    public var code: UInt8
    public var length: UInt8
    public var data: Data
    
    public init(code: UInt8, length: UInt8, data: Data) {
        self.code = code
        self.length = length
        self.data = data
    }
}

/// Beacon payload data supplier.
public class ConcreteExtendedDataV1 : ExtendedData {
    var payloadData : PayloadData
    
    public init() {
        payloadData = Data() // empty
    }
    
    public init(_ unparsedData: PayloadData) {
        self.payloadData = unparsedData
    }
    
    public func payload() -> PayloadData? {
        return payloadData
    }
    
    public func hasData() -> Bool {
        return 0 != payloadData.count
    }
    
    public func addSection(code: ExtendedDataSegmentCode, value: UInt8) {
        payloadData.append(code.bigEndian)
        payloadData.append(UInt8(0x01).bigEndian)
        payloadData.append(value.bigEndian)
    }
    
    public func addSection(code: ExtendedDataSegmentCode, value: UInt16) {
        payloadData.append(code.bigEndian)
        payloadData.append(UInt8(0x02).bigEndian)
        payloadData.append(UInt8(value >> 8).bigEndian)
        payloadData.append(UInt8(value & 0x00FF).bigEndian)
    }
    
    @available(iOS 14.0, *)
    public func addSection(code: ExtendedDataSegmentCode, value: Float16) {
        payloadData.append(code.bigEndian)
        payloadData.append(UInt8(0x02).bigEndian)
        
        var input: [Float16] = [value]
        var output: [UInt8] = [0,0]

        input.withUnsafeMutableBytes { inputBytes in
            output.withUnsafeMutableBytes { outputBytes in
                var sourceBuffer = vImage_Buffer(data: inputBytes.baseAddress, height: 1, width: 1, rowBytes: MemoryLayout<Float16>.size)
                var destinationBuffer = vImage_Buffer(data: outputBytes.baseAddress, height: 1, width: 1, rowBytes: MemoryLayout<UInt16>.size)
                vImageConvert_Planar16FtoPlanar8(&sourceBuffer, &destinationBuffer, 0)
            }
        }
        
        payloadData.append(output[0].bigEndian)
        payloadData.append(output[1].bigEndian)
    }
    
    public func addSection(code: ExtendedDataSegmentCode, value: Float32) {
        payloadData.append(code.bigEndian)
        payloadData.append(UInt8(0x04).bigEndian)
        
        var input: [Float] = [value]
        var output: [UInt8] = [0,0,0,0]

        input.withUnsafeMutableBytes { inputBytes in
            output.withUnsafeMutableBytes { outputBytes in
                var sourceBuffer = vImage_Buffer(data: inputBytes.baseAddress, height: 1, width: 1, rowBytes: MemoryLayout<Float>.size)
                var destinationBuffer = vImage_Buffer(data: outputBytes.baseAddress, height: 1, width: 1, rowBytes: MemoryLayout<UInt32>.size)
                vImageConvert_PlanarFtoPlanar8(&sourceBuffer, &destinationBuffer, Float.greatestFiniteMagnitude, Float.leastNonzeroMagnitude, 0)
            }
        }
        payloadData.append(output[0].bigEndian)
        payloadData.append(output[1].bigEndian)
        payloadData.append(output[2].bigEndian)
        payloadData.append(output[3].bigEndian)
    }
    
    public func addSection(code: ExtendedDataSegmentCode, value: String) {
        payloadData.append(code.bigEndian)
        payloadData.append(UInt8(value.count).bigEndian)
        payloadData.append(value.data(using: .utf8)!)
    }
    
    public func addSection(code: ExtendedDataSegmentCode, value: Data) {
        payloadData.append(code.bigEndian)
        payloadData.append(UInt8(value.count).bigEndian)
        payloadData.append(value)
    }
    
    // MARK:- V1 only methods
    
    public func getSections() -> [ConcreteExtendedDataSectionV1] {
        var sections : [ConcreteExtendedDataSectionV1] = []
        var pos = 0
        // read code
        while pos < payloadData.count {
            if payloadData.count - 2 <= pos { // at least 3 in length
                pos = payloadData.count
                continue
            }
            // read code
            let code = payloadData.uint8(pos)!
            pos = pos + 1
            // read length
            var length = payloadData[pos]
            pos = pos + 1
            // sanity check length
            if pos + Int(length) > payloadData.count {
                length = UInt8(payloadData.count - pos)
            }
            // extract data
            let data = payloadData.subdata(in: pos..<(pos+Int(length)))
            
            sections.append(ConcreteExtendedDataSectionV1(code: code, length: length, data: data))
            
            // repeat
        }
        return sections
    }
}
