//
//  UIntBig.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Mutable unsigned integer of unlimited size (for 32-bit architectures)
public class UIntBig: Equatable, Hashable, Comparable {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Datatype.UIntBig")
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
        var value: [UInt16] = [
            UInt16(truncatingIfNeeded: uint64 & 0xFFFF),         // LSB
            UInt16(truncatingIfNeeded: (uint64 >> 16) & 0xFFFF),
            UInt16(truncatingIfNeeded: (uint64 >> 32) & 0xFFFF),
            UInt16(truncatingIfNeeded: (uint64 >> 48) & 0xFFFF)  // MSB
        ]
        UIntBig.trimZeroMSBs(&value)
        self.init(value)
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
    
    public convenience init?(bitLength: Int, random: PseudoRandomFunction = SecureRandomFunction()) {
        self.init(Array<UInt16>(repeating: 0, count: (bitLength + 15) / 16))
        var data = Data(repeating: 0, count: magnitude.count * 2)
        guard random.nextBytes(&data) else {
            return nil
        }
        var remaining = bitLength
        var i = 0
        while i < magnitude.count, remaining > 0 {
            guard var value = data.uint16(i) else {
                return nil
            }
            if remaining < 16 {
                value = value >> (16 - remaining)
            } else {
                remaining -= 16
            }
            magnitude[i] = value
            i += 1
        }
    }
    
    public convenience init?(_ data: Data, index: Int = 0) {
        guard let uintBig = data.uintBig(index) else {
            return nil
        }
        self.init(uintBig.value.magnitude)
    }
    
