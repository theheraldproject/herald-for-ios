//
//  BLESensor.swift
//  
//
//  Created  on 24/07/2020.
//  Copyright © 2020 . All rights reserved.
//

import Foundation
import CoreBluetooth

protocol BLESensor : Sensor {
}

/// Defines BLE sensor configuration data, e.g. service and characteristic UUIDs
struct BLESensorConfiguration {
    /**
    Service UUID for beacon service. This is a fixed UUID to enable iOS devices to find each other even
    in background mode. Android devices will need to find Apple devices first using the manufacturer code
    then discover services to identify actual beacons.
    */
    static let serviceUUID = CBUUID(string: "FFFFFFFF-EEEE-DDDD-0000-000000000000")
    /// Signaling characteristic for controlling connection between peripheral and central, e.g. keep each other from suspend state
    static let signalCharacteristicUUID = CBUUID(string: "FFFFFFFF-EEEE-DDDD-0000-000000000001")
    /// Primary payload characteristic (read) for distributing payload data from peripheral to central, e.g. identity data
    static let payloadCharacteristicUUID = CBUUID(string: "FFFFFFFF-EEEE-DDDD-0000-000000000002")
    /// Secondary payload characteristic (read) for sharing payload data acquired by this central, e.g. identity data of other peripherals in the vincinity
    static let payloadSharingCharacteristicUUID = CBUUID(string: "FFFFFFFF-EEEE-DDDD-0000-000000000003")
    /// Time delay between notifications for subscribers.
    static let notificationDelay = DispatchTimeInterval.seconds(8)
}


/**
BLE sensor based on CoreBluetooth
Requires : Signing & Capabilities : BackgroundModes : Uses Bluetooth LE accessories  = YES
Requires : Signing & Capabilities : BackgroundModes : Acts as a Bluetooth LE accessory  = YES
Requires : Info.plist : Privacy - Bluetooth Always Usage Description
Requires : Info.plist : Privacy - Bluetooth Peripheral Usage Description
*/
class ConcreteBLESensor : NSObject, BLESensor {
    private let logger = ConcreteLogger(subsystem: "Sensor", category: "BLE.ConcreteBLESensor")
    private let queue = DispatchQueue(label: "Sensor.BLE.ConcreteBLESensor")
    private let database: BLEDatabase
    private let transmitter: BLETransmitter
    private let receiver: BLEReceiver

    init(_ payloadDataSupplier: PayloadDataSupplier) {
        database = ConcreteBLEDatabase()
        receiver = ConcreteBLEReceiver(queue: queue, database: database)
        transmitter = ConcreteBLETransmitter(queue: queue, database: database, payloadDataSupplier: payloadDataSupplier, receiver: receiver)
        super.init()
    }
    
    func start() {
        logger.debug("start")
        transmitter.start()
        receiver.start()
    }

    func stop() {
        logger.debug("stop")
        transmitter.stop()
        receiver.stop()
    }
    
    func add(delegate: SensorDelegate) {
        transmitter.add(delegate)
//        receiver.add(delegate)
    }
}
