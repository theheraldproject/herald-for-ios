//
//  SocialDistance.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

/// Estimate social distance to other app users.
public class SocialDistance: SensorDelegate {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Analysis.SocialDistance")
    // Database of targets and distribution of RSSI measurements
    private var targets: [TargetIdentifier:SocialDistanceTarget] = [:]
    
    // MARK:- SensorDelegate
    
    public func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        // Use RSSI [-100,0] as data source
        guard didMeasure.unit == .RSSI, didMeasure.value >= -100, didMeasure.value <= 0 else {
            return
        }
        // Collate RSSI measurements for each target
        guard let target = targets[fromTarget] else {
            logger.debug("didMeasure(rssi=\(didMeasure.value),fromTarget=\(fromTarget))")
            targets[fromTarget] = SocialDistanceTarget(fromTarget, didMeasure.value)
            return
        }
        logger.debug("didMeasure(rssi=\(didMeasure.value),fromTarget=\(fromTarget))")
        target.didMeasure(didMeasure.value)
    }
    
    // MARK:- Profiling
    
    /// Calibrate measured power by behaviour
    func calibrateByBehaviour() -> (distance: Distance, rssi: RSSI)? {
        // Assume at least 5% of people will always walk too close
        // to you where 0.45m as nearnest possible distance
        let passing = targets.values.filter({ $0.type == .passing })
        let samples = Int(round(Double(passing.count) * 0.05))
        guard samples >= 1 else {
            return nil
        }
        let rssiValues = passing.filter({ $0.rssiDistribution.max != nil }).map({ $0.rssiDistribution.max! }).sorted(by: { $0 > $1 }).prefix(samples)
        var rssiSum: Double = 0
        for rssiValue in rssiValues {
            rssiSum = rssiSum + rssiValue
        }
        let rssi = rssiSum / Double(samples)
        return (Distance(0.45), RSSI(rssi))
    }
    
    /// Estimate measured power based on behaviour to avoid phone model specific calibration
    func measuredPower() -> MeasuredPower {
        // Default value for iBeacons
        let defaultValue: Double = -56 // 1m
        let minimumValue: Double = -65 // 4m
        let maximumValue: Double = -28 // 50% of 1m
        // Calibration
        guard let calibration = calibrateByBehaviour() else {
            return defaultValue
        }
        // Estimate measured power or use bootstrap value if minimum
        // passing RSSI looks too low/high to be reliable
        let estimatedValue = SocialDistance.measuredPower(distance: calibration.distance, rssi: calibration.rssi)
        guard estimatedValue >= minimumValue, estimatedValue <= maximumValue else {
            return defaultValue
        }
        return estimatedValue
    }
    
    /// Calculate mean distance and total duration of exposure for a set of targets over a time period
    func exposure(type: SocialDistanceTargetType, _ start: Date, _ end: Date = Date()) -> (distance: Distance, duration: TimeInterval) {
        let filteredTargets = targets.values.filter({ $0.type == type && $0.lastSeenAt >= start && $0.lastSeenAt < end })
        let rssi = Sample()
        var duration: TimeInterval = 0
        filteredTargets.forEach() { target in
            rssi.add(target.rssiDistribution)
            duration = duration + target.duration
        }
        let distance = SocialDistance.distance(measuredPower: measuredPower(), rssi: (rssi.mean ?? -100))
        return (distance: distance, duration: duration)
    }
    
    /// Calculate measured power given distance (metres), rssi and environmental factor
    static func measuredPower(distance: Distance, rssi: RSSI, environmentalFactor: Double = Double(2)) -> MeasuredPower {
        return MeasuredPower(rssi + log10(distance) * 10 * environmentalFactor)
    }
    
    /// Calculate distance given measured power, rssi and environmental factor
    static func distance(measuredPower: MeasuredPower, rssi: RSSI, environmentalFactor: Double = Double(2)) -> Distance {
        return Distance(pow(10, (measuredPower - rssi) / (10 * environmentalFactor)))
    }
    
    /// Calculate RSSI given distance, measured power and environmental factor
    static func rssi(distance: Distance, measuredPower: MeasuredPower, environmentalFactor: Double = Double(2)) -> RSSI {
        return measuredPower - log10(distance) * 10 * environmentalFactor
    }
}

/// RSSI as decimal value
typealias RSSI = Double

/// Measured power at 1 metre
typealias MeasuredPower = Double

/// Distance in metres
typealias Distance = Double

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
        guard elapsed >= 1 else {
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
