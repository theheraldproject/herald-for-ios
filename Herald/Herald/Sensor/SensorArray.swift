//
//  SensorArray.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import UIKit

/// Sensor array for combining multiple detection and tracking methods.
public class SensorArray : NSObject, Sensor {
    public static let deviceDescription = "\(UIDevice.current.name) (iOS \(UIDevice.current.systemVersion))"
    public let payloadData: PayloadData?
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "SensorArray")
    private let concreteBle: ConcreteBLESensor
    private var sensorArray: [Sensor] = []
    private let delegateQueue = DispatchQueue(label: "Sensor.SensorArray.DelegateQueue")
    private var delegates: [SensorDelegate] = []

    public init(_ payloadDataSupplier: PayloadDataSupplier) {
        logger.debug("init")
        // Mobility sensor enables background BLE advert detection
        // - This is optional because an Android device can act as a relay,
        //   but enabling location sensor will enable direct iOS-iOS detection in background.
        // - Please note, the actual location is not used or recorded by HERALD.
        if let mobilitySensorResolution = BLESensorConfiguration.mobilitySensorEnabled {
            sensorArray.append(ConcreteMobilitySensor(resolution: mobilitySensorResolution, rangeForBeacon: UUID(uuidString:  BLESensorConfiguration.linuxFoundationServiceUUID.uuidString)))
        }
        // BLE sensor for detecting and tracking proximity
        concreteBle = ConcreteBLESensor(payloadDataSupplier)
        sensorArray.append(concreteBle)
        
        // Payload data at initiation time for identifying this device in the logs
        payloadData = payloadDataSupplier.payload(PayloadTimestamp(), device: nil)
        super.init()
        logger.debug("device (os=\(UIDevice.current.systemName)\(UIDevice.current.systemVersion),model=\(deviceModel()))")

        // Inertia sensor configured for automated RSSI-distance calibration data capture
        if BLESensorConfiguration.inertiaSensorEnabled {
            logger.debug("Inertia sensor enabled");
            sensorArray.append(ConcreteInertiaSensor());
            add(delegate: CalibrationLog(filename: "calibration.csv"));
        }

        if let payloadData = payloadData {
            logger.info("DEVICE (payloadPrefix=\(payloadData.shortName),description=\(SensorArray.deviceDescription))")
        } else {
            logger.info("DEVICE (payloadPrefix=EMPTY,description=\(SensorArray.deviceDescription))")
        }
    }
    
    private func deviceModel() -> String {
        var deviceInformation = utsname()
        uname(&deviceInformation)
        let mirror = Mirror(reflecting: deviceInformation.machine)
        return mirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else {
                return identifier
            }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
    
    public func immediateSend(data: Data, _ targetIdentifier: TargetIdentifier) -> Bool {
        return concreteBle.immediateSend(data: data,targetIdentifier);
    }
    
    public func immediateSendAll(data: Data) -> Bool {
        return concreteBle.immediateSendAll(data: data);
    }
    
    public func add(delegate: SensorDelegate) {
        delegates.append(delegate)
        sensorArray.forEach { $0.add(delegate: delegate) }
    }
    
    public func start() {
        logger.debug("start")
        sensorArray.forEach { $0.start() }
        delegates.forEach { $0.sensor(.ARRAY, didUpdateState: .on)}
    }
    
    public func stop() {
        logger.debug("stop")
        sensorArray.forEach { $0.stop() }
        delegates.forEach { $0.sensor(.ARRAY, didUpdateState: .off)}
    }
}
