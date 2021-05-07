//
//  SocialDistance.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Estimate social distance to other app users to encourage people to keep their distance from
/// people. This is intended to be used to generate a daily score as indicator of behavioural change
/// to improve awareness of social mixing behaviour.
public class SocialDistance: Interactions {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Analysis.SocialDistance")
        
    /// Calculate social distance score based on maximum RSSI per 1 minute time window over duration
    /// A score of 1.0 means RSSI >= measuredPower in every minute, score of 0.0 means no encounter
    /// or RSSI less than excludeRssiBelow in every minute.
    /// - measuredPower defines RSSI at 1 metre
    /// - excludeRssiBelow defines minimum RSSI to include in analysis
    public func scoreByProximity(_ start: Date, _ end: Date = Date(), measuredPower: Double = -32, excludeRssiBelow: Double = -65) -> Double {
        // Get encounters over time period
        let encounters = subdata(start: start, end: end)
        // Get number of minutes in time period
        let duration = ceil(end.timeIntervalSince(start) / 60)
        // Get interactions for each time windows over time period
        let timeWindows = reduceByTime(encounters, duration: 60)
        // Get sum of exposure in each time window
        let rssiRange = measuredPower - excludeRssiBelow
        var totalScore = 0.0
        timeWindows.forEach() { timeWindow in
            var maxRSSI: Double?
            timeWindow.context.values.forEach() { proximities in
                proximities.forEach() { proximity in
                    guard proximity.unit == .RSSI, proximity.value >= excludeRssiBelow, proximity.value <= 0 else {
                        return
                    }
                    maxRSSI = max(proximity.value, maxRSSI ?? proximity.value)
                }
            }
            guard let rssi = maxRSSI else {
                return
            }
            let rssiDelta = measuredPower - min(rssi, measuredPower)
            let rssiPercentage = 1.0 - (rssiDelta / rssiRange)
            totalScore = totalScore + rssiPercentage
        }
        // Score for time period is totalScore / duration
        let score = totalScore / duration
        return score
    }

    /// Calculate social distance score based on number of different devices per 1 minute time window over duration
    /// A score of 1.0 means 6 or more in every minute, score of 0.0 means no device in every minute.
    public func scoreByTarget(_ start: Date, _ end: Date = Date(), maximumDeviceCount: Int = 6, excludeRssiBelow: Double = -65) -> Double {
        // Get encounters over time period
        let encounters = subdata(start: start, end: end)
        // Get number of minutes in time period
        let duration = ceil(end.timeIntervalSince(start) / 60)
        // Get interactions for each time windows over time period
        let timeWindows = reduceByTime(encounters, duration: 60)
        // Get sum of exposure in each time window
        var totalScore = 0.0
        timeWindows.forEach() { timeWindow in
            var devices = 0
            timeWindow.context.values.forEach() { proximities in
                if proximities.filter({ $0.unit == .RSSI && $0.value >= excludeRssiBelow && $0.value <= 0 }).count > 0 {
                    devices = devices + 1
                }
            }
            let devicesPercentage = (Double(min(devices, maximumDeviceCount)) / Double(maximumDeviceCount))
            totalScore = totalScore + devicesPercentage
        }
        // Score for time period is totalScore / duration
        let score = totalScore / duration
        return score
     }
}
