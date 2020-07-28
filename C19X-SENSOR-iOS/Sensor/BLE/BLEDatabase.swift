//
//  BLEDatabase.swift
//  
//
//  Created  on 26/07/2020.
//  Copyright © 2020 . All rights reserved.
//

import Foundation
import CoreBluetooth

/// Registry for collating sniplets of information from asynchronous BLE operations.
protocol BLEDatabase {
    
    /// Add delegate for handling database events
    func add(delegate: BLEDatabaseDelegate)
    
    /// Get or create device for collating information from asynchronous BLE operations.
    func device(_ identifier: TargetIdentifier) -> BLEDevice

    /// Get or create device for collating information from asynchronous BLE operations.
    func device(_ peripheral: CBPeripheral, delegate: CBPeripheralDelegate) -> BLEDevice

    /// Get all devices
    func devices() -> [BLEDevice]
    
    /// Delete
    func delete(_ identifier: TargetIdentifier)
}

/// Delegate for receiving registry create/update/delete events
protocol BLEDatabaseDelegate {
    
    func bleDatabase(didCreate device: BLEDevice)
    
    func bleDatabase(didUpdate device: BLEDevice, attribute: BLEDeviceAttribute)
    
    func bleDatabase(didDelete device: BLEDevice)
}

extension BLEDatabaseDelegate {
    func bleDatabase(didCreate device: BLEDevice) {}
    
    func bleDatabase(didUpdate device: BLEDevice, attribute: BLEDeviceAttribute) {}
    
    func bleDatabase(didDelete device: BLEDevice) {}
}

class ConcreteBLEDatabase : NSObject, BLEDatabase, BLEDeviceDelegate {
    private let logger = ConcreteLogger(subsystem: "Sensor", category: "BLE.ConcreteBLEDatabase")
    private var delegates: [BLEDatabaseDelegate] = []
    private var database: [TargetIdentifier : BLEDevice] = [:]
    private var queue = DispatchQueue(label: "Sensor.BLE.ConcreteBLEDatabase")
    
    func add(delegate: BLEDatabaseDelegate) {
        delegates.append(delegate)
    }
    
    func devices() -> [BLEDevice] {
        return database.values.map { $0 }
    }
    
    func device(_ identifier: TargetIdentifier) -> BLEDevice {
        if database[identifier] == nil {
            let device = BLEDevice(identifier, delegate: self)
            database[identifier] = device
            queue.async {
                self.logger.debug("create (device=\(identifier))")
                self.delegates.forEach { $0.bleDatabase(didCreate: device) }
            }
        }
        let device = database[identifier]!
        return device
    }

    func device(_ peripheral: CBPeripheral, delegate: CBPeripheralDelegate) -> BLEDevice {
        let identifier = TargetIdentifier(peripheral: peripheral)
        if database[identifier] == nil {
            let device = BLEDevice(identifier, delegate: self)
            database[identifier] = device
            queue.async {
                self.logger.debug("create (device=\(identifier))")
                self.delegates.forEach { $0.bleDatabase(didCreate: device) }
            }
        }
        let device = database[identifier]!
        device.peripheral = peripheral
        peripheral.delegate = delegate
        return device
    }

    func delete(_ identifier: TargetIdentifier) {
        guard let device = database[identifier] else {
            return
        }
        database[identifier] = nil
        queue.async {
            self.logger.debug("delete (device=\(identifier))")
            self.delegates.forEach { $0.bleDatabase(didDelete: device) }
        }
    }
    
    // MARK:- BLEDeviceDelegate
    
    func device(_ device: BLEDevice, didUpdate attribute: BLEDeviceAttribute) {
        queue.async {
            self.logger.debug("update (device=\(device.identifier),attribute=\(attribute.rawValue))")
            self.delegates.forEach { $0.bleDatabase(didUpdate: device, attribute: attribute) }
        }
    }
}

// MARK:- BLEDatabase data

class BLEDevice {
    let identifier: TargetIdentifier
    let delegate: BLEDeviceDelegate
    var peripheral: CBPeripheral? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .peripheral)
        }}
    var signalCharacteristic: CBCharacteristic? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .signalCharacteristic)
        }}
    var payloadCharacteristic: CBCharacteristic? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .payloadCharacteristic)
        }}
    var payloadSharingCharacteristic: CBCharacteristic? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .payloadSharingCharacteristic)
        }}
    var operatingSystem: BLEDeviceOperatingSystem = .unknown {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .operatingSystem)
        }}
    var payloadData: PayloadData? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .payloadData)
        }}
    var rssi: BLE_RSSI? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .rssi)
        }}
    var txPower: BLE_TxPower? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .txPower)
        }}
    var lastUpdatedAt: Date
    var timeIntervalSinceLastUpdate: TimeInterval { get {
            Date().timeIntervalSince(lastUpdatedAt)
        }}
    var description: String { get {
        return "BLEDevice[id=\(identifier),lastUpdatedAt=\(lastUpdatedAt.description),peripheral=\(peripheral == nil ? "-" : "T"),os=\(operatingSystem.rawValue)]"
        }}
    
    init(_ identifier: TargetIdentifier, delegate: BLEDeviceDelegate) {
        self.identifier = identifier
        self.delegate = delegate
        lastUpdatedAt = Date()
    }
}

protocol BLEDeviceDelegate {
    func device(_ device: BLEDevice, didUpdate attribute: BLEDeviceAttribute)
}

enum BLEDeviceAttribute : String {
    case peripheral, signalCharacteristic, payloadCharacteristic, payloadSharingCharacteristic, operatingSystem, payloadData, rssi, txPower
}

enum BLEDeviceOperatingSystem : String {
    case android, ios, restored, unknown
}

/// RSSI in dBm.
typealias BLE_RSSI = Int

typealias BLE_TxPower = Int
