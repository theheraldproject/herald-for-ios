//
//  AppDelegate.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import UIKit
import os
import Herald

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, SensorDelegate {
    private let logger = Log(subsystem: "Herald", category: "AppDelegate")
    var window: UIWindow?

    // Payload data supplier, sensor and contact log
    var payloadDataSupplier: PayloadDataSupplier?
    var sensor: SensorArray?
    var phoneMode = true
    
    // Test automation, set to null to disable automation.
    // Set to "http://serverAddress:port" to enable automation.
    let automatedTestServer: String? = nil
    var automatedTestClient: AutomatedTestClient? = nil

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
        return true
    }
    
    func startPhone() {
        phoneMode = true
        payloadDataSupplier = ConcreteTestPayloadDataSupplier(identifier: identifier())
        sensor = SensorArray(payloadDataSupplier!)
        sensor?.add(delegate: self)
        // Sensor will start and stop with UI switch (default ON) and bluetooth state
        // Or remotely controlled by test server.
        if let automatedTestServer = automatedTestServer, let sensorArray = sensor {
            automatedTestClient = AutomatedTestClient(serverAddress: automatedTestServer, sensorArray: sensorArray, heartbeatInterval: TimeInterval(10))
            if let automatedTestClient = automatedTestClient {
                sensor?.add(delegate: automatedTestClient)
            }
        } else {
            sensor?.start()
        }
        addEfficacyLogging()
        

        // EXAMPLE immediate data send function (note: NOT wrapped with Herald header)
        //let targetIdentifier: TargetIdentifier? // ... set its value
        //let success: Bool = sensor!.immediateSend(data: Data(), targetIdentifier!)
        
    }
    
    func stopPhone() {
        sensor?.stop()
    }
    
    func startBeacon(_ payloadSupplier: PayloadDataSupplier) {
        phoneMode = false
        sensor = SensorArray(payloadSupplier)
        
        // Add ourselves as delegate
        sensor?.add(delegate: self)
        addEfficacyLogging()
        sensor?.start()
    }
    
    func stopBeacon() {
        sensor?.stop()
    }
    
    public func stopBluetooth() {
        if phoneMode {
            stopPhone()
        } else {
            stopBeacon()
        }
    }

    // MARK:- Efficacy Logging

    func addEfficacyLogging() {
        if let payloadData = sensor?.payloadData {
            // Loggers
            #if DEBUG
            var sensorDelegateLoggers: [SensorDelegateLogger] = []
            sensorDelegateLoggers.append(ContactLog(filename: "contacts.csv"))
            sensorDelegateLoggers.append(StatisticsLog(filename: "statistics.csv", payloadData: payloadData))
            sensorDelegateLoggers.append(DetectionLog(filename: "detection.csv", payloadData: payloadData))
            sensorDelegateLoggers.append(BatteryLog(filename: "battery.csv"))
            if (BLESensorConfiguration.payloadDataUpdateTimeInterval != .never ||
                (BLESensorConfiguration.interopOpenTraceEnabled && BLESensorConfiguration.interopOpenTracePayloadDataUpdateTimeInterval != .never)) {
                sensorDelegateLoggers.append(EventTimeIntervalLog(filename: "statistics_didRead.csv", payloadData: payloadData, eventType: .read))
            }
            for sensorDelegateLogger in sensorDelegateLoggers {
                sensor?.add(delegate: sensorDelegateLogger)
                automatedTestClient?.add(sensorDelegateLogger)
            }
            #endif
        }
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
//        stopBluetooth()
    }
    
    // MARK:- SensorDelegate
    
    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
        logger.info(sensor.rawValue + ",didDetect=" + didDetect.description)
    }
    
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        logger.info(sensor.rawValue + ",didRead=" + didRead.shortName + ",fromTarget=" + fromTarget.description)
    }
    
    func sensor(_ sensor: SensorType, didReceive: Data, fromTarget: TargetIdentifier) {
        logger.info(sensor.rawValue + ",didReceive=" + didReceive.base64EncodedString() + ",fromTarget=" + fromTarget.description)
    }
    
    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
        let payloads = didShare.map { $0.shortName }
        logger.info(sensor.rawValue + ",didShare=" + payloads.description + ",fromTarget=" + fromTarget.description)
    }
    
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        logger.info(sensor.rawValue + ",didMeasure=" + didMeasure.description + ",fromTarget=" + fromTarget.description)
    }
    
    func sensor(_ sensor: SensorType, didVisit: Location?) {
        logger.info(sensor.rawValue + ",didVisit=" + String(describing: didVisit))
    }
    
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData) {
        logger.info(sensor.rawValue + ",didMeasure=" + didMeasure.description + ",fromTarget=" + fromTarget.description + ",withPayload=" + withPayload.shortName)
    }
    
    func sensor(_ sensor: SensorType, didUpdateState: SensorState) {
        logger.info(sensor.rawValue + ",didUpdateState=" + didUpdateState.rawValue)
    }

}

