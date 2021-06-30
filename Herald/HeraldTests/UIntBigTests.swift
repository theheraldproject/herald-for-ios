//
//  UIntBigTests.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class UIntBigTests: XCTestCase {

    public func testLongValue() {
        XCTAssertEqual(0, UIntBig(0).uint64())
        var i = UInt64(1)
        while i < (Int64.max / 3) {
            XCTAssertEqual(i, UIntBig(i).uint64())
            i *= 3
        }
    }
    
    // MARK: - Basic tests
    
    public func testIsZero() {
        XCTAssertTrue(UIntBig(0).isZero)
        XCTAssertFalse(UIntBig(1).isZero)
        XCTAssertFalse(UIntBig(256).isZero)
        XCTAssertFalse(UIntBig(UInt64(Int64.max)).isZero)
    }

    public func testIsOne() {
        XCTAssertFalse(UIntBig(0).isOne)
        XCTAssertTrue(UIntBig(1).isOne)
        XCTAssertFalse(UIntBig(257).isOne)
        XCTAssertFalse(UIntBig(UInt64(Int64.max)).isOne)
    }

    public func testIsOdd() {
        XCTAssertFalse(UIntBig(0).isOdd)
        XCTAssertTrue(UIntBig(1).isOdd)
        XCTAssertFalse(UIntBig(512).isOdd)
        XCTAssertTrue(UIntBig(513).isOdd)
        XCTAssertFalse(UIntBig(UInt64(Int64.max) - 1).isOdd)
        XCTAssertTrue(UIntBig(UInt64(Int64.max)).isOdd)
    }
    
    // MARK: - Trim leading zero
    
    public func testTrimZeroMSBs() {
        for i in 0...64 {
            var magnitude = Array<UInt16>(repeating: 1, count: i)
            magnitude.append(contentsOf: Array<UInt16>(repeating: 0, count: 64 - i))
            UIntBig.trimZeroMSBs(&magnitude)
            XCTAssertEqual(i, magnitude.count)
        }
    }

    // Baseline : 5,006ns
    // RemoveLast : 4,646ns
    public func testTrimZeroMSBsPerformance() {
        let samples = UInt64(2000)
        var elapsed = UInt64(0)
        for _ in 1...samples {
            var magnitude = Array<UInt16>(repeating: 1, count: 2)
            magnitude.append(contentsOf: Array<UInt16>(repeating: 0, count: 254))
            let t0 = DispatchTime.now()
            UIntBig.trimZeroMSBs(&magnitude)
            let t1 = DispatchTime.now()
            elapsed += (t1.uptimeNanoseconds - t0.uptimeNanoseconds)
        }
        let speed = elapsed / samples
        print("UIntBig.trimZeroMSBs() = \(speed)ns/call")
    }

    // MARK: - Right shift by one

    public func testRightShiftByOne() {
        var i = UInt64(1)
        while i < (Int64.max / 3) {
            let a = UIntBig(i)
            a.rightShiftByOne()
            let b = a.uint64()
            let c = i >> 1
            XCTAssertEqual(String(c,radix:2), String(b,radix:2))
            i *= 3
        }
    }
    
    // Baseline implementation : 76,879ns
    // Fixed ie = magnitude.count - 1 : 71,910ns
    // WithUnsafeMutablePointer : 63,431ns
    // Combined >>= and |= to = : 60,431ns
    public func testRightShiftByOnePerformance() {
        let samples = UInt64(1000)
        let hex = String(repeating: "FF", count: 256)
        var elapsed = UInt64(0)
        for _ in 1...samples {
            let n = UIntBig(hex)!
            let t0 = DispatchTime.now()
            n.rightShiftByOne()
            let t1 = DispatchTime.now()
            elapsed += (t1.uptimeNanoseconds - t0.uptimeNanoseconds)
        }
        let speed = elapsed / samples
        print("UIntBig.rightShiftByOne() = \(speed)ns/call")
    }

    // MARK: - Times

    public func testTimes() {
        // a * 0
        var i = UInt64(1)
        while i < (Int64.max / 3) {
            let a = UIntBig(i)
            let b = UIntBig(0)
            a.times(b)
            XCTAssertEqual(0, a.uint64())
            i *= 3
        }
        // 0 * b
        i = UInt64(1)
        while i < (Int64.max / 3) {
            let a = UIntBig(0)
            let b = UIntBig(i)
            a.times(b)
            XCTAssertEqual(0, a.uint64())
            i *= 3
        }
        // a * b
        i = UInt64(1)
        while i < (Int64.max / 3) {
            var j = UInt64(1)
            while j < (Int64.max / 3) {
                if i.multipliedReportingOverflow(by: j).overflow {
                    break
                }
                let a = UIntBig(i)
                let b = UIntBig(j)
                a.times(b)
                XCTAssertEqual(i*j, a.uint64())
                j *= 3
            }
            i *= 3
        }
    }
    
    // Baseline implementation : 17,933,717ns
    // Pre-cast UInt16 to UInt32 for A and B  : 14,292,294ns
    // Post-cast UInt32 to UInt12 for Product : 13,209,268ns
    // Dedicated static function for times : 12,940,940ns
    // Pre-allocating a, b, and product : 12,939,280ns
    // for (i, valueA) in a.enumerated(), for (j, valueB) in b.enumerated : 9,822,250ns
    // for valueA in a, for valueB in b, and dedicated i,j,k counting : 8,346,576ns
    // Wrapped static function as self.times call : 8,438,665ns
    // withUnsafePointer as inner loop : 4,931,951ns
    // withUnsafePointer as outer loop : 4,922,198ns
    // Passing unsafePointers as parameters : 4,769,243ns
    // Passing unsafeMutablePointer as parameter : 4,633,002ns
    //
    // Next change to improve performance will require switching to Karatsuba algorithm
    // to reduce O(n^2) to O(n^1.58). It may be more productive to just switch to C.
    public func testTimesPerformance() {
        let samples = UInt64(100)
        let hex = String(repeating: "FF", count: 256)
        var elapsed = UInt64(0)
        let n = UIntBig(hex)!
        let a = n.magnitude.map({ UInt32($0) })
        let b = n.magnitude.map({ UInt32($0) })
        withUnsafePointer(to: a) { pA in
            withUnsafePointer(to: b) { pB in
                for _ in 1...samples {
                    var product = Array<UInt32>(repeating: 0, count: a.count + b.count)
                    withUnsafeMutablePointer(to: &product) { pProduct in
                        let t0 = DispatchTime.now()
                        UIntBig.times(pA, pB, pProduct)
                        let t1 = DispatchTime.now()
                        elapsed += (t1.uptimeNanoseconds - t0.uptimeNanoseconds)
                    }
                }
            }
        }
        let speed = elapsed / samples
        print("UIntBig.times() = \(speed)ns/call")
    }

    // MARK: - Minus
    
    public func testMinus() {
        var i = UInt64(1)
        while i < (Int64.max / 3) {
            var j = UInt64(1)
            while j < (Int64.max / 7) {
                var k = UInt64(1)
                while j * k <= i, k < (Int16.max / 11) {
                    let (partialValue, overflow) = j.multipliedReportingOverflow(by: k)
                    if overflow || partialValue > i {
                        break
                    }
                    let a = UIntBig(i)
                    let b = UIntBig(j)
                    let multiplier = UInt16(k)
                    let _ = a.minus(b, multiplier, 0)
                    XCTAssertEqual(i-j*k, a.uint64())
                    k *= 11
                }
                j *= 7
            }
            i *= 3
        }
    }
    
    public func testMinusOffset() {
        var i = UInt64(1)
        while i < (Int64.max / 3) {
            var j = UInt64(1)
            while j < (Int64.max / 7) {
                var k = UInt64(1)
                while (j << 16) * k <= i, k < (Int16.max / 11) {
                    let a = UIntBig(i)
                    let b = UIntBig(j)
                    if (a.magnitude.count >= b.magnitude.count + 1) {
                        let (partialValue, overflow) = (j << 16).multipliedReportingOverflow(by: k)
                        if overflow || partialValue > i {
                            break
                        }
                        let multiplier = UInt16(k)
                        let _ = a.minus(b, multiplier, 1)
                        XCTAssertEqual(i - (j << 16) * k, a.uint64())
                    }
                    k *= 11
                }
                j *= 7
            }
            i *= 3
        }
    }
    
    // Baseline : 142,096ns
    // Eliminate casting and replaced first for loop with withUnsafePointer loop : 80,801ns
    // Eliminate casting and replaced second while loop with withUnsafePointer loop : 73,378ns
    // Replace inner while loops for negative results with calculation : 67,717ns
    public func testSubtractPerformance() {
        let samples = UInt64(1000)
        let a = UIntBig(String(repeating: "FF", count: 255))!.magnitude.map({ UInt32($0) })
        var elapsed = UInt64(0)
        withUnsafePointer(to: a) { pA in
            for _ in 1...samples {
                var b = UIntBig(String(repeating: "FF", count: 256))!.magnitude.map({ UInt32($0) })
                withUnsafeMutablePointer(to: &b) { pB in
                    let t0 = DispatchTime.now()
                    let _ = UIntBig.subtract(pA, 2, pB, 0)
                    let t1 = DispatchTime.now()
                    elapsed += (t1.uptimeNanoseconds - t0.uptimeNanoseconds)
                }
            }
            let speed = elapsed / samples
            print("UIntBig.subtract() = \(speed)ns/call")
        }
    }

    // MARK: - Compare
    
    public func testCompare() {
        XCTAssertEqual(-1, UIntBig(0).compare(UIntBig(1)))
        XCTAssertEqual(0, UIntBig(0).compare(UIntBig(0)))
        XCTAssertEqual(1, UIntBig(1).compare(UIntBig(0)))
        var i = UInt64(1)
        while i < (Int64.max / 3) {
            let a = UIntBig(i)
            var j = UInt64(1)
            while j < (Int64.max / 3) {
                let b = UIntBig(j)
                XCTAssertEqual(i < j, a < b)
                XCTAssertEqual(i < j, a.compare(b) == -1)
                XCTAssertEqual(i == j, a.compare(b) == 0)
                XCTAssertEqual(i > j, a.compare(b) == 1)
                XCTAssertEqual(i == j, a == b)
                XCTAssertEqual(i == j, a.hashValue == b.hashValue)
                j *= 3
            }
            i *= 3
        }
    }

    // MARK: - Mod

    public func testMod() {
        var i = UInt64(1)
        while i < (Int64.max / 3) {
            var j = UInt64(1)
            while j < (Int64.max / 3) {
                let a = UIntBig(i)
                let b = UIntBig(j)
                a.mod(b)
                XCTAssertEqual(i % j, a.uint64())
                j *= 7
            }
            i *= 3
        }
    }
    
    // Baseline after subtract optimisation : 237,725ns
    // UnsafePointer as parameter : 232,203ns
    // Reduce function as inner loop : 201,585ns
    // Minimise var allocations : 197,770ns
    public func testModPerformance() {
        let samples = UInt64(1000)
        let a = UIntBig(String(repeating: "FF", count: 1))!.magnitude.map({ UInt32($0) })
        var elapsed = UInt64(0)
        withUnsafePointer(to: a) { pA in
            for _ in 1...samples {
                var b = UIntBig(String(repeating: "FF", count: 256))!.magnitude.map({ UInt32($0) })
                let t0 = DispatchTime.now()
                withUnsafeMutablePointer(to: &b) { pB in
                    UIntBig.mod(pA, pB)
                }
                let t1 = DispatchTime.now()
                elapsed += (t1.uptimeNanoseconds - t0.uptimeNanoseconds)
            }
        }
        let speed = elapsed / samples
        print("UIntBig.mod() = \(speed)ns/call")
    }
    
    // MARK: - ModPow

    public func testModPow() {
        // Cannot use same test range as Android as Swift has no
        // BigInteger equivalent for validation against reference
        // pow() will overflow and % operator is also limited here
        var i = UInt64(1)
        while i < (Int64.max >> 10) {
            var j = UInt64(1)
            while j < (Int64.max >> 10) {
                let p = pow(Double(i), Double(j))
                if p == .infinity || p > Double(Int64.max / 4) {
                    break
                }
                var k = UInt64(1)
                while k < (Int64.max >> 2) {
                    let b = UIntBig(i)
                    let m = b.modPow(UIntBig(j), UIntBig(k))
                    let ex = UInt64(pow(Double(i), Double(j))) % k
                    let ac = m.uint64()
                    XCTAssertEqual(ex, ac)
                    k *= 3
                }
                j *= 3
            }
            i *= 11
        }
    }

    public func testModPowPerformance() {
        // Cannot use same test range as Android as Swift is much slower
        let samples = UInt64(100)
        var elapsed = UInt64(0)
        for _ in 0...samples {
            let a = UIntBig(bitLength: 64)
            let b = UIntBig(bitLength: 64)
            let c = UIntBig(bitLength: 64)
            let t0 = DispatchTime.now()
            let _ = a.modPow(b, c)
            let t1 = DispatchTime.now()
            elapsed += (t1.uptimeNanoseconds - t0.uptimeNanoseconds)
        }
        let speed = elapsed / samples
        print("UIntBig.modPow() = \(speed)ns/call")
    }

    // MARK: - Hex

    public func testHexEncodedString() throws {
        XCTAssertEqual(0, UIntBig("")!.uint64())
        XCTAssertEqual(0, UIntBig("0")!.uint64())
        var i = UInt64(1)
        while i < (UInt64.max / 3) {
            let hex = String(i, radix: 16)
            let a = UIntBig(hex)!
            let hexEncodedString = (hex.count % 2 == 1 ? "0" : "") + hex.uppercased()
            XCTAssertEqual(i, a.uint64())
            XCTAssertEqual(hexEncodedString, a.hexEncodedString)
            i *= 3
        }
    }
    
    // MARK: - Bit length
    
    public func testBitLength() {
        XCTAssertEqual(0, UIntBig(0).bitLength())
        var i = UInt64(1)
        while i < (Int64.max / 3) {
            let a = String(i, radix: 2)
            let b = UIntBig(i)
            XCTAssertEqual(a.count, b.bitLength())
            i *= 3
        }
    }

    public func testRandom() {
        let random = TestRandomFunction(0xFF)
        var i = Int(1)
        while i < (Int16.max / 3) {
            let a = UIntBig(bitLength: i, random: random)
            XCTAssertNotNil(a)
            XCTAssertEqual(i, a.bitLength())
            i *= 3
        }
    }

    // MARK: - Cross-platform

    public func testCrossPlatform() {
        var csv = "value,data\n"
        var i = UInt64(1)
        while i <= (Int64.max / 7) {
            var data = Data()
            data.append(UIntBig(i))
            let (value, start, end) = data.uintBig(0)!
            XCTAssertEqual(UIntBig(i), value)
            XCTAssertEqual(start, 0)
            XCTAssertEqual(end, 4 + UIntBig(i).magnitude.count * 2)
            csv.append("\(i),\(data.base64EncodedString())\n")
            i *= 7
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "uintBig.csv"
        add(attachment)
    }

    public func testCrossPlatformModPow() {
        var csv = "a,b,c,d\n"
        var i = UInt64(1)
        while i < 0x000FFFFFFFFFFFFF {
            var j = UInt64(1)
            while j < 0x000FFFFFFFFFFFFF {
                var k = UInt64(1)
                while k < 0x000FFFFFFFFFFFFF {
                    let a = UIntBig(i)
                    let b = UIntBig(j)
                    let c = UIntBig(k)
                    let d = a.modPow(b, c)
                    var data = Data()
                    data.append(d)
                    csv.append("\(i),\(j),\(k),\(data.base64EncodedString())\n")
                    k *= 3
                }
                j *= 7
            }
            i *= 11
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "uintBigModPow.csv"
        add(attachment)
    }
    
    // MARK: - Equals
    
    public func testEquals() {
        XCTAssertTrue(UIntBig(0) == UIntBig(0))
        XCTAssertFalse(UIntBig(0) == UIntBig(1))
        XCTAssertFalse(UIntBig(1) == UIntBig(0))
        var i = UInt64(1)
        while i < (Int64.max / 3) {
            XCTAssertTrue(UIntBig(i) == UIntBig(i))
            XCTAssertFalse(UIntBig(i) == UIntBig(i+1))
            i *= 3
        }
    }
    
    // MARK: - Hashable
    
    public func testHash() {
        XCTAssertEqual(UIntBig(0).hashValue, UIntBig(0).hashValue)
        XCTAssertNotEqual(UIntBig(0).hashValue, UIntBig(1).hashValue)
        var i = UInt64(1)
        while i < (Int64.max / 3) {
            XCTAssertEqual(UIntBig(i).hashValue, UIntBig(i).hashValue)
            XCTAssertNotEqual(UIntBig(i).hashValue, UIntBig(i+1).hashValue)
            i *= 3
        }
    }
}
