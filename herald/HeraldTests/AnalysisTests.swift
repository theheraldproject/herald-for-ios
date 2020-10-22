//
//  AnalysisTests.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

import XCTest
@testable import Herald

class AnalysisTests: XCTestCase {
    
    func testTargets() {
        let analysis = Analysis()
        
        var encounters: [Encounter] = []
        
        XCTAssertEqual(analysis.targets(encounters).count, 0)
        
        let pd1 = PayloadData(repeating: 0, count: 1)
        let pd2 = PayloadData(repeating: 1, count: 1)

        // Single encounter of pd1 at RSSI=1
        encounters.append(Encounter(Proximity(unit: .RSSI, value: 1), pd1, timestamp: K.date("2020-09-24T00:00:00+0000")!)!)
        XCTAssertEqual(analysis.targets(encounters).count, 1)
        XCTAssertEqual(analysis.targets(encounters)[pd1]?.duration, 1)
        XCTAssertEqual(analysis.targets(encounters)[pd1]?.proximity.mean, 1) // 1 / 1

        // Encounter pd1 again 4 seconds later
        encounters.append(Encounter(Proximity(unit: .RSSI, value: 1), pd1, timestamp: K.date("2020-09-24T00:00:04+0000")!)!)
        XCTAssertEqual(analysis.targets(encounters).count, 1)
        XCTAssertEqual(analysis.targets(encounters)[pd1]?.duration, 5)
        XCTAssertEqual(analysis.targets(encounters)[pd1]?.proximity.mean, 1) // (1 + 4) / (1 + 4)

        // Encounter pd1 again 5 seconds later
        encounters.append(Encounter(Proximity(unit: .RSSI, value: 3), pd1, timestamp: K.date("2020-09-24T00:00:09+0000")!)!)
        XCTAssertEqual(analysis.targets(encounters).count, 1)
        XCTAssertEqual(analysis.targets(encounters)[pd1]?.duration, 10)
        XCTAssertEqual(analysis.targets(encounters)[pd1]?.proximity.mean, 2) // (1 + 4 + (5 * 3)) / (1 + 4 + 5)

        // Encounter pd1 again 31 seconds later, new encounter, so no change
        encounters.append(Encounter(Proximity(unit: .RSSI, value: 2), pd1, timestamp: K.date("2020-09-24T00:00:40+0000")!)!)
        XCTAssertEqual(analysis.targets(encounters).count, 1)
        XCTAssertEqual(analysis.targets(encounters)[pd1]?.duration, 10)
        XCTAssertEqual(analysis.targets(encounters)[pd1]?.proximity.mean, 2) // (1 + 4 + (5 * 3)) / (1 + 4 + 5)

        // Encounter pd1 again 10 seconds later
        encounters.append(Encounter(Proximity(unit: .RSSI, value: 4), pd1, timestamp: K.date("2020-09-24T00:00:50+0000")!)!)
        XCTAssertEqual(analysis.targets(encounters).count, 1)
        XCTAssertEqual(analysis.targets(encounters)[pd1]?.duration, 20)
        XCTAssertEqual(analysis.targets(encounters)[pd1]?.proximity.mean, 3) // (1 + 4 + (5 * 3) + (10 * 4)) / (1 + 4 + 5 + 10)

        // Encounter pd2 for the first time
        encounters.append(Encounter(Proximity(unit: .RSSI, value: 5), pd2, timestamp: K.date("2020-09-24T00:01:00+0000")!)!)
        XCTAssertEqual(analysis.targets(encounters).count, 2)
        XCTAssertEqual(analysis.targets(encounters)[pd2]?.duration, 1)
        XCTAssertEqual(analysis.targets(encounters)[pd2]?.proximity.mean, 5)
    }
    
    func testHistogramOfExposure() {
        let analysis = Analysis()
        
        XCTAssertEqual(analysis.histogramOfExposure([]).count, 0)
        
        // One encounter at RSSI=1 with one device within one time window -> [1:1]
        let encounters1 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!
        ]
        XCTAssertEqual(analysis.histogramOfExposure(encounters1).count, 1)
        XCTAssertEqual(analysis.histogramOfExposure(encounters1)[1], 1)
        
        // Two encounters at RSSI=1,2 with one device within one time window -> [1:1]
        let encounters2 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!,
            Encounter(Proximity(unit: .RSSI, value: 2), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:01+0000")!)!
        ]
        XCTAssertEqual(analysis.histogramOfExposure(encounters2).count, 1)
        XCTAssertEqual(analysis.histogramOfExposure(encounters2)[1], 1)

        // Two encounters at RSSI=1,1 with one device in two time windows -> [1:2]
        let encounters3 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!,
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:30:00+0000")!)!
        ]
        XCTAssertEqual(analysis.histogramOfExposure(encounters3).count, 1)
        XCTAssertEqual(analysis.histogramOfExposure(encounters3)[1], 2)

        // Two encounters at RSSI=1,2 with one device in two time windows -> [1:1,2:1]
        let encounters4 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!,
            Encounter(Proximity(unit: .RSSI, value: 2), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:30:00+0000")!)!
        ]
        XCTAssertEqual(analysis.histogramOfExposure(encounters4).count, 2)
        XCTAssertEqual(analysis.histogramOfExposure(encounters4)[1], 1)
        XCTAssertEqual(analysis.histogramOfExposure(encounters4)[2], 1)

        // Two encounters at RSSI=1,1 with two devices in one time window -> [1:2]
        let encounters5 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!,
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 1, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!
        ]
        XCTAssertEqual(analysis.histogramOfExposure(encounters5).count, 1)
        XCTAssertEqual(analysis.histogramOfExposure(encounters5)[1], 2)

        // Two encounters at RSSI=1,2 with two devices in one time windows -> [1:1,2:1]
        let encounters6 = [
            Encounter(Proximity(unit: .RSSI, value: 1), PayloadData(repeating: 0, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!,
            Encounter(Proximity(unit: .RSSI, value: 2), PayloadData(repeating: 1, count: 1), timestamp: K.date("2020-09-24T00:00:00+0000")!)!
        ]
        XCTAssertEqual(analysis.histogramOfExposure(encounters6).count, 2)
        XCTAssertEqual(analysis.histogramOfExposure(encounters6)[1], 1)
        XCTAssertEqual(analysis.histogramOfExposure(encounters6)[2], 1)
    }
}
