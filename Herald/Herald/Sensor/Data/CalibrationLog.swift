//
//  CalibrationLog.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// CSV contact log for post event analysis and visualisation
class CalibrationLog: SensorDelegateLogger {
    
    public override init(filename: String) {
        super.init(filename: filename)
    }
    
    private func writeHeader() {
        if empty() {
            write("time,payload,rssi,x,y,z")
        }
    }
    
    // MARK:- SensorDelegate
    
    override func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData) {
        writeHeader()
        write(timestamp() + "," + csv(withPayload.shortName) + "," + csv(didMeasure.value.description) + ",,,")
    }
    
    override func sensor(_ sensor: SensorType, didVisit: Location?) {
        guard let didVisit = didVisit, let reference = didVisit.value as? InertiaLocationReference else {
            return
        }
        let timestamp = dateFormatter.string(from: didVisit.time.start)
        writeHeader()
        write(timestamp + ",,," + reference.x.description + "," + reference.y.description + "," + reference.z.description)
    }
}
