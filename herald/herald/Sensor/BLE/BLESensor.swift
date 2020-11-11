//
//  BLESensor.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation
import CoreBluetooth

protocol BLESensor : Sensor {
}

/// Defines BLE sensor configuration data, e.g. service and characteristic UUIDs
public struct BLESensorConfiguration {
    static let logLevel: SensorLoggerLevel = .debug;
    
    // MARK:- BLE service and characteristic UUID, and manufacturer ID
    
    /// Service UUID for beacon service. This is a fixed UUID to enable iOS devices to find each other even
    /// in background mode. Android devices will need to find Apple devices first using the manufacturer code
    /// then discover services to identify actual beacons.
    /// - Service and characteristic UUIDs are V4 UUIDs that have been randomly generated and tested
    /// for uniqueness by conducting web searches to ensure it returns no results.
    static let serviceUUID = CBUUID(string: "428132af-4746-42d3-801e-4572d65bfd9b")
    /// Signaling characteristic for controlling connection between peripheral and central, e.g. keep each other from suspend state
    static let androidSignalCharacteristicUUID = CBUUID(string: "f617b813-092e-437a-8324-e09a80821a11")
    /// Signaling characteristic for controlling connection between peripheral and central, e.g. keep each other from suspend state
    static let iosSignalCharacteristicUUID = CBUUID(string: "0eb0d5f2-eae4-4a9a-8af3-a4adb02d4363")
    /// Primary payload characteristic (read) for distributing payload data from peripheral to central, e.g. identity data
    static let payloadCharacteristicUUID = CBUUID(string: "3e98c0f8-8f05-4829-a121-43e38f8933e7")
    /// Manufacturer data is being used on Android to store pseudo device address
    static let manufacturerIdForSensor = UInt16(65530)

    // MARK:- BLE signal characteristic action codes
    
    /// Signal characteristic action code for write payload, expect 1 byte action code followed by 2 byte little-endian Int16 integer value for payload data length, then payload data
    static let signalCharacteristicActionWritePayload = UInt8(1)
    /// Signal characteristic action code for write RSSI, expect 1 byte action code followed by 4 byte little-endian Int32 integer value for RSSI value
    static let signalCharacteristicActionWriteRSSI = UInt8(2)
    /// Signal characteristic action code for write payload, expect 1 byte action code followed by 2 byte little-endian Int16 integer value for payload sharing data length, then payload sharing data
    static let signalCharacteristicActionWritePayloadSharing = UInt8(3)
    /// Signal characteristic action code for arbitrary immediate write
    static let signalCharacteristicActionWriteImmediate = UInt8(4)

    // MARK:- BLE event timing
    
    /// Time delay between notifications for subscribers.
    static let notificationDelay = DispatchTimeInterval.seconds(2)
    /// Time delay between advert restart
    static let advertRestartTimeInterval = TimeInterval.hour
    /// Maximum number of concurrent BLE connections
    static let concurrentConnectionQuota = 12
    /// Advert refresh time interval on Android devices
    static let androidAdvertRefreshTimeInterval = TimeInterval.minute * 15
    
    // MARK:- App configurable BLE features

    /// Payload update at regular intervals, in addition to default HERALD communication process.
    /// - Use this to enable regular payload reads according to app payload lifespan.
    /// - Set to .never to disable this function.
    /// - Payload updates are reported to SensorDelegate as didRead.
    /// - Setting take immediate effect, no need to restart BLESensor, can also be applied while BLESensor is active.
    public static var payloadDataUpdateTimeInterval = TimeInterval.never
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
    private let receiver: ConcreteBLEReceiver

    init(_ payloadDataSupplier: PayloadDataSupplier) {
        database = ConcreteBLEDatabase()
        transmitter = ConcreteBLETransmitter(queue: sensorQueue, delegateQueue: delegateQueue, database: database, payloadDataSupplier: payloadDataSupplier)
        receiver = ConcreteBLEReceiver(queue: sensorQueue, delegateQueue: delegateQueue, database: database, payloadDataSupplier: payloadDataSupplier)
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
    
    func immediateSend(data: Data,_ targetIdentifier: TargetIdentifier) -> Bool {
        return receiver.immediateSend(data:data,targetIdentifier);
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
            let proximity = Proximity(unit: .RSSI, value: Double(rssi), calibration: device.calibration)
            logger.debug("didMeasure (device=\(device.identifier),payloadData=\(device.payloadData?.shortName ?? "nil"),proximity=\(proximity.description))")
            delegateQueue.async {
                self.delegates.forEach { $0.sensor(.BLE, didMeasure: proximity, fromTarget: device.identifier) }
            }
            guard let payloadData = device.payloadData else {
                return
            }
            delegateQueue.async {
                self.delegates.forEach { $0.sensor(.BLE, didMeasure: proximity, fromTarget: device.identifier, withPayload: payloadData) }
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
