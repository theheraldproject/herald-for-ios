//
//  Mobility.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: MIT
//

import Foundation

/// Estimate distance travelled without recording actual locations visited to produce mobility indicator for
/// prioritising work based on potential range of influence
public class Mobility: EventLog<MobilityEvent> {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Analysis.Mobility")
    
    // MARK:- SensorDelegate
    
    public override func sensor(_ sensor: SensorType, didVisit: Location?) {
        guard sensor == .MOBILITY else {
            return
        }
        guard let didVisit = didVisit, let locationReference = didVisit.value as? MobilityLocationReference else {
            return
        }
        let event = MobilityEvent(locationReference.distance, timestamp: didVisit.time.end)
        logger.debug("didVisit(event=\(event))")
        append(event)
    }
    
    // MARK:- Analysis functions
    
    public func reduce(into timeWindow: TimeInterval) -> [(time: Date, distance: Distance)] {
        let timeWindows = super.reduce(into: timeWindow)
        return timeWindows.map({ ($0.time, $0.events.reduce(into: Distance(0), { total, event in total.value += event.distance.value })) })
    }
}

/// Mobility record describing distance travelled
public class MobilityEvent: Event {
    public static var csvHeader: String = "time,distance"
    public let timestamp: Date
    public let distance: Distance
    public var csvString: String { get {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let f0 = dateFormatter.string(from: timestamp)
        let f1 = String(round(distance.value))
        return "\(f0),\(f1)"
    }}
    
    /// Create encounter instance from source data
    public init(_ distance: Distance, timestamp: Date = Date()) {
        self.timestamp = timestamp
        self.distance = distance
    }

    /// Create encounter instance from log entry
    required public init?(_ csvString: String) {
        let fields = csvString.split(separator: ",")
        guard fields.count >= 2 else {
            return nil
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let timestamp = dateFormatter.date(from: String(fields[0])) else {
            return nil
        }
        self.timestamp = timestamp
        guard let value = Double(String(fields[1])) else {
            return nil
        }
        self.distance = Distance(value)
    }
}
