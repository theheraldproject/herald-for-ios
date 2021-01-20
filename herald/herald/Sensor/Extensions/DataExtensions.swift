//
//  DataExtensions.swift
//
//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation
import Accelerate

public extension Data {
    
    public struct HexEncodingOptions: OptionSet {
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        public let rawValue: Int
        public static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    public func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
    
    /// MARK:- Conversion from intrinsic types to Data
    
    mutating func append(_ value: UInt8) {
        append(Data([value.bigEndian]))
    }
    
    mutating func append(_ value: UInt16) {
        append(UInt8(value & 0xFF).bigEndian) // LSB
        append(UInt8((value >> 8) & 0xFF).bigEndian) // MSB
    }
    
    mutating func append(_ value: UInt32) {
        append(UInt8(value & 0xFF).bigEndian) // LSB
        append(UInt8((value >> 8) & 0xFF).bigEndian)
        append(UInt8((value >> 16) & 0xFF).bigEndian)
        append(UInt8((value >> 24) & 0xFF).bigEndian) // MSB
    }
    
    mutating func append(_ value: UInt64) {
        append(UInt8(value & 0xFF).bigEndian) // LSB
        append(UInt8((value >> 8) & 0xFF).bigEndian)
        append(UInt8((value >> 16) & 0xFF).bigEndian)
        append(UInt8((value >> 24) & 0xFF).bigEndian)
        append(UInt8((value >> 32) & 0xFF).bigEndian)
        append(UInt8((value >> 40) & 0xFF).bigEndian)
        append(UInt8((value >> 48) & 0xFF).bigEndian)
        append(UInt8((value >> 56) & 0xFF).bigEndian) // MSB
    }
    
    mutating func append(_ value: Int8) {
        var int8 = value
        append(Data(bytes: &int8, count: MemoryLayout<Int8>.size))
    }

    mutating func append(_ value: Int16) {
        var int16 = value
        append(Data(bytes: &int16, count: MemoryLayout<Int16>.size))
    }

    mutating func append(_ value: Int32) {
        var int32 = value
        append(Data(bytes: &int32, count: MemoryLayout<Int32>.size))
    }

    mutating func append(_ value: Int64) {
        var int64 = value
        append(Data(bytes: &int64, count: MemoryLayout<Int64>.size))
    }
    
    @available(iOS 14.0, *)
    mutating func append(_ value: Float16) {
        var input: [Float16] = [value]
        var output: [UInt8] = [0,0]
        var sourceBuffer = vImage_Buffer(data: &input, height: 1, width: 1, rowBytes: MemoryLayout<Float16>.size)
        var destinationBuffer = vImage_Buffer(data: &output, height: 1, width: 1, rowBytes: MemoryLayout<UInt16>.size)
        vImageConvert_Planar16FtoPlanar8(&sourceBuffer, &destinationBuffer, 0)
        append(output[0])
        append(output[1])
    }
    
    mutating func append(_ value: Float32) {
        var input: [Float] = [value]
        var output: [UInt8] = [0,0,0,0]
        var sourceBuffer = vImage_Buffer(data: &input, height: 1, width: 1, rowBytes: MemoryLayout<Float>.size)
        var destinationBuffer = vImage_Buffer(data: &output, height: 1, width: 1, rowBytes: MemoryLayout<UInt32>.size)
        vImageConvert_PlanarFtoPlanar8(&sourceBuffer, &destinationBuffer, Float.greatestFiniteMagnitude, Float.leastNonzeroMagnitude, 0)
        append(output[0])
        append(output[1])
        append(output[2])
        append(output[3])
    }

