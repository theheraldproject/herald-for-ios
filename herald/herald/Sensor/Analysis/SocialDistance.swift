//
//  SocialDistance.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

public class SocialDistance: SensorDelegate {
    private var targets: [TargetIdentifier:SocialDistanceTarget] = [:]
    
    // MARK:- SensorDelegate
    
    public func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        guard didMeasure.unit == .RSSI, didMeasure.value < 0, didMeasure.value > -100 else {
            return
        }
        guard let target = targets[fromTarget] else {
            targets[fromTarget] = SocialDistanceTarget(fromTarget, didMeasure.value)
            return
        }
        target.didMeasure(didMeasure.value)
    }
    
    // MARK:- Profiling
    
    /// Estimate measured power based on behaviour
    func measuredPower() -> Double {
        // Default value for iBeacons
        let defaultValue: Double = -56 // 1m
        let minimumValue: Double = -65 // 4m
        let maximumValue: Double = -28 // 50% of 1m
        // Assume at least 1% of people will always walk too close
        // to you where 0.45m as nearnest possible distance
        let passing = targets.values.filter({ $0.type == .passing })
        guard passing.count > 100 else {
            return defaultValue
        }
        guard let minimumPassingRSSI = passing.sorted(by: { $0.rssiDistribution.min! < $1.rssiDistribution.min! }).first?.rssiDistribution.min else {
            return defaultValue
        }
        // Use RSSI at minimum passing distance of 0.45m as basis for
        // estimating measured power or use bootstrap value if minimum
        // passing RSSI looks too low/high to be reliable
        let estimatedValue = SocialDistance.measuredPower(distance: 0.45, rssi: minimumPassingRSSI)
        guard estimatedValue > minimumValue, estimatedValue < maximumValue else {
            return defaultValue
        }
        return estimatedValue
    }
    
    private func stationaryTargets(_ start: Date, _ end: Date = Date()) {
        let stationary = targets.values.filter({ $0.type == .stationary && $0.lastSeenAt >= start && $0.lastSeenAt < end })
        let power = measuredPower()
        var exposure: [(target: SocialDistanceTarget, distance: Double)] = []
        stationary.forEach { target in
            let estimatedDistance = SocialDistance.distance(measuredPower: power, rssi: target.rssi)
            exposure.append((target, estimatedDistance))
        }
    }
    
    /// Calculate measured power given distance (metres), rssi and environmental factor
    private static func measuredPower(distance: Double, rssi: Double, environmentalFactor: Double = Double(2)) -> Double {
        return rssi + pow(distance, 0.1) * 10 * environmentalFactor
    }
    
    /// Calculate distance given measured power, rssi and environmental factor
    private static func distance(measuredPower: Double, rssi: Double, environmentalFactor: Double = Double(2)) -> Double {
        return pow(10, (measuredPower - rssi) / (10 * environmentalFactor))
    }
}

enum SocialDistanceTargetType {
    // People walking pass: short duration < 60 second, single sample or high variance
    case passing
    // People sitting or standing: long duration > 10 minutes, low variance
    case stationary
    // People moving around you: long duration > 10 minutes, high variance
    case orbiting
    // Unknown characteristics
    case unknown
}

class SocialDistanceTarget {
    let identifier: TargetIdentifier
    let rssiDistribution: Sample = Sample()
    var duration: TimeInterval = 1
    var firstSeenAt: Date = Date()
    var lastSeenAt: Date = Date()
    var rssi: Double
    var type: SocialDistanceTargetType { get {
        if duration < 60, (rssiDistribution.count == 1 || rssiDistribution.variance! > rssiDistribution.mean! * 0.3) {
            return .passing
        } else if duration > 10 * .minute, let mean = rssiDistribution.mean, let variance = rssiDistribution.variance {
            if variance < mean * 0.3 {
                return .stationary
            } else {
                return .orbiting
            }
        } else {
            return .unknown
        }
    }}
    
    init(_ identifier: TargetIdentifier, _ rssi: Double) {
        self.identifier = identifier
        self.rssi = rssi
        rssiDistribution.add(rssi)
    }
    
    func didMeasure(_ rssi: Double) {
        guard rssi < 0, rssi > -100 else {
            return
        }
        let now = Date()
        let elapsed = now.timeIntervalSince(lastSeenAt)
        lastSeenAt = now
        // Two encounters separated by > 30 seconds is assumed to be disjointed
        guard elapsed <= 30 else {
            duration = duration + 1
            rssiDistribution.add(rssi)
            self.rssi = rssi
            return
        }
        guard elapsed > 0 else {
            rssiDistribution.add(rssi)
            self.rssi = rssi
            return
        }
        // Two encounters within 30 seconds is assumed to be continuous
        // Interpolate rssi value for each second
        duration = duration + elapsed
        let rssiDeltaPerSecond = (rssi - self.rssi) / Double(Int(elapsed))
        for period in 1...Int(elapsed) {
            rssiDistribution.add(Double(period) * rssiDeltaPerSecond)
        }
        self.rssi = rssi
    }
    
    
}
