//
//  CalibrationLog.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// CSV contact log for post event analysis and visualisation
class CalibrationLog: NSObject, SensorDelegate {
    private let textFile: TextFile
    private let dateFormatter = DateFormatter()
    
    init(filename: String) {
        textFile = TextFile(filename: filename)
        if textFile.empty() {
            textFile.write("time,payload,rssi,x,y,z")
        }
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    private func timestamp() -> String {
        let timestamp = dateFormatter.string(from: Date())
        return timestamp
    }
    
    private func csv(_ value: String) -> String {
        return TextFile.csv(value)
    }
    
    // MARK:- SensorDelegate
    
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData) {
        textFile.write(timestamp() + "," + csv(withPayload.shortName) + "," + csv(didMeasure.value.description) + ",,,")
    }
    
    func sensor(_ sensor: SensorType, didVisit: Location?) {
        guard let didVisit = didVisit, let reference = didVisit.value as? InertiaLocationReference else {
            return
        }
        let timestamp = dateFormatter.string(from: didVisit.time.start)
        textFile.write(timestamp + ",,," + reference.x.description + "," + reference.y.description + "," + reference.z.description)
    }
}