    /// Encode string as data, inserting length as prefix using UInt8,...,64. Returns true if successful, false otherwise.
    mutating func append(_ value: String, _ encoding: StringLengthEncodingOption = .UINT8) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }
        switch (encoding) {
        case .UINT8:
            guard data.count <= UInt8.max else {
                return false
            }
            append(UInt8(data.count))
            break
        case .UINT16:
            guard data.count <= UInt16.max else {
                return false
            }
            append(UInt16(data.count))
            break
        case .UINT32:
            guard data.count <= UInt32.max else {
                return false
            }
            append(UInt32(data.count))
            break
        case .UINT64:
            guard data.count <= UInt64.max else {
                return false
            }
            append(UInt64(data.count))
            break
        }
        append(data)
        return true
    }

    /// MARK:- Conversion from data to intrinsic types
    
    /// Get Int8 from byte array (little-endian).
    func int8(_ index: Int) -> Int8? {
        guard let value = uint8(index) else {
            return nil
        }
        return Int8(bitPattern: value)
    }

    /// Get UInt8 from byte array (little-endian).
    func uint8(_ index: Int) -> UInt8? {
        let bytes = [UInt8](self)
        guard index < bytes.count else {
            return nil
        }
        return bytes[index]
    }
    
    /// Get Int16 from byte array (little-endian).
    func int16(_ index: Int) -> Int16? {
        guard let value = uint16(index) else {
            return nil
        }
        return Int16(bitPattern: value)
    }
    
    /// Get UInt16 from byte array (little-endian).
    func uint16(_ index: Int) -> UInt16? {
        let bytes = [UInt8](self)
        guard index < (bytes.count - 1) else {
            return nil
        }
        return UInt16(bytes[index]) |
            UInt16(bytes[index + 1]) << 8
    }
    
    /// Get Int32 from byte array (little-endian).
    func int32(_ index: Int) -> Int32? {
        guard let value = uint32(index) else {
            return nil
        }
        return Int32(bitPattern: value)
    }
    
    /// Get UInt32 from byte array (little-endian).
    func uint32(_ index: Int) -> UInt32? {
        let bytes = [UInt8](self)
        guard index < (bytes.count - 3) else {
            return nil
        }
        return UInt32(bytes[index]) |
            UInt32(bytes[index + 1]) << 8 |
            UInt32(bytes[index + 2]) << 16 |
            UInt32(bytes[index + 3]) << 24
    }

    /// Get Int64 from byte array (little-endian).
    func int64(_ index: Int) -> Int64? {
        guard let value = uint64(index) else {
            return nil
        }
        return Int64(bitPattern: value)
    }
    
    /// Get UInt64 from byte array (little-endian).
    func uint64(_ index: Int) -> UInt64? {
        let bytes = [UInt8](self)
        guard index < (bytes.count - 7) else {
            return nil
        }
        return UInt64(bytes[index]) |
            UInt64(bytes[index + 1]) << 8 |
            UInt64(bytes[index + 2]) << 16 |
            UInt64(bytes[index + 3]) << 24 |
            UInt64(bytes[index + 4]) << 32 |
            UInt64(bytes[index + 5]) << 40 |
            UInt64(bytes[index + 6]) << 48 |
            UInt64(bytes[index + 7]) << 56
    }
    
    func string(_ index: Int, _ encoding: StringLengthEncodingOption = .UINT8) -> (value:String, start:Int, end:Int)? {
        var start = index
        var end = index
        switch (encoding) {
        case .UINT8:
            guard let count = uint8(index) else {
                return nil
            }
            start = index + 1
            end = start + Int(count)
            break
        case .UINT16:
            guard let count = uint16(index) else {
                return nil
            }
            start = index + 2
            end = start + Int(count)
            break
        case .UINT32:
            guard let count = uint32(index) else {
                return nil
            }
            start = index + 4
            end = start + Int(count)
            break
        case .UINT64:
            guard let count = uint64(index) else {
                return nil
            }
            start = index + 8
            end = start + Int(count)
            break
        }
        guard start != index, self.count >= start, self.count >= end else {
            return nil
        }
        guard let string = String(bytes: subdata(in: start..<end), encoding: .utf8) else {
            return nil
        }
        return (string, start, end)
    }
}

/// Encoding option for string length data as prefix
public enum StringLengthEncodingOption {
    case UINT8, UINT16, UINT32, UINT64
}
