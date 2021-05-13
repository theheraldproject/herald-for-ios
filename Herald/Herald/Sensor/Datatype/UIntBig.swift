//
//  UIntBig.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Mutable unsigned integer of unlimited size (for 32-bit architectures)
public class UIntBig: Equatable, Hashable, Comparable {
    // Unsigned value (LSB ... MSB)
    public var magnitude: [UInt16]
    // Common values
    private static let magnitudeZero: [UInt16] = []
    private static let zero: UInt16 = UInt16(0)
    private static let one: UInt16 = UInt16(1)

    /// From raw data
    public init(_ magnitude: [UInt16]) {
        self.magnitude = magnitude
    }

    /// Zero
    public convenience init() {
        self.init(UIntBig.magnitudeZero)
    }

    /// Deep copy of given value
    private convenience init(_ value: UIntBig) {
        // Primitive arrays are copied in Swift, so no need for explicit copy operation
        // to clone value.magnitude. Use value.magnitude.map({ $0 }) to explicitly copy
        self.init(value.magnitude)
    }

    /// Positive Int64 value as unlimited value
    public convenience init(_ uint64: UInt64) {
        let value: [UInt16] = [
            UInt16(truncatingIfNeeded: uint64 & 0xFFFF),         // LSB
            UInt16(truncatingIfNeeded: (uint64 >> 16) & 0xFFFF),
            UInt16(truncatingIfNeeded: (uint64 >> 32) & 0xFFFF),
            UInt16(truncatingIfNeeded: (uint64 >> 48) & 0xFFFF)  // MSB
        ]
        self.init(UIntBig.trimZeroMSBs(value))
    }


    /// Hex encoded string with format MSB...LSB
    public convenience init?(_ hexEncodedString: String) {
        // Pad MSB with zeros until length % 4 == 0
        var hex: String = ""
        while (hex.count + hexEncodedString.count) % 4 != 0 {
            hex.append("0")
        }
        hex.append(hexEncodedString)
        // Convert to bytes MSB...LSB
        guard let data = Data(hexEncodedString: hex) else {
            return nil
        }
        // Convert to short LSB...MSB
        self.init(Array<UInt16>(repeating: 0, count: data.count / 2))
        var i = 0, j = data.count - 1
        while i < magnitude.count {
            magnitude[i] = UInt16(data[j])
            j -= 1
            magnitude[i] |= (UInt16(data[j]) << 8)
            j -= 1
            i += 1
        }
    }
    
    public convenience init?(bitLength: Int, random: RandomSource = RandomSource()) {
        self.init(Array<UInt16>(repeating: 0, count: (bitLength + 15) / 16))
        var bytes: [UInt8] = Array<UInt8>(repeating: 0, count: 2)
        var value: UInt16
        var remaining = bitLength
        var i = 0
        while i < magnitude.count, remaining > 0 {
            if !random.nextBytes(&bytes) {
                return nil
            }
            value = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
            if remaining < 16 {
                value = value >> (16 - remaining)
            } else {
                remaining -= 16
            }
            magnitude[i] = value
            i += 1
        }
    }
    
    public var hexEncodedString: String { get {
        var data = Data()
        var i = magnitude.count - 1
        while i >= 0 {
            data.append(UInt8(truncatingIfNeeded: magnitude[i] >> 8))
            data.append(UInt8(truncatingIfNeeded: magnitude[i]))
            i -= 1
        }
        // Strip leading zeros
        var offset = 0
        while offset < data.count, data[offset] == 0 {
            offset += 1
        }
        let unpadded: Data = (offset == 0 ? data : data.dropFirst(offset))
        return unpadded.hexEncodedString
    }}

    /// Get unsigned long value.
    public func uint64() -> UInt64 {
        var value: UInt64 = 0
        if magnitude.count >= 1 {
            value = UInt64(magnitude[0])
        }
        if magnitude.count >= 2 {
            value |= (UInt64(magnitude[1]) << 16)
        }
        if (magnitude.count >= 3) {
            value |= (UInt64(magnitude[2]) << 32)
        }
        if (magnitude.count >= 4) {
            value |= (UInt64(magnitude[3]) << 48)
        }
        return value
    }

    /// Test if value is zero
    var isZero: Bool { get {
        return magnitude.count == 0
    }}

