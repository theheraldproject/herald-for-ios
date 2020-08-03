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
    private let dateFormatter = DateFormatter()
    private let deviceOS = UIDevice.current.systemVersion
    private let deviceName = UIDevice.current.name
    private var identifierToPayload: [String:String] = [:]
    private var identifierToSharedPayloads: [String:[String]] = [:]
    
    init(filename: String) {
        textFile = TextFile(filename: filename)
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
        let payload = didRead.base64EncodedString()
        identifierToPayload[fromTarget] = payload
        textFile.write(timestamp() + "," + payload + "," + deviceName + ",iOS," + deviceOS)
    }
    
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        guard let payload = identifierToPayload[fromTarget] else {
            return
        }
        textFile.write(timestamp() + "," + payload + "," + deviceName + ",iOS," + deviceOS)
    }
    
    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
        if identifierToSharedPayloads[fromTarget] == nil {
            identifierToSharedPayloads[fromTarget] = []
        }
        didShare.forEach() { data in
            let payload = data.base64EncodedString()
            identifierToSharedPayloads[fromTarget]?.append(payload)
        }
        identifierToSharedPayloads[fromTarget]?.forEach() { payload in
            textFile.write(timestamp() + "," + payload + "," + deviceName + ",iOS," + deviceOS)
        }
    }
    
    func sensor(_ sensor: SensorType, didVisit: Location) {
    }
    

}
