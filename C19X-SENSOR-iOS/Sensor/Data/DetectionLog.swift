//
//  DetectionLog.swift
//  
//
//  Created  on 04/08/2020.
//  Copyright © 2020 . All rights reserved.
//

import Foundation
import UIKit

/// CSV contact log for post event analysis and visualisation
class DetectionLog: NSObject, SensorDelegate {
    private let textFile: TextFile
    private let payloadString: String
    private let prefixLength: Int
    private let deviceName = UIDevice.current.name
    private let deviceOS = UIDevice.current.systemVersion
    private var payloads: Set<String> = []
    private let queue = DispatchQueue(label: "Sensor.Data.DetectionLog.Queue")
    
    init(filename: String, payloadString: String, prefixLength: Int) {
        textFile = TextFile(filename: filename)
        self.payloadString = payloadString
        self.prefixLength = prefixLength
    }
    
    private func csv(_ value: String) -> String {
        guard value.contains(",") else {
            return value
        }
        return "\"" + value + "\""
    }

    private func write() {
        let device = "\(deviceName) (iOS \(deviceOS))"
        let payloadPrefix = String(payloadString.prefix(prefixLength))
        var payloadList: [String] = []
        payloads.forEach() { payload in
            payloadList.append(String(payload.prefix(prefixLength)))
        }
        payloadList.sort()
        var content = csv(device) + ",id=" + payloadPrefix
        payloadList.forEach() { payload in
            content.append("," + payload)
        }
        content.append("\n")
        textFile.overwrite(content)
    }
    
    // MARK:- SensorDelegate
    
    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
    }
    
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        let payload = didRead.base64EncodedString()
        queue.async {
            if self.payloads.insert(payload).inserted {
                self.write()
            }
        }
    }
    
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
    }
    
    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
        didShare.forEach() { data in
            let payload = data.base64EncodedString()
            queue.async {
                if self.payloads.insert(payload).inserted {
                    self.write()
                }
            }
        }
    }
    
    func sensor(_ sensor: SensorType, didVisit: Location) {
    }
    

}
