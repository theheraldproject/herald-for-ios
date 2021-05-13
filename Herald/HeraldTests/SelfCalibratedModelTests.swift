//
//  SelfCalibratedModelTests.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//



import XCTest
@testable import Herald

class SelfCalibratedModelTests: XCTestCase {

    public func test_uncalibrated() {
        let model: SelfCalibratedModel = SelfCalibratedModel(min: Distance(0.2), mean: Distance(1), withinMin: TimeInterval.zero, withinMean: TimeInterval.hour * 12)
        
        model.map(value: Sample(secondsSinceUnixEpoch: 0, value: RSSI(-10)))
        XCTAssertEqual(model.reduce()!, 0.2, accuracy: 0.1)

        model.reset()
        model.map(value: Sample(secondsSinceUnixEpoch: 0, value: RSSI(-54)))
        XCTAssertEqual(model.reduce()!, 1.0, accuracy: 0.1)

        model.reset()
        model.map(value: Sample(secondsSinceUnixEpoch: 0, value: RSSI(-99)))
        XCTAssertEqual(model.reduce()!, 1.8, accuracy: 0.1)
    }

    public func test_calibrated_range() {
        for minRssi in -99...(-15) {
            for maxRssi in (minRssi+4)...(-11) {
                print("test_calibrated_range[\(minRssi),\(maxRssi)]");
                test_calibrated_range(minRssi, maxRssi)
            }
        }
    }

    private func test_calibrated_range(_ minRssi: Int, _ maxRssi: Int) {
        let midRssi = minRssi + (maxRssi - minRssi) / 2
        let quarterRssi = minRssi + (maxRssi - minRssi) * 3 / 4
        let model: SelfCalibratedModel = SelfCalibratedModel(min: Distance(0.2), mean: Distance(1), withinMin: TimeInterval.zero, withinMean: TimeInterval.hour * 12)
        for rssi in minRssi...maxRssi {
            model.histogram.add(rssi)
        }
        model.update()

        model.map(value: Sample(secondsSinceUnixEpoch: 0, value: RSSI(maxRssi)))
        XCTAssertEqual(model.reduce()!, 0.2, accuracy: 0.1)

        model.reset()
        model.map(value: Sample(secondsSinceUnixEpoch: 0, value: RSSI(quarterRssi)))
        XCTAssertEqual(model.reduce()!, 0.6, accuracy: 0.2)

        model.reset()
        model.map(value: Sample(secondsSinceUnixEpoch: 0, value: RSSI(midRssi)))
        XCTAssertEqual(model.reduce()!, 1.0, accuracy: 0.1)
    }

}
