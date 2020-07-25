//
//  BLESensor.swift
//  C19X-SENSOR-iOS
//
//  Created by Freddy Choi on 24/07/2020.
//  Copyright © 2020 C19X. All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BLESensor : Sensor {
}

/// Defines BLE sensor configuration data, e.g. service and characteristic UUIDs
struct BLESensorConfiguration {
    /// BLE beacon service
    static let serviceUUID = CBUUID(string: "0022D481-83FE-1F13-0000-000000000000")
    /// Signaling characteristic for controlling connection between peripheral and central, e.g. keep each other from suspend state
    static let signalCharacteristicUUID = CBUUID(string: "0022D481-83FE-1F13-0000-000000000001")
    /// Primary payload characteristic (read) for distributing payload data from peripheral to central, e.g. identity data
    static let payloadCharacteristicUUID = CBUUID(string: "0022D481-83FE-1F13-0000-000000000002")
    /// Secondary payload characteristic (read) for sharing payload data acquired by this central, e.g. identity data of other peripherals in the vincinity
    static let sharedPayloadCharacteristicUUID = CBUUID(string: "0022D481-83FE-1F13-0000-000000000003")
}


/**
BLE sensor based on CoreBluetooth
Requires : Signing & Capabilities : BackgroundModes : Uses Bluetooth LE accessories  = YES
Requires : Signing & Capabilities : BackgroundModes : Acts as a Bluetooth LE accessory  = YES
Requires : Info.plist : Privacy - Bluetooth Always Usage Description
Requires : Info.plist : Privacy - Bluetooth Peripheral Usage Description
*/
class ConcreteBLESensor : NSObject, BLESensor {
    private let logger = ConcreteLogger(subsystem: "Sensor", category: "ConcreteBLESensor")
    private var delegates: [SensorDelegate] = []

    func add(delegate: SensorDelegate) {
        delegates.append(delegate)
    }
    
    func start() {
        logger.debug("start")
    }
    
    func stop() {
        logger.debug("stop")
    }
}
