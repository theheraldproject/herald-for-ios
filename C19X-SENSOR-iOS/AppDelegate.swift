//
//  AppDelegate.swift
//  
//
//  Created  on 24/07/2020.
//  Copyright © 2020 . All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, SensorDelegate {
    private let logger = ConcreteSensorLogger(subsystem: "App", category: "AppDelegate")
    var window: UIWindow?

    // Payload data supplier, sensor and contact log
    var payloadDataSupplier: PayloadDataSupplier?
    var sensor: Sensor?

    /// Generate unique and consistent device identifier for testing detection and tracking
    private func identifier() -> Int32 {
        let text = UIDevice.current.name + ":" + UIDevice.current.model + ":" + UIDevice.current.systemName + ":" + UIDevice.current.systemVersion
        var hash = UInt64 (5381)
        let buf = [UInt8](text.utf8)
        for b in buf {
            hash = 127 * (hash & 0x00ffffffffffffff) + UInt64(b)
        }
        let value = Int32(hash.remainderReportingOverflow(dividingBy: UInt64(Int32.max)).partialValue)
        logger.debug("Identifier (text=\(text),hash=\(hash),value=\(value))")
        return value
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        logger.debug("application:didFinishLaunchingWithOptions")
        
        let deviceIdentifier = identifier()
        payloadDataSupplier = MockSonarPayloadSupplier(identifier: deviceIdentifier)
        let payloadString = payloadDataSupplier!.payload(Date()).base64EncodedString()
        logger.info("DEVICE ID (identifier=\(deviceIdentifier),payloadPrefix=\(payloadString.prefix(6)),payload=\(payloadString))")


        sensor = SensorArray(payloadDataSupplier!)
        sensor?.add(delegate: self)
        sensor?.add(delegate: ContactLog(filename: "contacts.csv"))
        sensor?.add(delegate: RScriptLog(filename: "rScriptLog.csv"))
        sensor?.add(delegate: DetectionLog(filename: "detection.csv", payloadString: payloadString, prefixLength: 6))
        sensor?.start()
        
        return true
    }
    
    // MARK:- UIApplicationDelegate
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        logger.debug("applicationDidBecomeActive")
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        logger.debug("applicationWillResignActive")
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        logger.debug("applicationWillEnterForeground")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        logger.debug("applicationDidEnterBackground")
    }

    func applicationWillTerminate(_ application: UIApplication) {
        logger.debug("applicationWillTerminate")
    }
    
    // MARK:- SensorDelegate
    
    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
        logger.info(sensor.rawValue + ",didDetect=" + didDetect.description)
    }
    
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        logger.info(sensor.rawValue + ",didRead=" + didRead.base64EncodedString() + ",fromTarget=" + fromTarget.description)
    }
    
    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
        let payloads = didShare.map { $0.base64EncodedString() }
        logger.info(sensor.rawValue + ",didShare=" + payloads.description + ",fromTarget=" + fromTarget.description)
    }
    
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        logger.info(sensor.rawValue + ",didMeasure=" + didMeasure.description + ",fromTarget=" + fromTarget.description)
    }
    
    func sensor(_ sensor: SensorType, didVisit: Location) {
        logger.info(sensor.rawValue + ",didVisit=" + didVisit.description)
    }
    

}

