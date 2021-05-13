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
                print("\(i),\(j),\(i%j),\(a.uint64())")
                XCTAssertEqual(i % j, a.uint64())
                j *= 7
            }
            i *= 3
        }
    }
    
    public func testModPerformance() {
        let modpGroup14Key: String = (
            "FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1" +
            "29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD" +
            "EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245" +
            "E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED" +
            "EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE45B3D" +
            "C2007CB8 A163BF05 98DA4836 1C55D39A 69163FA8 FD24CF5F" +
            "83655D23 DCA3AD96 1C62F356 208552BB 9ED52907 7096966D" +
            "670C354E 4ABC9804 F1746C08 CA18217C 32905E46 2E36CE3B" +
            "E39E772C 180E8603 9B2783A2 EC07A28F B5C55DF0 6F4C52C9" +
            "DE2BCBF6 95581718 3995497C EA956AE5 15D22618 98FA0510" +
            "15728E5A 8AACAA68 FFFFFFFF FFFFFFFF")
            .replacingOccurrences(of: " ", with: "")
        let p = UIntBig(modpGroup14Key)!
        let alicePublicKeyString = "E03560806F04BBD8D910D283581FCA1F47858CA4A4CEE93C410E55C13E25275239626D20BED40EFFF839B9FA8A3D7B6BD034229AD1096CFB45D2761F771AD68AA14424C0CB7E67BE87D94C0AE2C70C3F6A53B56F9711DDEAAC0B6B8B0F117105EDD56E77DAA6328B8B49E20DB80DE87691CDB555A6B0536CAD6B4A4D6588EFB0619DFB0D6EE2AED2F604F9FEBAF976BEEFC327FC567C1ACFBC66503F02DA13BEA9AA81B8E5C726D2070DC4A25423BDDD75DB5A086ED39C9EF694C8E4BCCD906D005C69245D3E3C9F201604276E6687BD8096D97B2E0C2FE57328846B13D464D8624D33503D12E3A92E0802FFF29DFBBB1AA69DB29D21E25F1FBE6AFBA6F9F17E"
        let alicePublicKey = UIntBig(alicePublicKeyString)!
        alicePublicKey.mod(p)
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
                    print("\(i),\(j),\(k),\(ex),\(ac)")
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
        var t1 = UInt64(0)
        for x in 0...samples {
            let i = UInt64.random(in: 0...UInt64.max)
            let j = UInt64.random(in: 0...UInt64.max)
            let k = UInt64.random(in: 0...UInt64.max)
            let a1 = UIntBig(i)
            let b1 = UIntBig(j)
            let c1 = UIntBig(k)
            let tS1 = DispatchTime.now()
            let _ = a1.modPow(b1, c1)
            let tE1 = DispatchTime.now()
            t1 += (tE1.uptimeNanoseconds - tS1.uptimeNanoseconds)
            if x % 10 == 0, x > 0, x < samples {
                print("sample=\(x),UIntBig=\(t1 / x)ns/call");
            }
        }
        print("sample=\(samples),UIntBig=\(t1 / samples)ns/call");
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
        let random = RandomSource(method: .Test, testValue: 0xFF)
        var i = Int(1)
        while i < (Int16.max / 3) {
            let a = UIntBig(bitLength: i, random: random)
            XCTAssertNotNil(a)
            XCTAssertEqual(i, a!.bitLength())
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
            XCTAssertEqual(UIntBig(i), data.uintBig(0))
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
                    print("\(i),\(j),\(k),\(data.base64EncodedString())")
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
