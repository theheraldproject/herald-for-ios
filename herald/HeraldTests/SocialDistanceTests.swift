////
//  SocialDistanceTests.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import XCTest
@testable import Herald

class SocialDistanceTests: XCTestCase {

    /// Expect measured power and distance calculations are reversible
    func testMeasuredPowerAndDistanceConversion() throws {
        for i in 0...200 {
            let distance = Double(i)
            let rssi = Double(-i)
            let estimated = SocialDistance.distance(measuredPower: SocialDistance.measuredPower(distance: distance, rssi: rssi), rssi: rssi)
            let delta = abs(distance - estimated)
            XCTAssertLessThanOrEqual(delta, Double(0.0001))
            print("\(distance),\(rssi),\(estimated)")
        }
    }
    
    /// Expect distance and Rssi calculations are reversible
    func testDistanceAndRssiConversion() throws {
        for i in 0...200 {
            let distance = Double(i)
            let measuredPower = Double(-i)
            let estimated = SocialDistance.distance(measuredPower: measuredPower, rssi: SocialDistance.rssi(distance: distance, measuredPower: measuredPower))
            let delta = abs(distance - estimated)
            XCTAssertLessThanOrEqual(delta, Double(0.0001))
            print("\(distance),\(measuredPower),\(estimated)")
        }
    }

    func testMeasuredPowerEstimation() throws {
        for p in -65 ... -28 {
            let socialDistance = SocialDistance()
            let measuredPower = Double(p)
            let minRssi: Double = SocialDistance.rssi(distance: 0.45, measuredPower: measuredPower)
            for i in 0 ... 5 {
                let proximity = Proximity(unit: .RSSI, value: minRssi)
                socialDistance.sensor(.BLE, didMeasure: proximity, fromTarget: TargetIdentifier("T\(i)"))
            }
            for i in 6 ... 100 {
                let proximityValue = minRssi - ((minRssi - Double(-100)) * Double(i) / Double(100))
                let proximity = Proximity(unit: .RSSI, value: proximityValue)
                socialDistance.sensor(.BLE, didMeasure: proximity, fromTarget: TargetIdentifier("T\(i)"))
            }
            let delta = abs(socialDistance.measuredPower() - measuredPower)
            XCTAssertLessThanOrEqual(delta, Double(0.0001))
        }
    }
}
