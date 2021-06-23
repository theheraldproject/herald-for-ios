//
//  AnalysisTests.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

import XCTest
@testable import Herald

class InteractionsTests: XCTestCase {
    
    func testReduceByTarget() {
        let interactions = Interactions()
        var encounters: [Encounter] = []
        XCTAssertEqual(interactions.reduceByTarget(encounters).count, 0)
        
        let pd1 = PayloadData(repeating: 0, count: 1)
        let pd2 = PayloadData(repeating: 1, count: 1)

        // Single encounter of pd1 at RSSI=1
        encounters.append(Encounter(Proximity(unit: .RSSI, value: 1), pd1, timestamp: K.date("2020-09-24T00:00:00+0000")!)!)
        XCTAssertEqual(interactions.reduceByTarget(encounters).count, 1)
        XCTAssertEqual(interactions.reduceByTarget(encounters)[pd1]?.duration, 1)
        XCTAssertEqual(interactions.reduceByTarget(encounters)[pd1]?.proximity.mean, 1) // 1 / 1

        // Encounter pd1 again 4 seconds later
        encounters.append(Encounter(Proximity(unit: .RSSI, value: 1), pd1, timestamp: K.date("2020-09-24T00:00:04+0000")!)!)
        XCTAssertEqual(interactions.reduceByTarget(encounters).count, 1)
        XCTAssertEqual(interactions.reduceByTarget(encounters)[pd1]?.duration, 5)
        XCTAssertEqual(interactions.reduceByTarget(encounters)[pd1]?.proximity.mean, 1) // (1 + 4) / (1 + 4)

        // Encounter pd1 again 5 seconds later
        encounters.append(Encounter(Proximity(unit: .RSSI, value: 3), pd1, timestamp: K.date("2020-09-24T00:00:09+0000")!)!)
        XCTAssertEqual(interactions.reduceByTarget(encounters).count, 1)
        XCTAssertEqual(interactions.reduceByTarget(encounters)[pd1]?.duration, 10)
        XCTAssertEqual(interactions.reduceByTarget(encounters)[pd1]?.proximity.mean, 2) // (1 + 4 + (5 * 3)) / (1 + 4 + 5)

        // Encounter pd1 again 31 seconds later, new encounter, so no change
        encounters.append(Encounter(Proximity(unit: .RSSI, value: 2), pd1, timestamp: K.date("2020-09-24T00:00:40+0000")!)!)
        XCTAssertEqual(interactions.reduceByTarget(encounters).count, 1)
        XCTAssertEqual(interactions.reduceByTarget(encounters)[pd1]?.duration, 10)
        XCTAssertEqual(interactions.reduceByTarget(encounters)[pd1]?.proximity.mean, 2) // (1 + 4 + (5 * 3)) / (1 + 4 + 5)

        // Encounter pd1 again 10 seconds later
        encounters.append(Encounter(Proximity(unit: .RSSI, value: 4), pd1, timestamp: K.date("2020-09-24T00:00:50+0000")!)!)
        XCTAssertEqual(interactions.reduceByTarget(encounters).count, 1)
        XCTAssertEqual(interactions.reduceByTarget(encounters)[pd1]?.duration, 20)
        XCTAssertEqual(interactions.reduceByTarget(encounters)[pd1]?.proximity.mean, 3) // (1 + 4 + (5 * 3) + (10 * 4)) / (1 + 4 + 5 + 10)

        // Encounter pd2 for the first time
        encounters.append(Encounter(Proximity(unit: .RSSI, value: 5), pd2, timestamp: K.date("2020-09-24T00:01:00+0000")!)!)
        XCTAssertEqual(interactions.reduceByTarget(encounters).count, 2)
        XCTAssertEqual(interactions.reduceByTarget(encounters)[pd2]?.duration, 1)
        XCTAssertEqual(interactions.reduceByTarget(encounters)[pd2]?.proximity.mean, 5)
    }
    
    func testReduceByProximity() {
        let interactions = Interactions()
        
        XCTAssertEqual(interactions.reduceByProximity([]).count, 0)
        
        // One encounter at RSSI=1 with one device -> [1:1]
        let encounters1 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!
        ]
        XCTAssertEqual(interactions.reduceByProximity(encounters1).count, 1)
        XCTAssertEqual(interactions.reduceByProximity(encounters1)[1], 1.0)
        
        // Two encounters at RSSI=1,2 with one device -> [1:1,2:1]
        let encounters2 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!,
            Encounter(Proximity(unit: .RSSI, value: 2), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:01+0000")!)!
        ]
        XCTAssertEqual(interactions.reduceByProximity(encounters2).count, 2)
        XCTAssertEqual(interactions.reduceByProximity(encounters2)[1], 1.0)
        XCTAssertEqual(interactions.reduceByProximity(encounters2)[2], 1.0)

