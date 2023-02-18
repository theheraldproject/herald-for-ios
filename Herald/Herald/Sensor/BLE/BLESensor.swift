//
//  BLESensor.swift
//
//  Copyright 2020-2023 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import CoreBluetooth
import CoreFoundation

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
    public static let legacyHeraldServiceUUID: CBUUID = CBUUID(string: "428132af-4746-42d3-801e-4572d65bfd9b")
    /// The legacy unregistered manufacturer ID that was used by Herald until Oct 2022
    public static let legacyHeraldManufacturerIdForSensor: UInt16 = UInt16(65530)
    /// Detect the old legacy (unregistered) 128 bit Herald service ID
    /// Since v2.1.0 (Oct 2022)
    /// Deprecated. Support will be removed by Oct 2023. May be changed to false by default before then.
    public static var legacyHeraldServiceDetectionEnabled: Bool = true
    
    /// The Service UUID (Short) used by Herald since v2.1.0 (Oct 2022)
    /// See legacyHeraldServiceDetectionEnabled and legacyHeraldServiceUUID for the prior service support
    public static let linuxFoundationServiceUUID: CBUUID = CBUUID(string: "0000FCF6-0000-1000-8000-00805F9B34FB")
    /// Manufacturer data is being used on Android to store pseudo device address
    /// - This is now the dedicated Linux Foundation manufacturer ID (decimal 1521, hex 0x05F1)
    /// See legacyHeraldManufacturerIdForSensor for previous version
    public static let linuxFoundationManufacturerIdForSensor: UInt16 = UInt16(1521) // aka 0x05F1
    
    /**
     * Enables detection of the current standard Herald service UUID.
     * Enabled by default
     * @since v2.2 February 2023
     */
    public static var standardHeraldServiceDetectionEnabled: Bool = true;
    
    /**
     * Enables advertising of the current standard Herald service UUID.
     * Enabled by default
     * @since v2.2 February 2023
     */
    public static var standardHeraldServiceAdvertisingEnabled: Bool = true;
    
    /// Signaling characteristic for controlling connection between peripheral and central, e.g. keep each other from suspend state
    /// - Characteristic UUID is randomly generated V4 UUIDs that has been tested for uniqueness by conducting web searches to ensure it returns no results.
    public static let androidSignalCharacteristicUUID: CBUUID = CBUUID(string: "f617b813-092e-437a-8324-e09a80821a11")
    /// Signaling characteristic for controlling connection between peripheral and central, e.g. keep each other from suspend state
    /// - Characteristic UUID is randomly generated V4 UUIDs that has been tested for uniqueness by conducting web searches to ensure it returns no results.
    public static let iosSignalCharacteristicUUID: CBUUID = CBUUID(string: "0eb0d5f2-eae4-4a9a-8af3-a4adb02d4363")
    /// Primary payload characteristic (read) for distributing payload data from peripheral to central, e.g. identity data
    /// - Characteristic UUID is randomly generated V4 UUIDs that has been tested for uniqueness by conducting web searches to ensure it returns no results.
    public static let payloadCharacteristicUUID: CBUUID = CBUUID(string: "3e98c0f8-8f05-4829-a121-43e38f8933e7")
    /// Secured Payload exchange registered UUID
    /// Since v2.1.0 (Not used until a future version TBD)
    public static let securedPayloadCharacteristicUUID: CBUUID = CBUUID(string: "ae9f88ca-6ea6-494d-bd3f-09ffa3380340")

    // MARK:- Custom Service UUID interoperability - Since v2.2
    /**
     * A custom service UUID to use for a Herald service. Required for custom apps (without Herald interop).
     *
     * @since v2.2 February 2023
     * @note Requires customHeraldServiceDetectionEnabled to be set to true to enable.
     */
    public static var customServiceUUID: CBUUID? = nil;
    /**
     * Whether to detect a custom service UUID. Disabled by default.
     * Doesn't affect advertising.
     * in preference to the default Linux Foundation Herald UUID if specified.
     * Only takes effect if customServiceUUID is set to a valid non-null UUID.
     *
     * @since v2.2 February 2023
     */
    public static var customServiceDetectionEnabled: Bool = false;
    /**
     * Whether to advertise using the main customServiceUUID instead of the standard Herald
     * Service UUID.
     *
     * @since v2.2 February 2023
     */
    public static var customServiceAdvertisingEnabled: Bool = false;
    /**
     * Additional UUIDs beyond just customServiceUUID to detect. Useful for 'legacy' custom
     * application detections. You do not have to include customServiceUUID in this list.
     *
     * @since v2.2 February 2023
     * @note Requires customHeraldServiceDetectionEnabled to be set to true to enable.
     */
    public static var customAdditionalServiceUUIDs: [CBUUID] = [];
    /**
     * The custom manufacturer ID to use. Note this MUST be a Bluetooth SIG registered ID to
     * ensure there is no interference.
     * Note that if this is not specified, then the default Linux Foundation Herald service
     * manufacturer ID will be used.
     *
     * @since v2.2 February 2023
     * @note Requires customHeraldServiceDetectionEnabled to be set to true to enable.
     * @note Requires pseudoDeviceAddress to be enabled.
     */
    static var customManufacturerIdForSensor: Int = 0;
    
    // MARK:- Interoperability with OpenTrace

    /// OpenTrace service UUID, characteristic UUID, and manufacturer ID
    /// - Enables capture of OpenTrace payloads, e.g. for transition to HERALD
    /// - HERALD will discover devices advertising OpenTrace service UUID (can be the same as HERALD service UUID)
    /// - HERALD will search for OpenTrace characteristic, write payload of self to target,
    ///   read payload from target, and capture payload written to self by target.
    /// - HERALD will read/write payload from/to OpenTrace at regular intervals if update time
    ///   interval is not .never. Tests have confirmed that using this feature, instead of relying
    ///   solely on OpenTrace advert updates on idle Android and iOS devices offers more
    ///   regular measurements for OpenTrace.
    /// - OpenTrace payloads will be reported via SensorDelegate:didRead where the payload
    ///   has type LegacyPayloadData, and service will be the OpenTrace characteristic UUID.
    /// - Set interopOpenTraceEnabled = false to disable feature
    public static var interopOpenTraceEnabled: Bool = false
    public static var interopOpenTraceServiceUUID: CBUUID = CBUUID(string: "A6BA4286-C550-4794-A888-9467EF0B31A8")
    public static var interopOpenTracePayloadCharacteristicUUID: CBUUID  = CBUUID(string: "D1034710-B11E-42F2-BCA3-F481177D5BB2")
    public static var interopOpenTraceManufacturerId: UInt16 = UInt16(1023)
    public static var interopOpenTracePayloadDataUpdateTimeInterval: TimeInterval = TimeInterval.minute * 5


    // MARK:- Interoperability with Advert based protocols

    /// Advert based protocol service UUID, service data key
    /// - Enable capture of advert based protocol payloads, e.g. for transition to HERALD
    /// - HERALD will discover devices advertising protocol service UUID (can be the same as HERALD service UUID)
    /// - HERALD will parse service data to read payload from target
    /// - Protocol payloads will be reported via SensorDelegate:didRead where the payload
    ///   has type LegacyPayloadData, and service will be the protocol service UUID.
    /// - Set interopAdvertBasedProtocolEnabled = false to disable feature
    /// - Scan for 16-bit service UUID by setting the value xxxx in base UUID 0000xxxx-0000-1000-8000-00805F9B34FB
    public static var interopAdvertBasedProtocolEnabled: Bool = false
    public static var interopAdvertBasedProtocolServiceUUID: CBUUID = CBUUID(string: "0000FD6F-0000-1000-8000-00805F9B34FB")
    public static var interopAdvertBasedProtocolServiceDataKey: CBUUID = CBUUID(string: "FD6F")

    
    // MARK:- BLE signal characteristic action codes
    
    /// Signal characteristic action code for write payload, expect 1 byte action code followed by 2 byte little-endian Int16 integer value for payload data length, then payload data
    public static let signalCharacteristicActionWritePayload: UInt8 = UInt8(1)
    /// Signal characteristic action code for write RSSI, expect 1 byte action code followed by 4 byte little-endian Int32 integer value for RSSI value
    public static let signalCharacteristicActionWriteRSSI: UInt8 = UInt8(2)
    /// Signal characteristic action code for write payload, expect 1 byte action code followed by 2 byte little-endian Int16 integer value for payload sharing data length, then payload sharing data
    public static let signalCharacteristicActionWritePayloadSharing: UInt8 = UInt8(3)
    /// Signal characteristic action code for arbitrary immediate write
    public static let signalCharacteristicActionWriteImmediate: UInt8 = UInt8(4)

    // MARK:- BLE event timing
    
    /// Time delay between notifications for subscribers.
    public static var notificationDelay: DispatchTimeInterval = DispatchTimeInterval.seconds(2)
    /// Time delay between advert restart
    public static var advertRestartTimeInterval: TimeInterval = TimeInterval.hour
    /// Maximum number of concurrent BLE connections
    public static var concurrentConnectionQuota: Int = 12
    /// Advert refresh time interval on Android devices
    public static var androidAdvertRefreshTimeInterval: TimeInterval = TimeInterval.minute * 15
    /// Herald internal connection expiry timeout
    public static var connectionAttemptTimeout: TimeInterval = TimeInterval(12)
    
    // MARK:- Venue check-in configuration
    /// The amount of time after which a diary venue event will stay in the log file (may be shown in the UI as 'pending' before this limit)
    public static var venueCheckInTimeLimit: TimeInterval = TimeInterval.minute * 2
    /// The amount of time after which a venue presence diary event will be said to have been finished
    public static var venueCheckOutTimeLimit: TimeInterval = TimeInterval.minute * 5
    // TODO consider a variable 'sensitivity' RSSI slider here, local to this person, as a preference
    /// The default number of days to save venue diary visits for, set by preference of the user. May be nil (no limit) or 0 (don't record anything, ever)
    public static var venueDiaryDefaultRecordingDays: UInt8? = 31
    /// If sharing a venue diary (E.g. via email to contact tracers), the number of days by default to share. nil means all. 0 means none
    public static var venueDiaryDefaultShareDays: UInt8? = 14
    /// If sharing a venue diary (E.g. via email to contact tracers), the email address to send the diary to by default when 'share' is clicked
    public static var venueDiaryDefaultShareEmail: String? = nil
    
    // MARK:- App configurable BLE features

    /// Log level for BLESensor
    public static var logLevel: SensorLoggerLevel = .debug
    
    /// Mobility sensor for estimating range of travel without recording location
    /// - Use this for prioritising positive cases that may have spread the disease over significant distances
    /// - Enabling location permission also has the benefit of enabling  awake on screen for iOS-iOS background detection
    /// - Set to nil to disable sensor, set to distance in metres to enable sensor for mobility sensing at given resolution.
    public static var mobilitySensorEnabled: Distance? = ConcreteMobilitySensor.minimumResolution
    
    /// Payload update at regular intervals, in addition to default HERALD communication process.
    /// - Use this to enable regular payload reads according to app payload lifespan.
    /// - Set to .never to disable this function.
    /// - Payload updates are reported to SensorDelegate as didRead.
    /// - Setting take immediate effect, no need to restart BLESensor, can also be applied while BLESensor is active.
    public static var payloadDataUpdateTimeInterval: TimeInterval = TimeInterval.never
    
    /// Filter duplicate payload data and suppress sensor(didRead:fromTarget) delegate calls
    /// - Set to .never to disable this feature
    /// - Set time interval N to filter duplicate payload data seen in last N seconds
    /// - Example : 60 means filter duplicates in last minute
    /// - Filters all occurrences of payload data from all targets
    public static var filterDuplicatePayloadData: TimeInterval = TimeInterval.never

    /// Remove peripheral records that haven't been updated for some time.
    /// - Herald aims to maintain a regular "connection" to all peripherals to gather precise proximity and duration data for all peripheral records.
    /// - A regular connection in this context means frequent data sampling that may or may not require an actual connection.
    /// - For example, RSSI measurements are taken from adverts, thus do not require an active connection; even the connection on iOS is just an illusion for ease of understanding.
    /// - A peripheral record stops updating if the device has gone out of range, therefore the record can be deleted to reduce workload.
    /// - Upper bound : Set this value to iOS Bluetooth address rotation period (roughly 15 minutes) to maximise continuity when devices go out of range, then return back in range (connection resume period = 15 mins max).
    /// - Lower bound : Set this value to Android scan-process period (roughly 2 minutes) to minimise workload, but iOS connection resume will be more reliant on re-discovery (connection resume period = 2 mins or more dependent on external factors).
    /// - iOS-iOS connections may resume beyond the set interval value if the addresses have not changed, due to other mechanisms in Herald.
    /// - Default changed to 30 minutes in V2.2 to reflect better Android lifecycle management
    public static var peripheralCleanInterval: TimeInterval = TimeInterval.minute * 30
    
    /// Enable inertia sensor
    /// - Inertia sensor (accelerometer) measures acceleration in meters per second (m/s) along device X, Y and Z axis
    /// - Generates SensorDelegate:didVisit callbacks with InertiaLocationReference data
    /// - Set to false to disable sensor, and true value to enable sensor
    /// - This is used for automated capture of RSSI at different distances, where the didVisit data is used as markers
    public static var inertiaSensorEnabled: Bool = false
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
    
    public func coordinationProvider() -> CoordinationProvider? {
        // ConcreteBLESensor does not have a coordination provider
        return nil
    }
    
    func start() {
        logger.debug("start")
        receiver.start()
        transmitter.start()
    }

    func stop() {
        logger.debug("stop")
        transmitter.stop()
        receiver.stop()
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
                // Confirm it's a Herald Payload device (didDeleteOrDetect)
                self.delegates.forEach { $0.sensor(.BLE, available: true, didDeleteOrDetect: device.identifier) }
                // Now share that payload
                self.delegates.forEach { $0.sensor(.BLE, didRead: payloadData, fromTarget: device.identifier) }
            }
        default:
            return
        }
    }
    
    func bleDatabase(didDelete device: BLEDevice) {
        logger.debug("didDelete(device=\(device.identifier),payloadData=\(device.payloadData?.shortName ?? "nil"))")
        delegateQueue.async {
            self.delegates.forEach { $0.sensor(.BLE, available: false, didDeleteOrDetect: device.identifier) }
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
