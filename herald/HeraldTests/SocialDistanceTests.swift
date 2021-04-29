////
//  SocialDistanceTests.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class SocialDistanceTests: XCTestCase {

    func testScoreByProximity() {
        let socialDistance = SocialDistance()
        XCTAssertEqual(socialDistance.scoreByProximity(K.date("2020-09-24T00:00:00+0000")!, K.date("2020-09-24T01:00:00+0000")!), 0)
        
        // Close enough to count
        socialDistance.append(Encounter(Proximity(unit: .RSSI, value: 0), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!)
        XCTAssertEqual(socialDistance.scoreByProximity(K.date("2020-09-24T00:00:00+0000")!, K.date("2020-09-24T01:00:00+0000")!), 1/60)

        // Too far away to count
        socialDistance.append(Encounter(Proximity(unit: .RSSI, value: -66), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:01:00+0000")!)!)
        XCTAssertEqual(socialDistance.scoreByProximity(K.date("2020-09-24T00:00:00+0000")!, K.date("2020-09-24T01:00:00+0000")!), 1/60)

        // Close enough to count but 0% contribution
        socialDistance.append(Encounter(Proximity(unit: .RSSI, value: -65), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:01:00+0000")!)!)
        XCTAssertEqual(socialDistance.scoreByProximity(K.date("2020-09-24T00:00:00+0000")!, K.date("2020-09-24T01:00:00+0000")!), 1/60)

        // Close enough to count at 100% contribution
        socialDistance.append(Encounter(Proximity(unit: .RSSI, value: 0), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:01:00+0000")!)!)
        XCTAssertEqual(socialDistance.scoreByProximity(K.date("2020-09-24T00:00:00+0000")!, K.date("2020-09-24T01:00:00+0000")!), 2/60)

    }

    func testScoreByTarget() {
        let socialDistance = SocialDistance()
//        XCTAssertEqual(socialDistance.scoreByTarget(K.date("2020-09-24T00:00:00+0000")!, K.date("2020-09-24T01:00:00+0000")!), 0)
        
        // Close enough to count
        socialDistance.append(Encounter(Proximity(unit: .RSSI, value: 0), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!)
        XCTAssertEqual(socialDistance.scoreByTarget(K.date("2020-09-24T00:00:00+0000")!, K.date("2020-09-24T01:00:00+0000")!), (1/6)/60)

        // Too far away to count
        socialDistance.append(Encounter(Proximity(unit: .RSSI, value: -66), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:01:00+0000")!)!)
        XCTAssertEqual(socialDistance.scoreByTarget(K.date("2020-09-24T00:00:00+0000")!, K.date("2020-09-24T01:00:00+0000")!), (1/6)/60)

        // Close enough to count
        socialDistance.append(Encounter(Proximity(unit: .RSSI, value: -65), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:01:00+0000")!)!)
        XCTAssertEqual(socialDistance.scoreByTarget(K.date("2020-09-24T00:00:00+0000")!, K.date("2020-09-24T01:00:00+0000")!), (2/6)/60)

        // Close enough to count but same device
        socialDistance.append(Encounter(Proximity(unit: .RSSI, value: -56), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:01:00+0000")!)!)
        XCTAssertEqual(socialDistance.scoreByTarget(K.date("2020-09-24T00:00:00+0000")!, K.date("2020-09-24T01:00:00+0000")!), (2/6)/60)

        // Close enough to count and new device
        socialDistance.append(Encounter(Proximity(unit: .RSSI, value: -56), PayloadData(repeating: 1, count: 1), timestamp: K.date("2020-09-24T00:01:00+0000")!)!)
        XCTAssertEqual(socialDistance.scoreByTarget(K.date("2020-09-24T00:00:00+0000")!, K.date("2020-09-24T01:00:00+0000")!), (3/6)/60)
    }
}
