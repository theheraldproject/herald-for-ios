//
//  SampleTests.swift
//
//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//



import XCTest
@testable import Herald

class SampleTests: XCTestCase {
    
    private class Value: DoubleValue {
    }

    func testSample() {
        let s1 = Sample<Value>(taken: Date(timeIntervalSince1970: 1), value: Value(doubleValue: 1))
        let s1Copy = Sample<Value>(taken: Date(timeIntervalSince1970: 1), value: Value(doubleValue: 1))
        let s2 = Sample<Value>(taken: Date(timeIntervalSince1970: 2), value: Value(doubleValue: 2))
        
        XCTAssertEqual(s1.taken, s1Copy.taken)
        XCTAssertEqual(s1.value.doubleValue(), s1Copy.value.doubleValue())
        XCTAssertNotEqual(s1.taken, s2.taken)
        XCTAssertNotEqual(s1.value.doubleValue(), s2.value.doubleValue())
    }

}
