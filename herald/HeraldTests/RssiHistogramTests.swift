//
//  RssiHistogramTests.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class RssiHistogramTests: XCTestCase {

    private func printRange(_ rssiHistogram: RssiHistogram, _ min: Int, _ max: Int) {
        for i in min...max {
            print("\(i),\(rssiHistogram.normalise(Double(i)))")
        }
    }
    
    public func test_empty() {
        let rssiHistogram = RssiHistogram(min: -99, max: -10, updatePeriod: TimeInterval.zero, textFile: nil)
        
        // Percentile values
        XCTAssertEqual(-10, rssiHistogram.samplePercentile(1.00))
        XCTAssertEqual(-32, rssiHistogram.samplePercentile(0.75))
        XCTAssertEqual(-54, rssiHistogram.samplePercentile(0.50))
        XCTAssertEqual(-55, rssiHistogram.samplePercentile(0.49))
        XCTAssertEqual(-77, rssiHistogram.samplePercentile(0.25))
        XCTAssertEqual(-99, rssiHistogram.samplePercentile(0.00))

        // Normalisation extends value to full range
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(1.00)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-32, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.75)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-54, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.50)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-55, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.49)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-77, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.25)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.00)), accuracy: Double.leastNonzeroMagnitude)

        // Out of range values clamped to min and max
        XCTAssertEqual(-99, rssiHistogram.normalise(-100), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(-99), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-50, rssiHistogram.normalise(-50), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-49, rssiHistogram.normalise(-49), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-10), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-9), accuracy: Double.leastNonzeroMagnitude)
    }
    
    public func test_zero_variance_10() {
        let rssiHistogram = RssiHistogram(min: -99, max: -10, updatePeriod: TimeInterval.zero, textFile: nil)
        rssiHistogram.add(-10)
        rssiHistogram.update()

        // Percentile values
        XCTAssertEqual(-10, rssiHistogram.samplePercentile(1.00))
        XCTAssertEqual(-10, rssiHistogram.samplePercentile(0.75))
        XCTAssertEqual(-10, rssiHistogram.samplePercentile(0.50))
        XCTAssertEqual(-10, rssiHistogram.samplePercentile(0.49))
        XCTAssertEqual(-10, rssiHistogram.samplePercentile(0.25))
        XCTAssertEqual(-99, rssiHistogram.samplePercentile(0.00))

        // Normalisation extends value to full range
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(1.00)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.75)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.50)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.49)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.25)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.00)), accuracy: Double.leastNonzeroMagnitude)

        // Out of range values clamped to min and max
        XCTAssertEqual(-99, rssiHistogram.normalise(-100), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(-99), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(-50), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(-49), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-10), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-9), accuracy: Double.leastNonzeroMagnitude)
    }

    public func test_zero_variance_10_x2() {
        let rssiHistogram = RssiHistogram(min: -99, max: -10, updatePeriod: TimeInterval.zero, textFile: nil)
        rssiHistogram.add(-10)
        rssiHistogram.add(-10)
        rssiHistogram.update()

        // Percentile values
        XCTAssertEqual(-10, rssiHistogram.samplePercentile(1.00))
        XCTAssertEqual(-10, rssiHistogram.samplePercentile(0.75))
        XCTAssertEqual(-10, rssiHistogram.samplePercentile(0.50))
        XCTAssertEqual(-10, rssiHistogram.samplePercentile(0.49))
        XCTAssertEqual(-10, rssiHistogram.samplePercentile(0.25))
        XCTAssertEqual(-99, rssiHistogram.samplePercentile(0.00))

        // Normalisation extends value to full range
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(1.00)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.75)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.50)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.49)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.25)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.00)), accuracy: Double.leastNonzeroMagnitude)

        // Out of range values clamped to min and max
        XCTAssertEqual(-99, rssiHistogram.normalise(-100), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(-99), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(-50), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(-49), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-10), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-9), accuracy: Double.leastNonzeroMagnitude)
    }

    public func test_zero_variance_50() {
        let rssiHistogram = RssiHistogram(min: -99, max: -10, updatePeriod: TimeInterval.zero, textFile: nil)
        rssiHistogram.add(-50)
        rssiHistogram.update()

        // Percentile values
        XCTAssertEqual(-50, rssiHistogram.samplePercentile(1.00))
        XCTAssertEqual(-50, rssiHistogram.samplePercentile(0.75))
        XCTAssertEqual(-50, rssiHistogram.samplePercentile(0.50))
        XCTAssertEqual(-50, rssiHistogram.samplePercentile(0.49))
        XCTAssertEqual(-50, rssiHistogram.samplePercentile(0.25))
        XCTAssertEqual(-99, rssiHistogram.samplePercentile(0.00))

        // Normalisation extends value to full range
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(1.00)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.75)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.50)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.49)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.25)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.00)), accuracy: Double.leastNonzeroMagnitude)

        // Out of range values clamped to min and max
        XCTAssertEqual(-99, rssiHistogram.normalise(-100), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(-99), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-50), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-49), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-10), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-9), accuracy: Double.leastNonzeroMagnitude)
    }

    public func test_zero_variance_50_x2() {
        let rssiHistogram = RssiHistogram(min: -99, max: -10, updatePeriod: TimeInterval.zero, textFile: nil)
        rssiHistogram.add(-50)
        rssiHistogram.add(-50)
        rssiHistogram.update()

        // Percentile values
        XCTAssertEqual(-50, rssiHistogram.samplePercentile(1.00))
        XCTAssertEqual(-50, rssiHistogram.samplePercentile(0.75))
        XCTAssertEqual(-50, rssiHistogram.samplePercentile(0.50))
        XCTAssertEqual(-50, rssiHistogram.samplePercentile(0.49))
        XCTAssertEqual(-50, rssiHistogram.samplePercentile(0.25))
        XCTAssertEqual(-99, rssiHistogram.samplePercentile(0.00))

        // Normalisation extends value to full range
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(1.00)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.75)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.50)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.49)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.25)), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.00)), accuracy: Double.leastNonzeroMagnitude)

        // Out of range values clamped to min and max
        XCTAssertEqual(-99, rssiHistogram.normalise(-100), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(-99), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-50), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-49), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-10), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-9), accuracy: Double.leastNonzeroMagnitude)
    }

    public func test_identity() {
        let rssiHistogram = RssiHistogram(min: -99, max: -10, updatePeriod: TimeInterval.zero, textFile: nil)
        for rssi in (-98)...(-10) {
            rssiHistogram.add(rssi)
        }
        rssiHistogram.update()

        // Percentile values
        XCTAssertEqual(-10, rssiHistogram.samplePercentile(1.00))
        XCTAssertEqual(-32, rssiHistogram.samplePercentile(0.75))
        XCTAssertEqual(-54, rssiHistogram.samplePercentile(0.50))
        XCTAssertEqual(-55, rssiHistogram.samplePercentile(0.49))
        XCTAssertEqual(-76, rssiHistogram.samplePercentile(0.25))
        XCTAssertEqual(-99, rssiHistogram.samplePercentile(0.00))

        // Normalisation extends value to full range
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(1.00)), accuracy: 0.5);
        XCTAssertEqual(-32, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.75)), accuracy: 0.5);
        XCTAssertEqual(-54, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.50)), accuracy: 0.5);
        XCTAssertEqual(-55, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.49)), accuracy: 0.5);
        XCTAssertEqual(-76, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.25)), accuracy: 0.5);
        XCTAssertEqual(-99, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.00)), accuracy: 0.5);

        // Out of range values clamped to min and max
        XCTAssertEqual(-99, rssiHistogram.normalise(-100), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(-99), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-50, rssiHistogram.normalise(-50), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-49, rssiHistogram.normalise(-49), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-10), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-9), accuracy: Double.leastNonzeroMagnitude)
    }

    public func test_identity_x2() {
        let rssiHistogram = RssiHistogram(min: -99, max: -10, updatePeriod: TimeInterval.zero, textFile: nil)
        for rssi in (-98)...(-10) {
            rssiHistogram.add(rssi)
            rssiHistogram.add(rssi)
        }
        rssiHistogram.update()

        // Percentile values
        XCTAssertEqual(-10, rssiHistogram.samplePercentile(1.00))
        XCTAssertEqual(-32, rssiHistogram.samplePercentile(0.75))
        XCTAssertEqual(-54, rssiHistogram.samplePercentile(0.50))
        XCTAssertEqual(-55, rssiHistogram.samplePercentile(0.49))
        XCTAssertEqual(-76, rssiHistogram.samplePercentile(0.25))
        XCTAssertEqual(-99, rssiHistogram.samplePercentile(0.00))

        // Normalisation extends value to full range
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(1.00)), accuracy: 0.5);
        XCTAssertEqual(-32, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.75)), accuracy: 0.5);
        XCTAssertEqual(-54, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.50)), accuracy: 0.5);
        XCTAssertEqual(-55, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.49)), accuracy: 0.5);
        XCTAssertEqual(-76, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.25)), accuracy: 0.5);
        XCTAssertEqual(-99, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.00)), accuracy: 0.5);

        // Out of range values clamped to min and max
        XCTAssertEqual(-99, rssiHistogram.normalise(-100), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(-99), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-50, rssiHistogram.normalise(-50), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-49, rssiHistogram.normalise(-49), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-10), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-9), accuracy: Double.leastNonzeroMagnitude)
    }

    public func test_upper_range() {
        let rssiHistogram = RssiHistogram(min: -99, max: -10, updatePeriod: TimeInterval.zero, textFile: nil)
        for rssi in (-44)...(-10) {
            rssiHistogram.add(rssi)
        }
        rssiHistogram.update()

        // Percentile values
        XCTAssertEqual(-10, rssiHistogram.samplePercentile(1.00))
        XCTAssertEqual(-18, rssiHistogram.samplePercentile(0.75))
        XCTAssertEqual(-27, rssiHistogram.samplePercentile(0.50))
        XCTAssertEqual(-27, rssiHistogram.samplePercentile(0.49))
        XCTAssertEqual(-36, rssiHistogram.samplePercentile(0.25))
        XCTAssertEqual(-44, rssiHistogram.samplePercentile(0.01))
        XCTAssertEqual(-99, rssiHistogram.samplePercentile(0.00))

        // Normalisation extends value to full range
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(1.00)), accuracy: 0.5)
        XCTAssertEqual(-30, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.75)), accuracy: 0.5)
        XCTAssertEqual(-53, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.50)), accuracy: 0.5)
        XCTAssertEqual(-53, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.49)), accuracy: 0.5)
        XCTAssertEqual(-76, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.25)), accuracy: 0.5)
        XCTAssertEqual(-99, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.00)), accuracy: 0.5)

        // Out of range values clamped to min and max
        XCTAssertEqual(-99, rssiHistogram.normalise(-46), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(-45), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-96, rssiHistogram.normalise(-44), accuracy: 0.5)
        XCTAssertEqual(-53, rssiHistogram.normalise(-27), accuracy: 0.5)
        XCTAssertEqual(-13, rssiHistogram.normalise(-11), accuracy: 0.5)
        XCTAssertEqual(-10, rssiHistogram.normalise(-10), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-9), accuracy: Double.leastNonzeroMagnitude)
    }
    
    public func test_upper_range_x2() {
        let rssiHistogram = RssiHistogram(min: -99, max: -10, updatePeriod: TimeInterval.zero, textFile: nil)
        for rssi in (-44)...(-10) {
            rssiHistogram.add(rssi)
            rssiHistogram.add(rssi)
        }
        rssiHistogram.update()

        // Percentile values
        XCTAssertEqual(-10, rssiHistogram.samplePercentile(1.00))
        XCTAssertEqual(-18, rssiHistogram.samplePercentile(0.75))
        XCTAssertEqual(-27, rssiHistogram.samplePercentile(0.50))
        XCTAssertEqual(-27, rssiHistogram.samplePercentile(0.49))
        XCTAssertEqual(-36, rssiHistogram.samplePercentile(0.25))
        XCTAssertEqual(-44, rssiHistogram.samplePercentile(0.01))
        XCTAssertEqual(-99, rssiHistogram.samplePercentile(0.00))

        // Normalisation extends value to full range
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(1.00)), accuracy: 0.5)
        XCTAssertEqual(-30, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.75)), accuracy: 0.5)
        XCTAssertEqual(-53, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.50)), accuracy: 0.5)
        XCTAssertEqual(-53, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.49)), accuracy: 0.5)
        XCTAssertEqual(-76, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.25)), accuracy: 0.5)
        XCTAssertEqual(-99, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.00)), accuracy: 0.5)

        // Out of range values clamped to min and max
        XCTAssertEqual(-99, rssiHistogram.normalise(-46), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-99, rssiHistogram.normalise(-45), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-96, rssiHistogram.normalise(-44), accuracy: 0.5)
        XCTAssertEqual(-53, rssiHistogram.normalise(-27), accuracy: 0.5)
        XCTAssertEqual(-13, rssiHistogram.normalise(-11), accuracy: 0.5)
        XCTAssertEqual(-10, rssiHistogram.normalise(-10), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-9), accuracy: Double.leastNonzeroMagnitude)
    }
    
    public func test_lower_range() {
        let rssiHistogram = RssiHistogram(min: -99, max: -10, updatePeriod: TimeInterval.zero, textFile: nil)
        for rssi in (-98)...(-45) {
            rssiHistogram.add(rssi)
        }
        rssiHistogram.update()

        // Percentile values
        XCTAssertEqual(-45, rssiHistogram.samplePercentile(1.00))
        XCTAssertEqual(-58, rssiHistogram.samplePercentile(0.75))
        XCTAssertEqual(-72, rssiHistogram.samplePercentile(0.50))
        XCTAssertEqual(-72, rssiHistogram.samplePercentile(0.49))
        XCTAssertEqual(-85, rssiHistogram.samplePercentile(0.25))
        XCTAssertEqual(-98, rssiHistogram.samplePercentile(0.01))
        XCTAssertEqual(-99, rssiHistogram.samplePercentile(0.00))

        // Normalisation extends value to full range
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(1.00)), accuracy: 0.5)
        XCTAssertEqual(-31, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.75)), accuracy: 0.5)
        XCTAssertEqual(-55, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.50)), accuracy: 0.5)
        XCTAssertEqual(-55, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.49)), accuracy: 0.5)
        XCTAssertEqual(-76, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.25)), accuracy: 0.5)
        XCTAssertEqual(-99, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.00)), accuracy: 0.5)

        // Out of range values clamped to min and max
        XCTAssertEqual(-99, rssiHistogram.normalise(-99), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-97, rssiHistogram.normalise(-98), accuracy: 0.5)
        XCTAssertEqual(-76, rssiHistogram.normalise(-85), accuracy: 0.5)
        XCTAssertEqual(-55, rssiHistogram.normalise(-72), accuracy: 0.5)
        XCTAssertEqual(-31, rssiHistogram.normalise(-58), accuracy: 0.5)
        XCTAssertEqual(-10, rssiHistogram.normalise(-45), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-9), accuracy: Double.leastNonzeroMagnitude)
    }

    public func test_lower_range_x2() {
        let rssiHistogram = RssiHistogram(min: -99, max: -10, updatePeriod: TimeInterval.zero, textFile: nil)
        for rssi in (-98)...(-45) {
            rssiHistogram.add(rssi)
            rssiHistogram.add(rssi)
        }
        rssiHistogram.update()

        // Percentile values
        XCTAssertEqual(-45, rssiHistogram.samplePercentile(1.00))
        XCTAssertEqual(-58, rssiHistogram.samplePercentile(0.75))
        XCTAssertEqual(-72, rssiHistogram.samplePercentile(0.50))
        XCTAssertEqual(-72, rssiHistogram.samplePercentile(0.49))
        XCTAssertEqual(-85, rssiHistogram.samplePercentile(0.25))
        XCTAssertEqual(-98, rssiHistogram.samplePercentile(0.01))
        XCTAssertEqual(-99, rssiHistogram.samplePercentile(0.00))

        // Normalisation extends value to full range
        XCTAssertEqual(-10, rssiHistogram.normalise(rssiHistogram.samplePercentile(1.00)), accuracy: 0.5)
        XCTAssertEqual(-31, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.75)), accuracy: 0.5)
        XCTAssertEqual(-55, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.50)), accuracy: 0.5)
        XCTAssertEqual(-55, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.49)), accuracy: 0.5)
        XCTAssertEqual(-76, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.25)), accuracy: 0.5)
        XCTAssertEqual(-99, rssiHistogram.normalise(rssiHistogram.samplePercentile(0.00)), accuracy: 0.5)

        // Out of range values clamped to min and max
        XCTAssertEqual(-99, rssiHistogram.normalise(-99), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-97, rssiHistogram.normalise(-98), accuracy: 0.5)
        XCTAssertEqual(-76, rssiHistogram.normalise(-85), accuracy: 0.5)
        XCTAssertEqual(-55, rssiHistogram.normalise(-72), accuracy: 0.5)
        XCTAssertEqual(-31, rssiHistogram.normalise(-58), accuracy: 0.5)
        XCTAssertEqual(-10, rssiHistogram.normalise(-45), accuracy: Double.leastNonzeroMagnitude)
        XCTAssertEqual(-10, rssiHistogram.normalise(-9), accuracy: Double.leastNonzeroMagnitude)
    }
}
