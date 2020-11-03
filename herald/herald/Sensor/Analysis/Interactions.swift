//
//  Interactions.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

/// Log of interactions for recording encounters (time, proximity, and identity).
/// This is can be used as basis for maintaining a persistent log
/// of encounters for on-device or centralised matching.
public class Interactions: NSObject, SensorDelegate {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Analysis.EncounterLog")
    private let textFile: TextFile?
    private let dateFormatter = DateFormatter()
    private let queue: DispatchQueue
    private var encounters: [Encounter] = []

    public override init() {
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        queue = DispatchQueue(label: "Sensor.Analysis.EncounterLog")
        textFile = nil
        super.init()
    }
    
    public init(filename: String) {
        textFile = TextFile(filename: filename)
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        queue = DispatchQueue(label: "Sensor.Analysis.EncounterLog(\(filename))")
        super.init()
        if textFile!.empty() {
            textFile!.write("time,proximity,unit,payload")
        } else if let file = textFile!.url {
            do {
                try String(contentsOf: file).split(separator: "\n").forEach { line in
                    if let encounter = Encounter(String(line)) {
                        encounters.append(encounter)
                    }
                }
                logger.debug("Loaded historic encounters (count=\(encounters.count))")
            } catch {
                logger.fault("Failed to read encounter log")
            }
        }
    }
    
    public func append(_ encounter: Encounter) {
        queue.sync {
            textFile?.write(encounter.csvString)
            encounters.append(encounter)
        }
    }
    
    /// Get encounters from start date (inclusive) to end date (exclusive)
    public func subdata(start: Date, end: Date) -> [Encounter] {
        queue.sync {
            let subdata = encounters.filter({ $0.timestamp >= start && $0.timestamp < end })
            return subdata
        }
    }

    /// Get all encounters from start date (inclusive)
    public func subdata(start: Date) -> [Encounter] {
        queue.sync {
            let subdata = encounters.filter({ $0.timestamp >= start })
            return subdata
        }
    }

    /// Remove all log records before date (exclusive). Use this function to implement data retention policy.
    public func remove(before: Date) {
        queue.sync {
            var content = String()
            let subdata = encounters.filter({ $0.timestamp >= before })
            subdata.forEach { encounter in
                content.append(encounter.csvString)
                content.append("\n")
            }
            textFile?.overwrite(content)
            encounters = subdata
        }
    }
    
    // MARK:- SensorDelegate
    
    public func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData) {
        guard let encounter = Encounter(didMeasure, withPayload) else {
            return
        }
        append(encounter)
    }
    
    // MARK:- Analysis functions
    
    /// Herald achieves > 93% continuity for 30 second windows, thus quantising encounter timestamps into 60 second
    /// windows will offer a reasonable estimate of the different number of devices within detection range over time. The
    /// result is a timeseries of different payloads acquired during each 60 second window, along with the proximity data
    /// for each payload.
    public func reduceByTime(_ encounters: [Encounter], duration: TimeInterval = 60) -> [(time: Date, context: [PayloadData:[Proximity]])] {
        var result: [(Date,[PayloadData:[Proximity]])] = []
        var currentTimeWindow = Date.distantPast
        var context: [PayloadData:[Proximity]] = [:]
        let divisor = Int(duration)
        encounters.forEach { encounter in
            let timeWindow = Date(timeIntervalSince1970: TimeInterval(Int(encounter.timestamp.timeIntervalSince1970).dividedReportingOverflow(by: divisor).partialValue * divisor))
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

    /// Get all target devices, duration and proximity distribution. The result is a table of payload data
    /// and summary information, including last seen at time, total duration of exposure, and distribution
    /// of proximity (RSSI) values.
    public func reduceByTarget(_ encounters: [Encounter]) -> [PayloadData:(lastSeenAt: Date, duration: TimeInterval, proximity: Sample)] {
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

    /// Histogram of exposure offers an esimate of exposure, while avoiding resolution of actual payload identity.
    public func reduceByProximity(_ encounters: [Encounter], unit: ProximityMeasurementUnit = .RSSI, bin: Double = 1) -> [Double:TimeInterval] {
        var targets: [PayloadData:Date] = [:]
        var histogram: [Double:TimeInterval] = [:]
        encounters.filter({ $0.proximity.unit == unit }).forEach { encounter in
            let value = round(encounter.proximity.value / bin) * bin
            guard let lastSeenAt = targets[encounter.payload] else {
                // One encounter is assumed to be at least 1 second minimum
                histogram[value] = TimeInterval(1) + (histogram[value] ?? 0)
                targets[encounter.payload] = encounter.timestamp
                return
            }
            let elapsed = encounter.timestamp.timeIntervalSince(lastSeenAt)
            guard elapsed <= 30 else {
                // Two encounters separated by > 30 seconds is assumed to be disjointed
                targets[encounter.payload] = encounter.timestamp
                return
            }
            // Two encounters within 30 seconds is assumed to be continuous
            // Proximity for every second of the most recent period of encounter
            // is assumed to be the most recent measurement
            histogram[value] = elapsed + (histogram[value] ?? 0)
            targets[encounter.payload] = encounter.timestamp
        }
        return histogram
    }
}

/// Encounter record describing proximity with target at a moment in time
public class Encounter {
    let timestamp: Date
    let proximity: Proximity
    let payload: PayloadData
    var csvString: String { get {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let f0 = dateFormatter.string(from: timestamp)
        let f1 = proximity.value.description
        let f2 = proximity.unit.rawValue
        let f3 = payload.base64EncodedString()
        return "\(f0),\(f1),\(f2),\(f3)"
    }}
    
    /// Create encounter instance from source data
    init?(_ didMeasure: Proximity, _ withPayload: PayloadData, timestamp: Date = Date()) {
        self.timestamp = timestamp
        self.proximity = didMeasure
        self.payload = withPayload
    }

    /// Create encounter instance from log entry
    init?(_ row: String) {
        let fields = row.split(separator: ",")
        guard fields.count >= 4 else {
            return nil
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let timestamp = dateFormatter.date(from: String(fields[0])) else {
            return nil
        }
        self.timestamp = timestamp
        guard let proximityValue = Double(String(fields[1])) else {
            return nil
        }
        guard let proximityUnit = ProximityMeasurementUnit.init(rawValue: String(fields[2])) else {
            return nil
        }
        self.proximity = Proximity(unit: proximityUnit, value: proximityValue);
        guard let payload = PayloadData(base64Encoded: String(fields[3])) else {
            return nil
        }
        self.payload = payload
    }   
}
