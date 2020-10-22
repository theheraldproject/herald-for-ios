//
//  Analysis.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

class Analysis {
    
    /// Histogram of exposure [RSSI:Windows], where RSSI is the minimum RSSI associated with each payload in a 30 second window,
    /// and duration is the number 30 second windows. This estimation scheme offers a rough count of different devices for each time
    /// window, while avoiding resolution of actual payload identity.
    func histogramOfExposure(_ encounters: [Encounter]) -> [Int:Int] {
        var histogram: [Int:Int] = [:]
        let windows = timeWindows(encounters.filter({ $0.proximity.unit == .RSSI }))
        windows.forEach { window in
            window.context.forEach { context in
                if let minRSSI = context.value.map({ Int($0.value) }).min() {
                    histogram[minRSSI] = (histogram[minRSSI] == nil ? 1 : histogram[minRSSI]! + 1)
                }
            }
        }
        return histogram
    }
    
    func analysis(_ encounters: [Encounter]) {
        let allTargets = targets(encounters)
        // People passing by tend to be the nearest acceptable distance as it is the hardest to avoid
        //
        let passingTargets = allTargets.filter({ $0.value.duration < .minute })
        let nearestAcceptableDistance = 
        passingTargets.values.map({ $0.proximity.min })

        
        // Co-location (duration for > 10 minutes, maximum is 15 minutes due to identity rotation)
        let coLocatedTargets = allTargets.filter({ $0.value.duration > (.minute * 10) })
        
        
        // Passing distance of people walking pass, encounter < 60s, high variance
    }

    // Get all targets, duration and proximity distribution
    func targets(_ encounters: [Encounter]) -> [PayloadData:(lastSeenAt: Date, duration: TimeInterval, proximity: Sample)] {
        var targets: [PayloadData:(lastSeenAt: Date, duration: TimeInterval, proximity: Sample)] = [:]
        encounters.filter({ $0.proximity.unit == .RSSI }).forEach { encounter in
            guard let (lastSeenAt, duration, proximity) = targets[encounter.payload] else {
                // One encounter is assumed to be at least 1 second minimum
                let proximity = Sample(encounter.proximity.value, 1)
                targets[encounter.payload] = (encounter.timestamp, 1, proximity)
                return
            }
            let elapsed = encounter.timestamp.timeIntervalSince(lastSeenAt)
            guard elapsed <= 30 else {
                // Two encounters separated by > 30 seconds is assumed to be disjointed
                targets[encounter.payload] = (encounter.timestamp, duration, proximity)
                return
            }
            // Two encounters within 30 seconds is assumed to be continuous
            // Proximity for every second of the most recent period of encounter
            // is assumed to be the most recent measurement
            proximity.add(encounter.proximity.value, Int(elapsed))
            targets[encounter.payload] = (encounter.timestamp, duration + elapsed, proximity)
        }
        return targets
    }
    
    
    
    /// Herald achieves > 93% continuity for 30 second windows, thus quantising encounter timestamps into 30 second
    /// windows will offer a reasonable estimate of the different number of devices within detection range over time
    private func timeWindows(_ encounters: [Encounter]) -> [(time: Date, context: [PayloadData:[Proximity]])] {
        var result: [(Date,[PayloadData:[Proximity]])] = []
        var currentTimeWindow = Date.distantPast
        var context: [PayloadData:[Proximity]] = [:]
        encounters.forEach { encounter in
            let timeWindow = Date(timeIntervalSince1970: TimeInterval(Int(encounter.timestamp.timeIntervalSince1970).dividedReportingOverflow(by: 30).partialValue * 30))
            if timeWindow != currentTimeWindow {
                if !context.isEmpty {
                    result.append((currentTimeWindow, context))
                    context = [:]
                }
                currentTimeWindow = timeWindow
            }
            if context[encounter.payload] == nil {
                context[encounter.payload] = []
            }
            context[encounter.payload]?.append(encounter.proximity)
        }
        if !context.isEmpty {
            result.append((time: currentTimeWindow, context: context))
        }
        return result
    }

}