    /// Test if value is one
    var isOne: Bool { get {
        if magnitude.count != 1 {
            return false
        }
        return magnitude[0] == UIntBig.one
    }}

    /// Test if value is odd
    var isOdd: Bool { get {
        if magnitude.count == 0 {
            return false
        }
        return (magnitude[0] & 0x01) == UIntBig.one
    }}

    /// Modular exponentiation r = (a ^ b) % c where
    /// - a: self
    /// - b: exponent
    /// - c: modulus
    /// Performance test shows software implementation is acceptably slower than native hardware
    /// - Test samples = 399,626,333
    /// - Native 64-bit hardware = 416ns/call
    /// - Software 32-bit implementation = 3613ns/call
    ///
    /// return r, the result
    public func modPow(_ exponent: UIntBig, _ modulus: UIntBig) -> UIntBig {
        if modulus.isZero {
            return UIntBig()
        }
        if exponent.isOne {
            let base = UIntBig(self)
            base.mod(modulus)
            return base
        }
        let result = UIntBig(1)
        let base = UIntBig(self)
        base.mod(modulus)
        let exp = UIntBig(exponent)
        while !exp.isZero {
            if exp.isOdd {
                result.times(base)
                result.mod(modulus)
            }
            exp.rightShiftByOne()
            base.times(base)
            base.mod(modulus)
        }
        return result
    }

    /// Replace self with self % modulus
    func mod(_ modulus: UIntBig) {
        let a = modulus.magnitude
        var b = magnitude
        UIntBig.mod(a, &b)
        magnitude = UIntBig.trimZeroMSBs(b)
    }

    /// Reduce b until b < a at offset by repeatedly deducting a from b at offset
    /// Assumes b.length >= a.length + offset
    static func reduce(_ a: [UInt16], _ b: inout [UInt16], _ offset: Int) {
        let valueA = UInt32(a[a.count - 1]) + (a.count > 1 ? 1 : 0)
        var valueB, carry, quotient: UInt32
        var multiplier: UInt16
        carry = (a.count + offset < b.count ? UInt32(b[a.count + offset]) : 0)
        valueB = UInt32(b[a.count + offset - 1])
        while carry != 0 || valueB >= valueA || (offset == 0 && compare(a, b) <= 0) {
            if carry > UInt16.max {
                quotient = UInt32(UInt16.max)
            } else if carry > 0 {
                valueB = carry << 16 | valueB
                quotient = valueB / valueA
            } else {
                quotient = valueB / valueA
                if quotient == 0 {
                    quotient = 1
                }
            }
            multiplier = (quotient > UInt16.max ? UInt16.max : UInt16(truncatingIfNeeded: quotient))
            let _ = subtract(a, multiplier, &b, offset)
            carry = (a.count + offset < b.count ? UInt32(b[a.count + offset]) : 0)
            valueB = UInt32(b[a.count + offset - 1])
        }
    }
    
    /// Modular function : b % a
    static func mod(_ a: [UInt16], _ b: inout [UInt16]) {
        var offset = b.count - a.count
        while offset >= 0 {
            reduce(a, &b, offset)
            offset -= 1
        }
    }

    // MARK: - Comparable
    
    /// Compare a and b, ignoring leading zeros
    public static func < (lhs: UIntBig, rhs: UIntBig) -> Bool {
        let value = compare(lhs.magnitude, rhs.magnitude)
        return (value == -1)
    }
    
    /// Compare self with given value
    /// returns -1 for self < value, 0 for self == value, 1 for self > value
    func compare(_ value: UIntBig) -> Int {
        return UIntBig.compare(magnitude, value.magnitude)
    }
    
    /// Compare a and b, ignoring leading zeros
    /// returns -1 for a < b, 0 for a == b, 1 for a > b
    static func compare(_ a: [UInt16], _ b: [UInt16]) -> Int {
        var i = a.count - 1, j = b.count - 1
        while i >= 0 && a[i] == 0 {
            i -= 1
        }
        while j >= 0 && b[j] == 0 {
            j -= 1
        }
        if i < j {
            return -1
        }
        if i > j {
            return 1
        }
        // i == j, switching to i as index
        while (i >= 0) {
            if (a[i] < b[i]) {
                return -1
            }
            if (a[i] > b[i]) {
                return 1
            }
            i -= 1
        }
        return 0
    }

