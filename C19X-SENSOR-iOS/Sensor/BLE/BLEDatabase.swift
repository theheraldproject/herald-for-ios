//
//  BLEDatabase.swift
//  C19X-SENSOR-iOS
//
//  Created by Freddy Choi on 26/07/2020.
//  Copyright © 2020 C19X. All rights reserved.
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

    /// Get or create device for collating information from asynchronous BLE operations.
    func device(_ payload: PayloadData) -> BLEDevice

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
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "BLE.ConcreteBLEDatabase")
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
    
    func device(_ payload: PayloadData) -> BLEDevice {
        if let device = database.values.filter({ $0.payloadData == payload }).first {
            return device
        }
        // Create temporary UUID, the taskRemoveDuplicatePeripherals function
        // will delete this when a direct connection to the peripheral has been
        // established
        let identifier = TargetIdentifier(UUID().uuidString)
        let placeholder = device(identifier)
        placeholder.payloadData = payload
        return placeholder
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
    /// Device registratiion timestamp
    let createdAt: Date
    /// Last time anything changed, e.g. attribute update
    var lastUpdatedAt: Date
    /// Last time a wake up call was received from this device (iOS only)
    var lastNotifiedAt: Date = Date.distantPast
    /// Ephemeral device identifier, e.g. peripheral identifier UUID
    let identifier: TargetIdentifier
    /// Delegate for listening to attribute updates events.
    let delegate: BLEDeviceDelegate
    /// CoreBluetooth peripheral object for interacting with this device.
    var peripheral: CBPeripheral? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .peripheral)
        }}
    /// Service characteristic for signalling between BLE devices, e.g. to keep awake
    var signalCharacteristic: CBCharacteristic? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .signalCharacteristic)
        }}
    /// Service characteristic for reading payload data, e.g. C19X beacon code or Sonar encrypted identifier
    var payloadCharacteristic: CBCharacteristic? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .payloadCharacteristic)
        }}
    /// Service characteristic for reading payload sharing data, e.g. C19X beacon code or Sonar encrypted identifier recently acquired by this device
    var payloadSharingCharacteristic: CBCharacteristic? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .payloadSharingCharacteristic)
        }}
    /// Device operating system, this is necessary for selecting different interaction procedures for each platform.
    var operatingSystem: BLEDeviceOperatingSystem = .unknown {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .operatingSystem)
        }}
    /// Payload data acquired from the device via payloadCharacteristic read, e.g. C19X beacon code or Sonar encrypted identifier
    var payloadData: PayloadData? {
        didSet {
            payloadDataLastUpdatedAt = Date()
            lastUpdatedAt = payloadDataLastUpdatedAt
            delegate.device(self, didUpdate: .payloadData)
        }}
    /// Payload data last update timestamp, this is used to determine what needs to be shared with peers.
    var payloadDataLastUpdatedAt: Date = Date.distantPast
    /// Payload data already shared with this peer
    var payloadSharingData: [PayloadData] = []
    /// Payload sharing last update timestamp, , this is used to throttle read payload sharing calls
    var payloadSharingDataLastUpdatedAt: Date = Date.distantPast
    
    /// Most recent RSSI measurement taken by readRSSI or didDiscover.
    var rssi: BLE_RSSI? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .rssi)
        }}
    /// Transmit power data where available (only provided by Android devices)
    var txPower: BLE_TxPower? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .txPower)
        }}

    /// Time interval since last attribute value update, this is used to identify devices that may have expired and should be removed from the database.
    var timeIntervalSinceLastUpdate: TimeInterval { get {
            Date().timeIntervalSince(lastUpdatedAt)
        }}
    /// Time interval since last payload sharing value update, this is used to throttle read payload sharing calls
    var timeIntervalSinceLastPayloadShared: TimeInterval { get {
            Date().timeIntervalSince(payloadSharingDataLastUpdatedAt)
        }}
    var description: String { get {
        return "BLEDevice[id=\(identifier),lastUpdatedAt=\(lastUpdatedAt.description),peripheral=\(peripheral == nil ? "-" : "T"),os=\(operatingSystem.rawValue)]"
        }}
    
    init(_ identifier: TargetIdentifier, delegate: BLEDeviceDelegate) {
        self.createdAt = Date()
        self.identifier = identifier
        self.delegate = delegate
        lastUpdatedAt = createdAt
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
