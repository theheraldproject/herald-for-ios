//
//  BLESensor.swift
//  
//
//  Created  on 24/07/2020.
//  Copyright © 2020 . All rights reserved.
//

import Foundation

protocol BLESensor : Sensor {
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
