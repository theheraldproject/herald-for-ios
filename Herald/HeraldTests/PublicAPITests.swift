//
//  PublicAPITests.swift
//
//  Copyright 2022 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

// Reimplementing Mean to test Aggregate's subclassing from another Module
public class MyTestAggregate: Aggregate {
    public override var runs: Int { get { 1 }}
    private var run: Int = 1
    private var count: Int64 = 0
    private var sum: Double = 0

    public override func beginRun(thisRun: Int) {
        run = thisRun
    }

    public override func map(value: Sample) {
        guard run == 1 else {
            return
        }
        sum += value.value.value
        count += 1
    }

    public override func reduce() -> Double? {
        guard count > 0 else {
            return nil
        }
        return sum / Double(count)
    }

    public override func reset() {
        run = 1
        count = 0
        sum = 0
    }
}

// Test to replicate issue https://github.com/theheraldproject/herald-for-ios/issues/172
// Note: Due to the Tests being compiled *WITHIN* the Herald product, this check
//       doesn't actually fail!
// TODO: Determine how to add a separate project to perform external-API client tests too.
class PublicAPITests: XCTestCase {

    public func test_publicapi_aggregate() {
        let srcData = SampleList(25)
        srcData.push(secondsSinceUnixEpoch: 0, value: RSSI(-66))
        srcData.push(secondsSinceUnixEpoch: 10, value: RSSI(-66))
        srcData.push(secondsSinceUnixEpoch: 20, value: RSSI(-68))
        srcData.push(secondsSinceUnixEpoch: 30, value: RSSI(-68))
        srcData.push(secondsSinceUnixEpoch: 40, value: RSSI(-70))
        srcData.push(secondsSinceUnixEpoch: 50, value: RSSI(-70))

        let mean = MyTestAggregate()
        
        // values = -60, -68, -68
        let summary = srcData.aggregate([mean])
        XCTAssertEqual(summary.get(MyTestAggregate.self), -68)
    }
}