    /// Subtraction function : b - a * multiplier (at offset of b)
    /// Note, multiplier range is [0,32767]
    static func subtract(_ a: [UInt16], _ multiplier: UInt16, _ b: inout [UInt16], _ offset: Int) -> UInt32 {
        let times = UInt32(multiplier)
        var carry = UInt32(0)
        for i in 0...a.count-1 {
            var valueA = UInt32(a[i])
            let valueB = Int32(b[i+offset])
            valueA *= times
            let valueAL = valueA & 0xFFFF
            let valueAH = valueA >> 16
            var result = valueB - Int32(valueAL + carry)
            carry = valueAH
            while result < 0 {
                result += 0x00010000
                carry += 1
            }
            b[i+offset] = UInt16(truncatingIfNeeded: result)
        }
        var i = a.count + offset
        while i < b.count, carry > 0 {
            let valueB = Int32(b[i])
            var result = valueB - Int32(carry)
            carry = 0
            while result < 0 {
                result += 0x00010000
                carry += 1
            }
            b[i] = UInt16(truncatingIfNeeded: result)
            i += 1
        }
        return carry
    }

    /// Replace self with self - value * multiplier (at offset of self)
    /// Note, multiplier range is [0,32767]
    func minus(_ value: UIntBig, _ multiplier: UInt16, _ offset: Int) -> UInt32 {
        let a = value.magnitude
        var b = magnitude
        let underflow = UIntBig.subtract(a, multiplier, &b, offset)
        magnitude = UIntBig.trimZeroMSBs(b)
        return underflow
    }

    /// Replace self with self * multiplier
    func times(_ multiplier: UIntBig) {
        if isZero || multiplier.isZero {
            magnitude = UIntBig.magnitudeZero
            return
        }
        if multiplier.isOne {
            return
        }
        let a = magnitude
        let b = multiplier.magnitude
        var product: [UInt16] = Array<UInt16>(repeating: 0, count: a.count + b.count)
        var valueA, valueB, carry, carried: UInt32
        for i in 0...a.count-1 {
            valueA = UInt32(a[i])
            carry = 0
            for j in 0...b.count-1 {
                valueB = UInt32(b[j])
                carried = UInt32(product[i+j])
                carry += valueA * valueB + carried
                product[i+j] = UInt16(truncatingIfNeeded: carry)
                carry >>= 16
            }
            product[i+b.count] = UInt16(truncatingIfNeeded: carry)
        }
        magnitude = UIntBig.trimZeroMSBs(product)
    }

    /// Right shift all bits by one bit and insert leading 0 bit
    func rightShiftByOne() {
        if isZero {
            return
        }
        if isOne {
            magnitude = UIntBig.magnitudeZero
            return
        }
        var i = 0
        while i < magnitude.count - 1 {
            magnitude[i] >>= 1
            magnitude[i] |= magnitude[i+1] << 15
            i += 1
        }
        magnitude[magnitude.count - 1] >>= 1
        magnitude = UIntBig.trimZeroMSBs(magnitude)
    }
    
    /// Remove leading zeros from array
    static func trimZeroMSBs(_ magnitude: [UInt16]) -> [UInt16] {
        var i = magnitude.count - 1;
        while i > 0, magnitude[i] == UIntBig.zero {
            i -= 1
        }
        if i == 0, magnitude[0] == UIntBig.zero {
            return UIntBig.magnitudeZero
        }
        if i == magnitude.count - 1 {
            return magnitude
        }
        let trimmed = magnitude.dropLast(magnitude.count - i - 1)
        return Array<UInt16>(trimmed)
    }

    /// Count of bits based on highest set bit
    public func bitLength() -> Int {
        if (magnitude.count == 0) {
            return 0
        }
        var length: Int = (magnitude.count > 1 ? (magnitude.count - 1) * 16 : 0)
        var msb: Int32 = Int32(magnitude[magnitude.count - 1]) & 0xFFFF
        while (msb != 0) {
            msb = msb >> 1
            length += 1
        }
        return length
    }
    
    // MARK: - Equatable
    
    public static func == (lhs: UIntBig, rhs: UIntBig) -> Bool {
        return lhs.magnitude == rhs.magnitude
    }
    
    // MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(magnitude)
    }
}
