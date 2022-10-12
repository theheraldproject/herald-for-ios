//
//  ContactLog.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// CSV contact log for post event analysis and visualisation
public class ContactLog: SensorDelegateLogger {
    private let payloadDataFormatter: PayloadDataFormatter

    public init(filename: String, payloadDataFormatter: PayloadDataFormatter = ConcretePayloadDataFormatter()) {
        self.payloadDataFormatter = payloadDataFormatter
        super.init(filename: filename)
    }
    
    private func writeHeader() {
        if empty() {
            write("time,sensor,id,detect,read,measure,share,visit,detectHerald,delete,data")
        }
    }
    
    // MARK:- SensorDelegate
    
    public override func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
        writeHeader()
        write(timestamp() + "," + sensor.rawValue + "," + csv(didDetect) + ",1,,,,,,,")
    }
    
    public override func sensor(_ sensor: SensorType, available: Bool, didDeleteOrDetect: TargetIdentifier) {
        writeHeader()
        if (available) {
            // Guaranteed to be a Herald payload capable device
            write(timestamp() + "," + sensor.rawValue + "," + csv(didDeleteOrDetect) + ",,,,,,6,,")
        } else {
            // Any Bluetooth device (including Herald) that has not been seen in some time
            write(timestamp() + "," + sensor.rawValue + "," + csv(didDeleteOrDetect) + ",,,,,,,7,")
        }
    }
    
    public override func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        writeHeader()
        write(timestamp() + "," + sensor.rawValue + "," + csv(fromTarget) + ",,2,,,,,," + csv(payloadDataFormatter.shortFormat(didRead)))
    }
    
    public override func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        writeHeader()
        write(timestamp() + "," + sensor.rawValue + "," + csv(fromTarget) + ",,,3,,,,," + csv(didMeasure.description))
    }
    
    public override func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
        let prefix = timestamp() + "," + sensor.rawValue + "," + csv(fromTarget)
        didShare.forEach() { payloadData in
            writeHeader()
            write(prefix + ",,,,4,,,," + csv(payloadDataFormatter.shortFormat(payloadData)))
        }
    }
    
    public override func sensor(_ sensor: SensorType, didVisit: Location?) {
        var visitString = ""
        if let dv = didVisit {
            visitString = dv.description
        }
        writeHeader()
        write(timestamp() + "," + sensor.rawValue + ",,,,,,5,,," + csv(visitString))
    }
}
