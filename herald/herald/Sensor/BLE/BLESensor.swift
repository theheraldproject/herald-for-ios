//
//  BLESensor.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import CoreBluetooth

protocol BLESensor : Sensor {
}

/// Defines BLE sensor configuration data, e.g. service and characteristic UUIDs
public struct BLESensorConfiguration {
    // MARK:- BLE service and characteristic UUID, and manufacturer ID
    
    /// Service UUID for beacon service. This is a fixed UUID to enable iOS devices to find each other even
    /// in background mode. Android devices will need to find Apple devices first using the manufacturer code
    /// then discover services to identify actual beacons.
    /// - Service and characteristic UUIDs are V4 UUIDs that have been randomly generated and tested
    /// for uniqueness by conducting web searches to ensure it returns no results.
    public static var serviceUUID = CBUUID(string: "428132af-4746-42d3-801e-4572d65bfd9b")
    /// Signaling characteristic for controlling connection between peripheral and central, e.g. keep each other from suspend state
    /// - Characteristic UUID is randomly generated V4 UUIDs that has been tested for uniqueness by conducting web searches to ensure it returns no results.
    public static var androidSignalCharacteristicUUID = CBUUID(string: "f617b813-092e-437a-8324-e09a80821a11")
    /// Signaling characteristic for controlling connection between peripheral and central, e.g. keep each other from suspend state
    /// - Characteristic UUID is randomly generated V4 UUIDs that has been tested for uniqueness by conducting web searches to ensure it returns no results.
    public static var iosSignalCharacteristicUUID = CBUUID(string: "0eb0d5f2-eae4-4a9a-8af3-a4adb02d4363")
    /// Primary payload characteristic (read) for distributing payload data from peripheral to central, e.g. identity data
    /// - Characteristic UUID is randomly generated V4 UUIDs that has been tested for uniqueness by conducting web searches to ensure it returns no results.
    public static var payloadCharacteristicUUID = CBUUID(string: "3e98c0f8-8f05-4829-a121-43e38f8933e7")
    public static var legacyPayloadCharacteristicUUID : CBUUID? = nil
    /// Legacy characteristic. E.g. could be set to: CBMutableCharacteristic(type: BLESensorConfiguration.legacyPayloadCharacteristicUUID, properties: [.read, .write, .writeWithoutResponse], value: nil, permissions: [.readable, .writeable])
    public static var legacyPayloadCharacteristic : CBMutableCharacteristic? = nil
    /// Manufacturer data is being used on Android to store pseudo device address
    /// - Pending update to dedicated ID
    public static var manufacturerIdForSensor = UInt16(65530)

    // MARK:- BLE signal characteristic action codes
    
    /// Signal characteristic action code for write payload, expect 1 byte action code followed by 2 byte little-endian Int16 integer value for payload data length, then payload data
    public static var signalCharacteristicActionWritePayload = UInt8(1)
    /// Signal characteristic action code for write RSSI, expect 1 byte action code followed by 4 byte little-endian Int32 integer value for RSSI value
    public static var signalCharacteristicActionWriteRSSI = UInt8(2)
    /// Signal characteristic action code for write payload, expect 1 byte action code followed by 2 byte little-endian Int16 integer value for payload sharing data length, then payload sharing data
    public static var signalCharacteristicActionWritePayloadSharing = UInt8(3)
    /// Signal characteristic action code for arbitrary immediate write
    public static var signalCharacteristicActionWriteImmediate = UInt8(4)

    // MARK:- BLE event timing
    
    /// Time delay between notifications for subscribers.
    public static var notificationDelay = DispatchTimeInterval.seconds(2)
    /// Time delay between advert restart
    public static var advertRestartTimeInterval = TimeInterval.hour
    /// Maximum number of concurrent BLE connections
    public static var concurrentConnectionQuota = 12
    /// Advert refresh time interval on Android devices
    public static var androidAdvertRefreshTimeInterval = TimeInterval.minute * 15
    /// Herald internal connection expiry timeout
    public static var connectionAttemptTimeout = TimeInterval(12)
    
