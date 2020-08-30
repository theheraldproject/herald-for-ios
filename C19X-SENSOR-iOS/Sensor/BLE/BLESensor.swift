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
    static let logLevel: SensorLoggerLevel = .debug;
    /**
    Service UUID for beacon service. This is a fixed UUID to enable iOS devices to find each other even
    in background mode. Android devices will need to find Apple devices first using the manufacturer code
    then discover services to identify actual beacons.
    */
    static let serviceUUID = CBUUID(string: "FFFFFFFF-EEEE-DDDD-0000-000000000000")
    /// Signaling characteristic for controlling connection between peripheral and central, e.g. keep each other from suspend state
    static let androidSignalCharacteristicUUID = CBUUID(string: "FFFFFFFF-EEEE-DDDD-0000-000000000001")
    /// Signaling characteristic for controlling connection between peripheral and central, e.g. keep each other from suspend state
    static let iosSignalCharacteristicUUID = CBUUID(string: "FFFFFFFF-EEEE-DDDD-0000-000000000002")
    /// Primary payload characteristic (read) for distributing payload data from peripheral to central, e.g. identity data
    static let payloadCharacteristicUUID = CBUUID(string: "FFFFFFFF-EEEE-DDDD-0000-000000000003")
    /// Time delay between notifications for subscribers.
    static let notificationDelay = DispatchTimeInterval.seconds(2)
    /// Time delay between advert restart
    static let advertRestartTimeInterval = TimeInterval.hour
    /// Expiry time for shared payloads, to ensure only recently seen payloads are shared
    /// Must be > payloadSharingTimeInterval to share pending payloads
    static let payloadSharingExpiryTimeInterval = TimeInterval.minute * 5
    /// Maximum number of concurrent BLE connections
    static let concurrentConnectionQuota = 12
    /// Manufacturer data is being used on Android to store pseudo device address
    static let manufacturerIdForSensor = UInt16(65530);
    /// Advert refresh time interval on Android devices
    static let androidAdvertRefreshTimeInterval = TimeInterval.minute * 15;


    /// Signal characteristic action code for write payload, expect 1 byte action code followed by 2 byte little-endian Int16 integer value for payload data length, then payload data
    static let signalCharacteristicActionWritePayload = UInt8(1)
    /// Signal characteristic action code for write RSSI, expect 1 byte action code followed by 4 byte little-endian Int32 integer value for RSSI value
    static let signalCharacteristicActionWriteRSSI = UInt8(2)
    /// Signal characteristic action code for write payload, expect 1 byte action code followed by 2 byte little-endian Int16 integer value for payload sharing data length, then payload sharing data
    static let signalCharacteristicActionWritePayloadSharing = UInt8(3)
}


/**
BLE sensor based on CoreBluetooth
Requires : Signing & Capabilities : BackgroundModes : Uses Bluetooth LE accessories  = YES
Requires : Signing & Capabilities : BackgroundModes : Acts as a Bluetooth LE accessory  = YES
Requires : Info.plist : Privacy - Bluetooth Always Usage Description
Requires : Info.plist : Privacy - Bluetooth Peripheral Usage Description
*/
class ConcreteBLESensor : NSObject, BLESensor, BLEDatabaseDelegate {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "BLE.ConcreteBLESensor")
    private let sensorQueue = DispatchQueue(label: "Sensor.BLE.ConcreteBLESensor.SensorQueue")
    private let delegateQueue = DispatchQueue(label: "Sensor.BLE.ConcreteBLESensor.DelegateQueue")
    private var delegates: [SensorDelegate] = []
    private let database: BLEDatabase
    private let transmitter: BLETransmitter
    private let receiver: BLEReceiver

    init(_ payloadDataSupplier: PayloadDataSupplier) {
        database = ConcreteBLEDatabase()
        transmitter = ConcreteBLETransmitter(queue: sensorQueue, database: database, payloadDataSupplier: payloadDataSupplier)
        receiver = ConcreteBLEReceiver(queue: sensorQueue, database: database, payloadDataSupplier: payloadDataSupplier)
        super.init()
        database.add(delegate: self)
    }
    
    func start() {
        logger.debug("start")
        // BLE transmitter and receivers start on powerOn event
    }

    func stop() {
        logger.debug("stop")
        // BLE transmitter and receivers stops on powerOff event
    }
    
    func add(delegate: SensorDelegate) {
        delegates.append(delegate)
        transmitter.add(delegate: delegate)
        receiver.add(delegate: delegate)
    }
    
    // MARK:- BLEDatabaseDelegate
    
    func bleDatabase(didCreate device: BLEDevice) {
        logger.debug("didDetect (device=\(device.identifier),payloadData=\(device.payloadData?.shortName ?? "nil"))")
        delegateQueue.async {
            self.delegates.forEach { $0.sensor(.BLE, didDetect: device.identifier) }
        }
    }
    
    func bleDatabase(didUpdate device: BLEDevice, attribute: BLEDeviceAttribute) {
        switch attribute {
        case .rssi:
            guard let rssi = device.rssi else {
                return
            }
            let proximity = Proximity(unit: .RSSI, value: Double(rssi))
            logger.debug("didMeasure (device=\(device.identifier),payloadData=\(device.payloadData?.shortName ?? "nil"),proximity=\(proximity.description))")
            delegateQueue.async {
                self.delegates.forEach { $0.sensor(.BLE, didMeasure: proximity, fromTarget: device.identifier) }
            }
        case .payloadData:
            guard let payloadData = device.payloadData else {
                return
            }
            logger.debug("didRead (device=\(device.identifier),payloadData=\(payloadData.shortName))")
            delegateQueue.async {
                self.delegates.forEach { $0.sensor(.BLE, didRead: payloadData, fromTarget: device.identifier) }
            }
        default:
            return
        }
    }
    
}

extension TargetIdentifier {
    init(peripheral: CBPeripheral) {
        self.init(peripheral.identifier.uuidString)
    }
    init(central: CBCentral) {
        self.init(central.identifier.uuidString)
    }
}