    public var data: Data { get {
        var data = Data()
        data.append(self)
        return data
    }}
    
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
        withUnsafePointer(to: modulus.magnitude.map({ UInt32($0) })) { pM in
            while !exp.isZero {
                if exp.isOdd {
                    UIntBig.timesMod(result, base, pM)
                }
                exp.rightShiftByOne()
                UIntBig.timesMod(base, base, pM)
            }
        }
        return result
    }
    
    /// a = (a * b) % m
    static func timesMod(_ a: UIntBig, _ b: UIntBig, _ pM: UnsafePointer<[UInt32]>) {
        var ab: [UInt32] = Array<UInt32>(repeating: 0, count: a.magnitude.count + b.magnitude.count)
        withUnsafePointer(to: a.magnitude.map({ UInt32($0) })) { pA in
            withUnsafePointer(to: b.magnitude.map({ UInt32($0) })) { pB in
                withUnsafeMutablePointer(to: &ab) { pAB in
                    UIntBig.times(pA, pB, pAB)
                    UIntBig.mod(pM, pAB)
                }
            }
        }
        a.magnitude = ab.map({ UInt16(truncatingIfNeeded: $0) })
        UIntBig.trimZeroMSBs(&a.magnitude)
    }

    /// Replace self with self % modulus
    func mod(_ modulus: UIntBig) {
        let a = modulus.magnitude.map({ UInt32($0) })
        var b = magnitude.map({ UInt32($0) })
        withUnsafePointer(to: a) { pA in
            withUnsafeMutablePointer(to: &b) { pB in
                UIntBig.mod(pA, pB)
            }
        }
        magnitude = b.map({ UInt16(truncatingIfNeeded: $0) })
        UIntBig.trimZeroMSBs(&magnitude)
    }

    /// Reduce b until b < a at offset by repeatedly deducting a from b at offset
    /// Assumes b.length >= a.length + offset
    static func reduce(_ pA: UnsafePointer<[UInt32]>, _ pB: UnsafeMutablePointer<[UInt32]>, _ offset: Int) {
        let countA = pA.pointee.count
        let countB = pB.pointee.count
        let valueA = UInt32(pA.pointee[countA - 1]) + (countA > 1 ? 1 : 0)
        var valueB = UInt32(pB.pointee[countA + offset - 1]);
        var carry: UInt32 = (countA + offset < countB ? UInt32(pB.pointee[countA + offset]) : 0)
        var quotient: UInt32
        var multiplier: UInt16
        while carry != 0 || valueB >= valueA || (offset == 0 && lessThanOrEquals(pA, pB)) {
            if carry > UInt16.max {
                quotient = UInt32(UInt16.max)
            } else if carry > 0 {
                valueB = (carry << 16) | valueB
                quotient = valueB / valueA
            } else {
                quotient = valueB / valueA
                if quotient == 0 {
                    quotient = 1
                }
            }
            multiplier = (quotient > UInt16.max ? UInt16.max : UInt16(truncatingIfNeeded: quotient))
            let _ = subtract(pA, multiplier, pB, offset)
            carry = (countA + offset < countB ? UInt32(pB.pointee[countA + offset]) : 0)
            valueB = UInt32(pB.pointee[countA + offset - 1])
        }
    }

    /// Modular function : b % a
    static func mod(_ pA: UnsafePointer<[UInt32]>, _ pB: UnsafeMutablePointer<[UInt32]>) {
        let countA = pA.pointee.count
        let countB = pB.pointee.count
        let offsetAB = countB - countA
        var offset = offsetAB
        let valueA = UInt32(pA.pointee[countA - 1]) + (countA > 1 ? 1 : 0)
        var quotient: UInt32
        var multiplier: UInt16
        while offset >= 0 {
            var valueB = UInt32(pB.pointee[countA + offset - 1]);
            var carry = (countA + offset < countB ? UInt32(pB.pointee[countA + offset]) : 0)
            while carry != 0 || valueB >= valueA || (offset == 0 && lessThanOrEquals(pA, pB)) {
                if carry > UInt16.max {
                    quotient = UInt32(UInt16.max)
                } else if carry > 0 {
                    valueB = (carry << 16) | valueB
                    quotient = valueB / valueA
                } else {
                    quotient = valueB / valueA
                    if quotient == 0 {
                        quotient = 1
                    }
                }
                multiplier = (quotient > UInt16.max ? UInt16.max : UInt16(truncatingIfNeeded: quotient))
                _ = subtract(pA, multiplier, pB, offset)
                carry = (countA + offset < countB ? UInt32(pB.pointee[countA + offset]) : 0)
                valueB = UInt32(pB.pointee[countA + offset - 1])
            }
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

    static func lessThanOrEquals(_ pA: UnsafePointer<[UInt32]>, _ pB: UnsafeMutablePointer<[UInt32]>) -> Bool {
        // Skip zero MSBs
        var j = pB.pointee.count - 1
        while j >= 0, pB.pointee[j] == 0 {
            j -= 1
        }
        var i = pA.pointee.count - 1
        while i >= 0, pA.pointee[i] == 0 {
            i -= 1
            if i < j {
                return true
            }
        }
        if i < j {
            return true
        } else if i > j {
            return false
        }
        // i == j, switching to i as index
        while i >= 0 {
            if pA.pointee[i] < pB.pointee[i] {
                return true
            } else if pA.pointee[i] > pB.pointee[i] {
                return false
            }
            i -= 1
        }
        return true
    }

    /// Subtraction function : b - a * times (at offset of b)
    /// Note: multiplier range is [0,UInt16.max]
    static func subtract(_ pA: UnsafePointer<[UInt32]>, _ multiplier: UInt16, _ pB: UnsafeMutablePointer<[UInt32]>, _ offset: Int) -> Int32 {
        let countA = pA.pointee.count
        let countB = pB.pointee.count
        let times = UInt32(multiplier)
        var carry = Int32(0)
        var i = 0
        pB.withMemoryRebound(to: [Int32].self, capacity: countB) { pBI in
            while i < countA {
                let aHL = pA.pointee[i] * times
                let aL = Int32(aHL & 0xFFFF)
                let aH = Int32(aHL >> 16)
                var result = pBI.pointee[i+offset] - aL - carry
                carry = aH
                while result < 0 {
                    result += 0x00010000
                    carry += 1
                }
                pBI.pointee[i+offset] = result
                i += 1
            }
            if carry > 0 {
                i = countA + offset
                while i < countB, carry > 0 {
                    var result = pBI.pointee[i] - carry
                    carry = 0
                    while result < 0 {
                        result += 0x00010000
                        carry += 1
                    }
                    pBI.pointee[i] = result
                    i += 1
                }
            }
        }
        return carry
    }

    /// Replace self with self - value * multiplier (at offset of self)
    /// Note, multiplier range is [0,32767]
    func minus(_ value: UIntBig, _ multiplier: UInt16, _ offset: Int) -> UInt32 {
        let a = value.magnitude.map({ UInt32($0) })
        var b = magnitude.map({ UInt32($0) })
        var underflow = Int32(0)
        withUnsafePointer(to: a) { pA in
            withUnsafeMutablePointer(to: &b) { pB in
                underflow = UIntBig.subtract(pA, multiplier, pB, offset)
            }
        }
        magnitude = b.map({ UInt16(truncatingIfNeeded: $0) })
        UIntBig.trimZeroMSBs(&magnitude)
        return UInt32(underflow)
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
        let a = magnitude.map({ UInt32($0) })
        let b = multiplier.magnitude.map({ UInt32($0) })
        var product: [UInt32] = Array<UInt32>(repeating: 0, count: a.count + b.count)
        withUnsafePointer(to: a) { pA in
            withUnsafePointer(to: b) { pB in
                withUnsafeMutablePointer(to: &product) { pProduct in
                    UIntBig.times(pA, pB, pProduct)
                }
            }
        }
        magnitude = product.map({ UInt16(truncatingIfNeeded: $0) })
        UIntBig.trimZeroMSBs(&magnitude)
    }
    
    /// Optimised times function "product = a * b", this is the fastest implementation in Swift
    /// Further optimisation will need to move to Karatsuba algorithm
    static func times(_ pA: UnsafePointer<[UInt32]>, _ pB: UnsafePointer<[UInt32]>, _ pProduct: UnsafeMutablePointer<[UInt32]>) {
        let countA = pA.pointee.count
        let countB = pB.pointee.count
        // Indices for a, b, and product
        var i = 0, j = 0, k = 0
        // Shortcut : Test if either A or B is zero
        if countA == 0 || countB == 0 {
            return
        }
        // Shortcut : Test if A is one, copy B into P
        if countA == 1, pA.pointee[0] == 1 {
            while k < countB {
                pProduct.pointee[k] = pB.pointee[k]
                k += 1
            }
            return
        }
        // Shortcut : Test if B is one, copy A into P
        if countB == 1, pB.pointee[0] == 1 {
            while k < countA {
                pProduct.pointee[k] = pA.pointee[k]
                k += 1
            }
            return
        }
        // Multiplication
        var carry: UInt32
        while i < countA {
            carry = 0
            j = 0
            k = i
            let valueA = pA.pointee[i]
            while j < countB {
                carry += valueA * pB.pointee[j] + pProduct.pointee[k]
                pProduct.pointee[k] = carry & 0xFFFF
                carry >>= 16
                j += 1
                k += 1
            }
            pProduct.pointee[k] = carry
            i += 1
        }
        k += 1
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
        let ie = magnitude.count - 1
        withUnsafeMutablePointer(to: &magnitude) { pointer in
            while i < ie {
                pointer.pointee[i] = (pointer.pointee[i] >> 1) | (pointer.pointee[i + 1] << 15)
                i += 1
            }
            pointer.pointee[ie] >>= 1
        }
        UIntBig.trimZeroMSBs(&magnitude)
    }
    
    /// Remove leading zeros from array
    static func trimZeroMSBs(_ magnitude: inout [UInt16]) {
        let ie = magnitude.count - 1
        var i = ie
        while i > 0, magnitude[i] == UIntBig.zero {
            i -= 1
        }
        if i == 0, magnitude[0] == UIntBig.zero {
            magnitude = UIntBig.magnitudeZero
            return
        }
        if i == ie {
            return
        }
        magnitude.removeLast(ie - i)
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