    // MARK:- Venue check-in configuration
    /// The amount of time after which a diary venue event will stay in the log file (may be shown in the UI as 'pending' before this limit)
    public static var venueCheckInTimeLimit = TimeInterval.minute * 2
    /// The amount of time after which a venue presence diary event will be said to have been finished
    public static var venueCheckOutTimeLimit = TimeInterval.minute * 5
    // TODO consider a variable 'sensitivity' RSSI slider here, local to this person, as a preference
    /// The default number of days to save venue diary visits for, set by preference of the user. May be nil (no limit) or 0 (don't record anything, ever)
    public static var venueDiaryDefaultRecordingDays : UInt8? = 31
    /// If sharing a venue diary (E.g. via email to contact tracers), the number of days by default to share. nil means all. 0 means none
    public static var venueDiaryDefaultShareDays : UInt8? = 14
    /// If sharing a venue diary (E.g. via email to contact tracers), the email address to send the diary to by default when 'share' is clicked
    public static var venueDiaryDefaultShareEmail : String? = nil
    
    // MARK:- App configurable BLE features

    /// Log level for BLESensor
    public static var logLevel: SensorLoggerLevel = .debug
    
    /// Are Location Permissions enabled in the app, and thus awake on screen on enabled
    public static var awakeOnLocationEnabled: Bool = true
    
    /// Payload update at regular intervals, in addition to default HERALD communication process.
    /// - Use this to enable regular payload reads according to app payload lifespan.
    /// - Set to .never to disable this function.
    /// - Payload updates are reported to SensorDelegate as didRead.
    /// - Setting take immediate effect, no need to restart BLESensor, can also be applied while BLESensor is active.
    public static var payloadDataUpdateTimeInterval = TimeInterval.never
    
    /// Filter duplicate payload data and suppress sensor(didRead:fromTarget) delegate calls
    /// - Set to .never to disable this feature
    /// - Set time interval N to filter duplicate payload data seen in last N seconds
    /// - Example : 60 means filter duplicates in last minute
    /// - Filters all occurrences of payload data from all targets
    public static var filterDuplicatePayloadData = TimeInterval.never

    /// Remove peripheral records that haven't been updated for some time.
    /// - Herald aims to maintain a regular "connection" to all peripherals to gather precise proximity and duration data for all peripheral records.
    /// - A regular connection in this context means frequent data sampling that may or may not require an actual connection.
    /// - For example, RSSI measurements are taken from adverts, thus do not require an active connection; even the connection on iOS is just an illusion for ease of understanding.
    /// - A peripheral record stops updating if the device has gone out of range, therefore the record can be deleted to reduce workload.
    /// - Upper bound : Set this value to iOS Bluetooth address rotation period (roughly 15 minutes) to maximise continuity when devices go out of range, then return back in range (connection resume period = 15 mins max).
    /// - Lower bound : Set this value to Android scan-process period (roughly 2 minutes) to minimise workload, but iOS connection resume will be more reliant on re-discovery (connection resume period = 2 mins or more dependent on external factors).
    /// - iOS-iOS connections may resume beyond the set interval value if the addresses have not changed, due to other mechanisms in Herald.
    public static var peripheralCleanInterval = TimeInterval.minute * 2
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
    // Record payload data to enable de-duplication
    private var didReadPayloadData: [PayloadData:Date] = [:]

    init(_ payloadDataSupplier: PayloadDataSupplier) {
        database = ConcreteBLEDatabase()
        transmitter = ConcreteBLETransmitter(queue: sensorQueue, delegateQueue: delegateQueue, database: database, payloadDataSupplier: payloadDataSupplier)
        receiver = ConcreteBLEReceiver(queue: sensorQueue, delegateQueue: delegateQueue, database: database, payloadDataSupplier: payloadDataSupplier)
        super.init()
        database.add(delegate: self)
    }
    
    func start() {
        logger.debug("start")
        receiver.start()
        // BLE receivers start on powerOn event, on status change the transmitter will be started.
        // This is to request permissions and turn on dialogs sequentially
    }

    func stop() {
        logger.debug("stop")
        transmitter.stop()
        receiver.stop()
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
    
    func immediateSendAll(data: Data) -> Bool {
        return receiver.immediateSendAll(data:data);
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
            // De-duplicate payload in recent time
            if BLESensorConfiguration.filterDuplicatePayloadData != .never {
                let removePayloadDataBefore = Date() - BLESensorConfiguration.filterDuplicatePayloadData
                let recentDidReadPayloadData = didReadPayloadData.filter({ $0.value >= removePayloadDataBefore })
                didReadPayloadData = recentDidReadPayloadData
                if let lastReportedAt = didReadPayloadData[payloadData] {
                    logger.debug("didRead, filtered duplicate (device=\(device.identifier),payloadData=\(payloadData.shortName),lastReportedAt=\(lastReportedAt.description))")
                    return
                }
                didReadPayloadData[payloadData] = Date()
            }
            // Notify delegates
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
