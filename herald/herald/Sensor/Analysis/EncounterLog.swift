//
//  EncounterLog.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

/// CSV encounter log for recording contact time, rssi, and identity
class EncounterLog: NSObject, SensorDelegate {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Analysis.EncounterLog")
    private let textFile: TextFile
    private let dateFormatter = DateFormatter()
    private let queue: DispatchQueue
    private var encounters: [Encounter] = []

    init(filename: String) {
        textFile = TextFile(filename: filename)
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        queue = DispatchQueue(label: "Sensor.Analysis.EncounterLog(\(filename))")
        super.init()
        if textFile.empty() {
            textFile.write("time,proximity,unit,payload")
        } else if let file = textFile.url {
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
    
    private func append(_ encounter: Encounter) {
        queue.sync {
            textFile.write(encounter.csvString)
            encounters.append(encounter)
        }
    }
    
    /// Get encounters from start date (inclusive) to end date (exclusive)
    func subdata(start: Date, end: Date) -> [Encounter] {
        queue.sync {
            let subdata = encounters.filter({ $0.timestamp >= start && $0.timestamp < end })
            return subdata
        }
    }

    /// Get all encounters from start date (inclusive)
    func subdata(start: Date) -> [Encounter] {
        queue.sync {
            let subdata = encounters.filter({ $0.timestamp >= start })
            return subdata
        }
    }

    /// Remove all log records before date (exclusive)
    func remove(before: Date) {
        queue.sync {
            var content = String()
            let subdata = encounters.filter({ $0.timestamp >= before })
            subdata.forEach { encounter in
                content.append(encounter.csvString)
                content.append("\n")
            }
            textFile.overwrite(content)
            encounters = subdata
        }
    }
    
    // MARK:- SensorDelegate
    
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData) {
        guard let encounter = Encounter(didMeasure, withPayload) else {
            return
        }
        append(encounter)
    }
}
