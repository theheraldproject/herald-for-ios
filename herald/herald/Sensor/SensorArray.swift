//
//  SensorArray.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import UIKit

/// Sensor array for combining multiple detection and tracking methods.
public class SensorArray : NSObject, Sensor {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "SensorArray")
    private var sensorArray: [Sensor] = []
    public let payloadData: PayloadData?
    public static let deviceDescription = "\(UIDevice.current.name) (iOS \(UIDevice.current.systemVersion))"
    
    private var concreteBle: ConcreteBLESensor?;

    public init(_ payloadDataSupplier: PayloadDataSupplier) {
        logger.debug("init")
        // Location sensor is necessary for enabling background BLE advert detection
        // - This is optional in iOS 9.3 to 13, because an Android device can act as a relay,
        //   but enabling location sensor will enable direct iOS-iOS detection in background.
        // - This is mandatory in iOS 14, because service discovery will fail for Android and
        //   iOS devices unless location sensor has been enabled and the user grants access
        //   to location. Please note, the actual location is not used nor recorded by HERALD.
        //   This is only necessary to enable iOS-iOS background BLE advert discovery, and
        //   service discovery, to enable characteristic read / write / notify with other
        //   iOS and Android devices.
        if (BLESensorConfiguration.awakeOnLocationEnabled) {
            sensorArray.append(ConcreteGPSSensor(rangeForBeacon: UUID(uuidString:  BLESensorConfiguration.serviceUUID.uuidString)))
        }
        // BLE sensor for detecting and tracking proximity
        concreteBle = ConcreteBLESensor(payloadDataSupplier)
        sensorArray.append(concreteBle!)
        // Payload data at initiation time for identifying this device in the logs
        payloadData = payloadDataSupplier.payload(PayloadTimestamp(), device: nil)
        super.init()
        
        if let payloadData = payloadData {
        
        // Loggers
        #if DEBUG
            add(delegate: ContactLog(filename: "contacts.csv"))
            add(delegate: StatisticsLog(filename: "statistics.csv", payloadData: payloadData))
            add(delegate: StatisticsDidReadLog(filename: "statistics_didRead.csv", payloadData: payloadData))
            add(delegate: DetectionLog(filename: "detection.csv", payloadData: payloadData))
            _ = BatteryLog(filename: "battery.csv")
        #endif
        logger.info("DEVICE (payloadPrefix=\(payloadData.shortName),description=\(SensorArray.deviceDescription))")
        } else {
            logger.info("DEVICE (payloadPrefix=EMPTY,description=\(SensorArray.deviceDescription))")
        }
    }
    
    public func immediateSend(data: Data, _ targetIdentifier: TargetIdentifier) -> Bool {
        return concreteBle!.immediateSend(data: data,targetIdentifier);
    }
    
    public func add(delegate: SensorDelegate) {
        sensorArray.forEach { $0.add(delegate: delegate) }
    }
    
    public func start() {
        logger.debug("start")
        sensorArray.forEach { $0.start() }
    }
    
    public func stop() {
        logger.debug("stop")
        sensorArray.forEach { $0.stop() }
    }
}
