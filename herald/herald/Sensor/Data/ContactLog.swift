//
//  ContactLog.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// CSV contact log for post event analysis and visualisation
public class ContactLog: NSObject, SensorDelegate {
    private let textFile: TextFile
    private let dateFormatter = DateFormatter()
    private let payloadDataFormatter: PayloadDataFormatter

    public init(filename: String, payloadDataFormatter: PayloadDataFormatter = ConcretePayloadDataFormatter()) {
        textFile = TextFile(filename: filename)
        if textFile.empty() {
            textFile.write("time,sensor,id,detect,read,measure,share,visit,data")
        }
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        self.payloadDataFormatter = payloadDataFormatter
    }
    
    private func timestamp() -> String {
        let timestamp = dateFormatter.string(from: Date())
        return timestamp
    }
    
    private func csv(_ value: String) -> String {
        return TextFile.csv(value)
    }
    
    // MARK:- SensorDelegate
    
    public func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
        textFile.write(timestamp() + "," + sensor.rawValue + "," + csv(didDetect) + ",1,,,,,")
    }
    
    public func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        textFile.write(timestamp() + "," + sensor.rawValue + "," + csv(fromTarget) + ",,2,,,," + csv(payloadDataFormatter.shortFormat(didRead)))
    }
    
    public func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        textFile.write(timestamp() + "," + sensor.rawValue + "," + csv(fromTarget) + ",,,3,,," + csv(didMeasure.description))
    }
    
    public func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
        let prefix = timestamp() + "," + sensor.rawValue + "," + csv(fromTarget)
        didShare.forEach() { payloadData in
            textFile.write(prefix + ",,,,4,," + csv(payloadDataFormatter.shortFormat(payloadData)))
        }
    }
    
    public func sensor(_ sensor: SensorType, didVisit: Location?) {
        var visitString = ""
        if let dv = didVisit {
            visitString = dv.description
        }
        textFile.write(timestamp() + "," + sensor.rawValue + ",,,,,,5," + csv(visitString))
    }
}
