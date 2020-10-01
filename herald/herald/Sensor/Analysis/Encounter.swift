////
//  Encounter.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

/// Encounter record describing proximity with target at a moment in time
class Encounter {
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
    
    init?(_ didMeasure: Proximity, _ withPayload: PayloadData, timestamp: Date = Date()) {
        self.timestamp = timestamp
        self.proximity = didMeasure
        self.payload = withPayload
    }

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
