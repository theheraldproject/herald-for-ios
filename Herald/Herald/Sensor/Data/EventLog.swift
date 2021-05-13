//
//  EventLog.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: MIT
//

import Foundation

/// Generic event log with optional data retention enforcement functions
public class EventLog<T:Event>: NSObject, SensorDelegate {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Data.EventLog")
    private let textFile: TextFile?
    private let queue: DispatchQueue
    public var events: [T] = []

    public override init() {
        queue = DispatchQueue(label: "Sensor.Data.EventLog")
        textFile = nil
        super.init()
    }
    
    public init(filename: String) {
        textFile = TextFile(filename: filename)
        queue = DispatchQueue(label: "Sensor.Data.EventLog(\(filename))")
        super.init()
        if textFile!.empty() {
            textFile!.write(T.csvHeader)
        } else if let file = textFile!.url {
            do {
                try String(contentsOf: file).split(separator: "\n").forEach { line in
                    if let event = T(String(line)) {
                        events.append(event)
                    }
                }
                logger.debug("Loaded historic events (count=\(events.count))")
            } catch {
                logger.fault("Failed to read event log")
            }
        }
    }
    
    public func append(_ event: T) {
        logger.debug("append(\(event.csvString))")
        queue.sync {
            textFile?.write(event.csvString)
            events.append(event)
        }
    }
    
    /// Get records from start date (inclusive) to end date (exclusive)
    public func subdata(start: Date, end: Date) -> [T] {
        queue.sync {
            let subdata = events.filter({ $0.timestamp >= start && $0.timestamp < end })
            return subdata
        }
    }

    /// Get all encounters from start date (inclusive)
    public func subdata(start: Date) -> [T] {
        queue.sync {
            let subdata = events.filter({ $0.timestamp >= start })
            return subdata
        }
    }

    /// Remove all log records before date (exclusive). Use this function to implement data retention policy.
    public func remove(before: Date) {
        queue.sync {
            var content = "\(T.csvHeader)\n"
            let subdata = events.filter({ $0.timestamp >= before })
            subdata.forEach { event in
                content.append(event.csvString)
                content.append("\n")
            }
            textFile?.overwrite(content)
            events = subdata
        }
    }
    
    /// Remove all log records before retention period.
    public func removeBefore(retention: TimeInterval) {
        remove(before: Date().addingTimeInterval(-retention))
    }
        
    // MARK:- Analysis functions
    
    /// Get events in time windows
    public func reduce(into timeWindow: TimeInterval) -> [(time: Date, events: [T])] {
        var result: [(Date,[T])] = []
        var currentTimeWindow = Date.distantPast
        var eventsInTimeWindow: [T] = []
        let divisor = Int(timeWindow)
        events.forEach { event in
            let timeWindow = Date(timeIntervalSince1970: TimeInterval(Int(event.timestamp.timeIntervalSince1970).dividedReportingOverflow(by: divisor).partialValue * divisor))
            if timeWindow != currentTimeWindow {
                if !eventsInTimeWindow.isEmpty {
                    result.append((currentTimeWindow, eventsInTimeWindow))
                    eventsInTimeWindow = []
                }
                currentTimeWindow = timeWindow
            }
            eventsInTimeWindow.append(event)
        }
        if !eventsInTimeWindow.isEmpty {
            result.append((currentTimeWindow, eventsInTimeWindow))
        }
        return result
    }
    
    // MARK:- SensorDelegate
    
    public func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {}
    public func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {}
    public func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {}
    public func sensor(_ sensor: SensorType, didReceive: Data, fromTarget: TargetIdentifier) {}
    public func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {}
    public func sensor(_ sensor: SensorType, didVisit: Location?) {}
    public func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData) {}
    public func sensor(_ sensor: SensorType, didUpdateState: SensorState) {}
}

/// Event for logging
public protocol Event {
    var timestamp: Date { get }
    /// Get CSV header for event data including timestamp
    static var csvHeader: String { get }
    /// Get CSV representation of event data including timestamp
    var csvString: String { get }
    /// Parse CSV representation of event data to recreate event
    init?(_ csvString: String)
}
