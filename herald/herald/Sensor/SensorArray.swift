//
//  SensorArray.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation
import UIKit

/// Sensor array for combining multiple detection and tracking methods.
public class SensorArray : NSObject, Sensor {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "SensorArray")
    private var sensorArray: [Sensor] = []
    public let payloadData: PayloadData
    public static let deviceDescription = "\(UIDevice.current.name) (iOS \(UIDevice.current.systemVersion))"

    public init(_ payloadDataSupplier: PayloadDataSupplier) {
        logger.debug("init")
        // Location sensor is necessary for enabling background BLE advert detection
        // NOT REQUIRED: sensorArray.append(ConcreteGPSSensor(rangeForBeacon: UUID(uuidString:  BLESensorConfiguration.serviceUUID.uuidString)))
        // BLE sensor for detecting and tracking proximity
        sensorArray.append(ConcreteBLESensor(payloadDataSupplier))
        // Payload data at initiation time for identifying this device in the logs
        payloadData = payloadDataSupplier.payload(PayloadTimestamp())
        super.init()
        
        // Loggers
        add(delegate: ContactLog(filename: "contacts.csv"))
        add(delegate: StatisticsLog(filename: "statistics.csv", payloadData: payloadData))
        add(delegate: DetectionLog(filename: "detection.csv", payloadData: payloadData))
        _ = BatteryLog(filename: "battery.csv")
        logger.info("DEVICE (payloadPrefix=\(payloadData.shortName),description=\(SensorArray.deviceDescription))")
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
