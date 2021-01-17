//
//  Mobility.swift
//
//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

/// Estimate distance travelled without recording actual locations visited to produce mobility indicator for
/// prioritising work based on potential range of influence
public class Mobility: NSObject, SensorDelegate {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Analysis.Mobility")
    private let textFile: TextFile?
    private let dateFormatter = DateFormatter()
    private let queue: DispatchQueue
    private var events: [MobilityEvent] = []

    public override init() {
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        queue = DispatchQueue(label: "Sensor.Analysis.Mobility")
        textFile = nil
        super.init()
    }
    
    public init(filename: String, retention: TimeInterval = TimeInterval.fortnight) {
        textFile = TextFile(filename: filename)
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        queue = DispatchQueue(label: "Sensor.Analysis.Mobility(\(filename))")
        super.init()
        if textFile!.empty() {
            textFile!.write("time,distance")
        } else if let file = textFile!.url {
            do {
                try String(contentsOf: file).split(separator: "\n").forEach { line in
                    if let event = MobilityEvent(String(line)) {
                        events.append(event)
                    }
                }
                logger.debug("Loaded historic events (count=\(events.count))")
            } catch {
                logger.fault("Failed to read mobility log")
            }
        }
        // Remove data beyond data retention period
        remove(before: Date().addingTimeInterval(-retention))
    }
    
    public func append(_ event: MobilityEvent) {
        queue.sync {
            textFile?.write(event.csvString)
            events.append(event)
        }
    }
    
    /// Get records from start date (inclusive) to end date (exclusive)
    public func subdata(start: Date, end: Date) -> [MobilityEvent] {
        queue.sync {
            let subdata = events.filter({ $0.timestamp >= start && $0.timestamp < end })
            return subdata
        }
    }

    /// Get all encounters from start date (inclusive)
    public func subdata(start: Date) -> [MobilityEvent] {
        queue.sync {
            let subdata = events.filter({ $0.timestamp >= start })
            return subdata
        }
    }

    /// Remove all log records before date (exclusive). Use this function to implement data retention policy.
    public func remove(before: Date) {
        queue.sync {
            var content = "time,distance\n"
            let subdata = events.filter({ $0.timestamp >= before })
            subdata.forEach { event in
                content.append(event.csvString)
                content.append("\n")
            }
            textFile?.overwrite(content)
            events = subdata
        }
    }
    
    // MARK:- SensorDelegate
    
    public func sensor(_ sensor: SensorType, didVisit: Location?) {
        guard sensor == .MOBILITY else {
            return
        }
        guard let didVisit = didVisit, let locationReference = didVisit.value as? MobilityLocationReference else {
            return
        }
        let event = MobilityEvent(locationReference.distance, timestamp: didVisit.time.end)
        append(event)
    }
    
    // MARK:- Analysis functions
    
    /// Herald achieves > 93% continuity for 30 second windows, thus quantising encounter timestamps into 60 second
    /// windows will offer a reasonable estimate of the different number of devices within detection range over time. The
    /// result is a timeseries of different payloads acquired during each 60 second window, along with the proximity data
    /// for each payload.
    public func reduceByTime(_ events: [MobilityEvent], duration: TimeInterval = .day) -> [(time: Date, distance: Distance)] {
        var result: [(Date,Distance)] = []
        var currentTimeWindow = Date.distantPast
        var distance: Distance = 0
        let divisor = Int(duration)
        events.forEach { event in
            let timeWindow = Date(timeIntervalSince1970: TimeInterval(Int(event.timestamp.timeIntervalSince1970).dividedReportingOverflow(by: divisor).partialValue * divisor))
            if timeWindow != currentTimeWindow {
                if distance > 0 {
                    result.append((currentTimeWindow, distance))
                    distance = 0
                }
                currentTimeWindow = timeWindow
            }
            distance += event.distance
        }
        if distance > 0 {
            result.append((currentTimeWindow, distance))
        }
        return result
    }

}

/// Mobility record describing distance travelled
public class MobilityEvent {
    let timestamp: Date
    let distance: Distance
    var csvString: String { get {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let f0 = dateFormatter.string(from: timestamp)
        let f1 = String(distance)
        return "\(f0),\(f1)"
    }}
    
    /// Create encounter instance from source data
    init(_ distance: Distance, timestamp: Date = Date()) {
        self.timestamp = timestamp
        self.distance = distance
    }

    /// Create encounter instance from log entry
    init?(_ row: String) {
        let fields = row.split(separator: ",")
        guard fields.count >= 2 else {
            return nil
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let timestamp = dateFormatter.date(from: String(fields[0])) else {
            return nil
        }
        self.timestamp = timestamp
        guard let distance = Distance(String(fields[1])) else {
            return nil
        }
        self.distance = distance
    }
}
