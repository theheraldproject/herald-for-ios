//
//  RScriptLog.swift
//  
//
//  Created  on 03/08/2020.
//  Copyright © 2020 . All rights reserved.
//

import Foundation
import UIKit

/// CSV contact log for post event analysis and visualisation
class RScriptLog: NSObject, SensorDelegate {
    private let textFile: TextFile
    private let payloadData: PayloadData
    private let dateFormatter = DateFormatter()
    private let deviceOS = UIDevice.current.systemVersion
    private let deviceName = UIDevice.current.name
    private var identifierToPayload: [String:String] = [:]
    
    init(filename: String, payloadData: PayloadData) {
        textFile = TextFile(filename: filename)
        self.payloadData = payloadData
        if textFile.empty() {
            textFile.write("datetime,payload,devicename,os,osver")
        }
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    private func timestamp() -> String {
        let timestamp = dateFormatter.string(from: Date())
        return timestamp
    }
    
    private func csv(_ value: String) -> String {
        guard value.contains(",") else {
            return value
        }
        return "\"" + value + "\""
    }
    
    // MARK:- SensorDelegate
    
    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
    }
    
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        identifierToPayload[fromTarget] = didRead.shortName
        textFile.write(timestamp() + "," + didRead.shortName + "," + deviceName + ",iOS," + deviceOS)
    }
    
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        guard let payload = identifierToPayload[fromTarget] else {
            return
        }
        textFile.write(timestamp() + "," + payload + "," + deviceName + ",iOS," + deviceOS)
    }
    
    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
        let now = timestamp()
        didShare.forEach() { payload in
            guard payload.shortName != payloadData.shortName else {
                return
            }
            textFile.write(now + "," + payload.shortName + "," + deviceName + ",iOS," + deviceOS)
        }
    }
    
    func sensor(_ sensor: SensorType, didVisit: Location) {
    }
    

}