        // Two encounters at RSSI=1,1 with one device -> [1:30]
        let encounters3 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!,
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:30+0000")!)!
        ]
        XCTAssertEqual(interactions.reduceByProximity(encounters3).count, 1)
        XCTAssertEqual(interactions.reduceByProximity(encounters3)[1], 31.0)

        // Two encounters at RSSI=1,2 with one device -> [1:1,2:30]
        let encounters4 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!,
            Encounter(Proximity(unit: .RSSI, value: 2), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:30+0000")!)!
        ]
        XCTAssertEqual(interactions.reduceByProximity(encounters4).count, 2)
        XCTAssertEqual(interactions.reduceByProximity(encounters4)[1], 1.0)
        XCTAssertEqual(interactions.reduceByProximity(encounters4)[2], 30.0)

        // Two encounters at RSSI=1,1 with two devices -> [1:2]
        let encounters5 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!,
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 1, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!
        ]
        XCTAssertEqual(interactions.reduceByProximity(encounters5).count, 1)
        XCTAssertEqual(interactions.reduceByProximity(encounters5)[1], 2.0)

        // Two encounters at RSSI=1,2 with two devices -> [1:1,2:1]
        let encounters6 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!,
            Encounter(Proximity(unit: .RSSI, value: 2), PayloadData(repeating: 1, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!
        ]
        XCTAssertEqual(interactions.reduceByProximity(encounters6).count, 2)
        XCTAssertEqual(interactions.reduceByProximity(encounters6)[1], 1.0)
        XCTAssertEqual(interactions.reduceByProximity(encounters6)[2], 1.0)
    }

    func testReduceByTime() {
        let interactions = Interactions()
        
        XCTAssertEqual(interactions.reduceByTime([]).count, 0)
        
        // One encounter at RSSI=1 with one device -> [(2020-09-24T00:00:00+0000,[0:[1]])]
        let encounters1 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!
        ]
        XCTAssertEqual(interactions.reduceByTime(encounters1).count, 1)
        XCTAssertEqual(interactions.reduceByTime(encounters1)[0].context.values.first?.count, 1)
        XCTAssertEqual(interactions.reduceByTime(encounters1)[0].context.values.first?.first?.value, 1.0)
        
        // Two encounters at RSSI=1,2 with one device -> [(2020-09-24T00:00:00+0000,[0:[1,2]])]
        let encounters2 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!,
            Encounter(Proximity(unit: .RSSI, value: 2), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:01+0000")!)!
        ]
        XCTAssertEqual(interactions.reduceByTime(encounters2).count, 1)
        XCTAssertEqual(interactions.reduceByTime(encounters2)[0].context.values.first?.count, 2)
        print(interactions.reduceByTime(encounters2))

        // Two encounters at RSSI=1,1 with one device -> [(2020-09-24T00:00:00+0000,[0:[1,1]])]
        let encounters3 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!,
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:30+0000")!)!
        ]
        XCTAssertEqual(interactions.reduceByTime(encounters3).count, 1)
        XCTAssertEqual(interactions.reduceByTime(encounters3)[0].context.values.first?.count, 2)

        // Two encounters at RSSI=1,2 with one device -> [(2020-09-24T00:00:00+0000,[0:[1,2]])]
        let encounters4 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!,
            Encounter(Proximity(unit: .RSSI, value: 2), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:30+0000")!)!
        ]
        XCTAssertEqual(interactions.reduceByTime(encounters4).count, 1)
        XCTAssertEqual(interactions.reduceByTime(encounters4)[0].context.values.first?.count, 2)

        // Two encounters at RSSI=1,1 with two devices -> [(2020-09-24T00:00:00+0000,[0:[1],1:[1]])]
        let encounters5 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!,
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 1, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!
        ]
        XCTAssertEqual(interactions.reduceByTime(encounters5).count, 1)
        XCTAssertEqual(interactions.reduceByTime(encounters5)[0].context.count, 2)
        XCTAssertEqual(interactions.reduceByTime(encounters5)[0].context.values.first?.count, 1)

        // Two encounters at RSSI=1,1 with one device -> [(2020-09-24T00:00:00+0000,[0:[1]]),(2020-09-24T00:01:00+0000,[0:[1]])]
        let encounters6 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!,
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:01:15+0000")!)!
        ]
        XCTAssertEqual(interactions.reduceByTime(encounters6).count, 2)
        XCTAssertEqual(interactions.reduceByTime(encounters6)[0].context.count, 1)
        XCTAssertEqual(interactions.reduceByTime(encounters6)[1].context.count, 1)
    }
}
