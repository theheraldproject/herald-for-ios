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
    
    /// Associate identifier with peripheral
    func insert(_ identifier: TargetIdentifier, peripheral: CBPeripheral)
    func insert(_ identifier: TargetIdentifier, signalCharacteristic: CBCharacteristic)
    func insert(_ identifier: TargetIdentifier, payloadCharacteristic: CBCharacteristic)
    func insert(_ identifier: TargetIdentifier, payloadSharingCharacteristic: CBCharacteristic)
    func insert(_ identifier: TargetIdentifier, operatingSystem: BLEDeviceOperatingSystem)
    /// Measured RSSI at time
    func insert(_ identifier: TargetIdentifier, rssi: RSSI)
    func insert(_ identifier: TargetIdentifier, payload: PayloadData)
    func insert(_ identifier: TargetIdentifier, shared: [PayloadData])
}

class BLEDevice {
    var identifier: TargetIdentifier
    var peripheral: CBPeripheral?
    var signalCharacteristic: CBCharacteristic?
    var payloadCharacteristic: CBCharacteristic?
    var payloadSharingCharacteristic: CBCharacteristic?
    var operatingSystem: BLEDeviceOperatingSystem = .unknown
    var lastSeenAt: Date = .distantPast
    
    init(_ identifier: TargetIdentifier) {
        self.identifier = identifier
    }
}

enum BLEDeviceOperatingSystem {
    case android
    case ios
    case restored
    case unknown
}

