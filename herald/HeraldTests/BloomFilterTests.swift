//
//  BloomFilterTests.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import XCTest
@testable import Herald

class BloomFilterTests: XCTestCase {
    
    func test() {
        let bloomFilter = BloomFilter(1024 * 1024)
        for i in 0...10000 {
            bloomFilter.add(networkByteOrderData(Int32(i * 2)))
        }
        for i in 0...10000 {
            XCTAssertTrue(bloomFilter.contains(networkByteOrderData(Int32(i * 2))))
        }
        for i in 0...10000 {
            XCTAssertFalse(bloomFilter.contains(networkByteOrderData(Int32(i * 2 + 1))))
        }
    }

    private func networkByteOrderData(_ identifier: Int32) -> Data {
        var mutableSelf = identifier.bigEndian // network byte order
        return Data(bytes: &mutableSelf, count: MemoryLayout.size(ofValue: mutableSelf))
    }
}
