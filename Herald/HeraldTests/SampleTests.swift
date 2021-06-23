//
//  SampleTests.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//



import XCTest
@testable import Herald

class SampleTests: XCTestCase {
    
    private class Value: DoubleValue {
    }

    func testSample() {
        let s1 = Sample(taken: Date(timeIntervalSince1970: 1), value: Value(1))
        let s1Copy = Sample(taken: Date(timeIntervalSince1970: 1), value: Value(1))
        let s2 = Sample(taken: Date(timeIntervalSince1970: 2), value: Value(2))
        
        XCTAssertEqual(s1.taken, s1Copy.taken)
        XCTAssertEqual(s1.value.value, s1Copy.value.value)
        XCTAssertNotEqual(s1.taken, s2.taken)
        XCTAssertNotEqual(s1.value.value, s2.value.value)
    }

}
