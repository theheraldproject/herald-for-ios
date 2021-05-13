//
//  BloomFilterTests.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class BloomFilterTests: XCTestCase {
    
    func test() {
        let bloomFilter = BloomFilter(1024 * 1024)
        // Add even numbers to bloom filter
        for i in 0...10000 {
            var data = Data()
            data.append(Int32(i * 2))
            bloomFilter.add(data)
        }
        // Test even numbers are all contained in bloom filter
        for i in 0...10000 {
            var data = Data()
            data.append(Int32(i * 2))
            XCTAssertTrue(bloomFilter.contains(data))
        }
        // Confirm odd numbers are not in bloom filter
        for i in 0...10000 {
            var data = Data()
            data.append(Int32(i * 2 + 1))
            XCTAssertFalse(bloomFilter.contains(data))
        }
    }
}
