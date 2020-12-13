//
//  SwiftExtensions.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
extension Date {

    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }

}
extension Data {
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
    
    /// MARK:- Conversion from intrinsic types to Data
    
    mutating func append(_ value: UInt16) {
        append(UInt8(value & 0xff).bigEndian) // LSB
        append(UInt8(value >> 8).bigEndian) // MSB
    }
    
    mutating func append(_ value: UInt32) {
        append(UInt8(value & 0xff).bigEndian) // LSB
        append(UInt8((value >> 8) & 0xff).bigEndian)
        append(UInt8((value >> 16) & 0xff).bigEndian)
        append(UInt8((value >> 24) & 0xff).bigEndian) // MSB
    }
    
    mutating func append(_ value: UInt64) {
        append(UInt8(value & 0xff).bigEndian) // LSB
        append(UInt8((value >> 8) & 0xff).bigEndian)
        append(UInt8((value >> 16) & 0xff).bigEndian)
        append(UInt8((value >> 24) & 0xff).bigEndian)
        append(UInt8((value >> 32) & 0xff).bigEndian)
        append(UInt8((value >> 40) & 0xff).bigEndian)
        append(UInt8((value >> 48) & 0xff).bigEndian)
        append(UInt8((value >> 56) & 0xff).bigEndian) // MSB
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
}

