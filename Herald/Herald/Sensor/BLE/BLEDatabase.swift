//
//  BLEDatabase.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import CoreBluetooth

/// Registry for collating fragments of information from asynchronous BLE operations.
protocol BLEDatabase {
    
    /// Add delegate for handling database events
    func add(delegate: BLEDatabaseDelegate)
    
    /// Get or create device for collating information from asynchronous BLE operations.
    func device(_ identifier: TargetIdentifier) -> BLEDevice

    /// Get or create device for collating information from asynchronous BLE operations.
    func device(_ peripheral: CBPeripheral, delegate: CBPeripheralDelegate) -> BLEDevice

    /// Get or create device for collating information from asynchronous BLE operations.
    func device(_ peripheral: CBPeripheral, advertisementData: [String : Any], delegate: CBPeripheralDelegate) -> BLEDevice
    
    /// Get or create device for collating information from asynchronous BLE operations.
    func device(_ payload: PayloadData) -> BLEDevice
    
    /// Get if a device exists
    func hasDevice(_ payload: PayloadData) -> Bool
    
    /// Print all devices to a log file (if debug enabled)
    func printDevices()

    /// Get all devices
    func devices() -> [BLEDevice]
    
    /// Delete device's (non functional) peripheral, and if no peripherals are left, delete the device
    func delete(_ device: BLEDevice, peripheral: CBPeripheral)
    
    /// Delete device from database
    func delete(_ device: BLEDevice)
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
    
    func printDevices() {
        logger.debug("devices - Printing all BLE Devices:-")
        database.values.forEach({
            // Print each one out so we can see actual contents over time
            logger.debug("devices - print (device=\($0))")
        })
    }
    
    func devices() -> [BLEDevice] {
        return Array(Set(database.values))
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
    
    func deviceByPeripheralUUID(_ uuid: UUID) -> BLEDevice? {
        for device in database {
            for id in device.value.peripheralIDs {
                if id.id == uuid {
                    return device.value;
                }
            }
        }
        logger.debug("deviceByPeripheralUUID(uuid=\(uuid.uuidString) - not found")
        return nil;
    }
    
    func deviceByPeripheral(_ peripheral: CBPeripheral) -> BLEDevice? {
        return deviceByPeripheralUUID(peripheral.identifier)
    }

    func device(_ peripheral: CBPeripheral, delegate: CBPeripheralDelegate) -> BLEDevice {
        // Since v2.1.0 - multi peripheral ID support - loop through all BLEDevice and check the LIST of peripheral IDs
        let deviceLookup = deviceByPeripheral(peripheral)
        if let device = deviceLookup {
            // return this device
            return device;
        }
        
        // create new device
        let identifier = TargetIdentifier(UUID().uuidString)
        let device = BLEDevice(identifier, delegate: self)
        database[identifier] = device
        queue.async {
            self.logger.debug("create (device=\(identifier))")
            self.delegates.forEach { $0.bleDatabase(didCreate: device) }
        }
        device.addPeripheralID(peripheral, when: Date())
        peripheral.delegate = delegate
        return device
        
//
////        let identifier = TargetIdentifier(peripheral: peripheral)
//        if database[identifier] == nil {
//            let device = BLEDevice(identifier, delegate: self)
//            database[identifier] = device
//            queue.async {
//                self.logger.debug("create (device=\(identifier))")
//                self.delegates.forEach { $0.bleDatabase(didCreate: device) }
//            }
//        }
//        let device = database[identifier]!
//        if device.peripheral != peripheral {
//            device.peripheral = peripheral
//            peripheral.delegate = delegate
//        }
//        return device
    }
    
    func device(_ peripheral: CBPeripheral, advertisementData: [String : Any], delegate: CBPeripheralDelegate) -> BLEDevice {
        
        let pseudoDeviceAddress = BLEPseudoDeviceAddress(fromAdvertisementData: advertisementData)
        
        // Since v2.1.0-beta we now loop through all BLEDevice and check the LIST of peripheral IDs
        let deviceLookup = deviceByPeripheral(peripheral)
        if let device = deviceLookup {
            // Update advertisement data if it has changed!
            logger.debug("device(peripheral,advertData) - found device, returning")
            
            // Ensure we write pseudoDeviceAddress if the device is already known by peripheralID
            // This is so when it's physical address rotates, the next part of this function can find it again
            // - this in turn prevents a re-read of the Herald identifier, reducing Bluetooth traffic
            if let pda = pseudoDeviceAddress {
                logger.debug("device(peripheral,advertData) - updating pseudoDeviceAddress and OS before returning")
                if device.operatingSystem != .android {
                    device.operatingSystem = .android
                }
                device.pseudoDeviceAddress = pda
            }
            
            // update lastSeen!
            device.updateLastSeen(peripheral: peripheral, when: Date())
            // return this device
            return device;
        }
        logger.debug("device(peripheral,advertData) - NOT found device, checking pseudoDeviceAddress")
        
        
//        // Get device by target identifier
//        let identifier = TargetIdentifier(peripheral: peripheral)
//        if let device = database[identifier] {
//            return device
//        }
        // Get device by pseudo device address
        if let pda = pseudoDeviceAddress {
            // Reuse existing Android device
            if let device = devices().filter({ pda.address == $0.pseudoDeviceAddress?.address }).first {
                // Update identifier first, and don't create a duplicate record
//                database[device.identifier] = nil
//                device.identifier = identifier
//                // Now add the corrected record
//                database[identifier] = device
//
//                // Now fix the record's peripheral, if required
//                if device.peripheral != peripheral {
//                    device.peripheral = peripheral
//                    peripheral.delegate = delegate
//                }
                // To get here the peripheral ID must have changed, but it is showing the same pseudo device
                // address in the manufacturer data area
                device.addPeripheralID(peripheral, when: Date())
                if device.operatingSystem != .android {
                    device.operatingSystem = .android
                }
                logger.debug("updateAddress (device=\(device))")
                return device
            }
            // Create new Android device with this pseudoDeviceAddress
            else {
                logger.debug("device(peripheral,advertData) - New Device found with a new pseudoDeviceAddress - creating new device with pseudoDeviceAddress")
                let newDevice = device(peripheral, delegate: delegate)
                newDevice.pseudoDeviceAddress = pseudoDeviceAddress
                newDevice.operatingSystem = .android
                return newDevice
            }
        }
        logger.debug("device(peripheral,advertData) - New Device doesn't have pseudoDeviceAddress - creating new blank device")
        // Create new device without pseudoDeviceAddress
        return device(peripheral, delegate: delegate)
    }
    
    // The below should never be called - ConcreteBLEReceiver calls device (peripheral,delegate) instead
    // So the below should only be called for PseudoRandom data from Android devices with fake temp IDs?
    func device(_ payload: PayloadData) -> BLEDevice {
        logger.debug("device FOR PAYLOAD ONLY (payload=\(payload))")
        if let device = database.values.filter({ $0.payloadData == payload }).first {
            return device
        }
        logger.debug("device FOR PAYLOAD ONLY - PAYLOAD NOT FOUND, GENERATING TEMP UUID (payload=\(payload))")
        // Create temporary UUID, the taskRemoveDuplicatePeripherals function
        // will delete this when a direct connection to the peripheral has been
        // established
        // Since v2.1.0-beta4 we don't create temporary devices, we just append data to existing devices
        let identifier = TargetIdentifier(UUID().uuidString)
        let newDevice = device(identifier)
        newDevice.payloadData = payload
        return newDevice
    }
    
    func hasDevice(_ payload: PayloadData) -> Bool {
        if database.values.filter({ $0.payloadData == payload }).first != nil {
            return true
        }
        return false
    }
    
    func delete(_ device: BLEDevice, peripheral: CBPeripheral) {
        let initialCount = device.peripheralIDs.count
        device.peripheralIDs = device.peripheralIDs.filter({ $0.peripheral != peripheral })
        if device.peripheralIDs.count < initialCount {
            device.lastUpdatedAt = Date()
        }
        if !device.hasPeripheral() {
            // delete whole device
            delete(device)
        }
    }

    func delete(_ device: BLEDevice) {
        
        // Note: Since v2.1.0-beta4, we should specify peripheral as well to ensure we only delete when absolutely necessary
        
        let identifiers = database.keys.filter({ database[$0] == device })
        guard !identifiers.isEmpty else {
            return
        }
        identifiers.forEach({ database[$0] = nil })
        queue.async {
            self.logger.debug("delete (device=\(device),identifiers=\(identifiers.count))")
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

public class BLEDeviceID {
    var id: UUID
    var peripheral: CBPeripheral
    var lastSeen: Date
    
    init(_ newPeripheral:CBPeripheral, seen: Date) {
        id = newPeripheral.identifier
        peripheral = newPeripheral
        lastSeen = seen
    }
}

// MARK:- BLEDatabase data

public class BLEDevice : Device {
    /// Last time a wake up call was received from this device (iOS only)
    var lastNotifiedAt: Date = Date.distantPast
    /// Pseudo device address for tracking devices that change device identifier constantly like the Samsung A10, A20 and Note 8
    var pseudoDeviceAddress: BLEPseudoDeviceAddress? {
        didSet {
            lastUpdatedAt = Date()
        }}
    /// Apple Core Bluetooth Peripheral ID and date last seen pairs - note since iOS v15.1 it's likely all devices (Android or iOS) have TWO of these even if only one actual Bluetooth MAC address is advertised
    var peripheralIDs: [BLEDeviceID] = []
    /// Delegate for listening to attribute updates events.
    let delegate: BLEDeviceDelegate
    /// CoreBluetooth peripheral object for interacting with this device.
//    var peripheral: CBPeripheral? {
//        didSet {
//            lastUpdatedAt = Date()
//            delegate.device(self, didUpdate: .peripheral)
//        }}
    /// Service characteristic for signalling between BLE devices, e.g. to keep awake
    var signalCharacteristic: CBCharacteristic? {
        didSet {
            if signalCharacteristic != nil {
                lastUpdatedAt = Date()
            }
            delegate.device(self, didUpdate: .signalCharacteristic)
        }}
    /// Service characteristic for reading payload data
    var payloadCharacteristic: CBCharacteristic? {
        didSet {
            if payloadCharacteristic != nil {
                lastUpdatedAt = Date()
            }
            delegate.device(self, didUpdate: .payloadCharacteristic)
        }}
    var legacyPayloadCharacteristic: CBCharacteristic? {
        didSet {
            if legacyPayloadCharacteristic != nil {
                lastUpdatedAt = Date()
            }
            delegate.device(self, didUpdate: .payloadCharacteristic)
        }}
    /// Device operating system, this is necessary for selecting different interaction procedures for each platform.
    var operatingSystem: BLEDeviceOperatingSystem = .unknown {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .operatingSystem)
        }}
    /// Device is receive only, this is necessary for filtering payload sharing data
    var receiveOnly: Bool = false {
        didSet {
            lastUpdatedAt = Date()
        }}
    /// Payload data acquired from the device via payloadCharacteristic read
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
    /// Most recent RSSI measurement taken by readRSSI or didDiscover.
    public var rssi: BLE_RSSI? {
        didSet {
            lastUpdatedAt = Date()
            rssiLastUpdatedAt = lastUpdatedAt
            delegate.device(self, didUpdate: .rssi)
        }}
    /// RSSI last update timestamp, this is used to track last advertised at without relying on didDiscover
    var rssiLastUpdatedAt: Date = Date.distantPast
    /// Transmit power data where available (only provided by Android devices)
    public var txPower: BLE_TxPower? {
        didSet {
            lastUpdatedAt = Date()
            delegate.device(self, didUpdate: .txPower)
        }}
    /// Transmit power as calibration data
    var calibration: Calibration? { get {
        guard let txPower = txPower else {
            return nil
        }
        return Calibration(unit: .BLETransmitPower, value: Double(txPower))
    }}
    /// Track discovered at timestamp, used by taskConnect to prioritise connection when device runs out of concurrent connection capacity
    var lastDiscoveredAt: Date = Date.distantPast
    /// Track Herald initiated connection attempts - workaround for iOS peripheral caching incorrect state bug
    var lastConnectionInitiationAttempt: Date?
    /// Count the number of failed connection attempts since forced disconnect
    var failedConnectionAttempts: Int = 0
    /// Progressive backoff and jitter requires a don't connect until time
    var onlyConnectAfter: Date = Date()
    /// Track connect request at timestamp, used by taskConnect to prioritise connection when device runs out of concurrent connection capacity
    var lastConnectRequestedAt: Date = Date.distantPast
    /// Track connected at timestamp, used by taskConnect to prioritise connection when device runs out of concurrent connection capacity
    var lastConnectedAt: Date? {
        didSet {
            // Reset lastDisconnectedAt
            lastDisconnectedAt = nil
            // Reset lastConnectionInitiationAttempt
            lastConnectionInitiationAttempt = nil
        }}
    /// Track read payload request at timestamp, used by readPayload to de-duplicate requests from asynchronous calls
    var lastReadPayloadRequestedAt: Date = Date.distantPast
    /// Track disconnected at timestamp, used by taskConnect to prioritise connection when device runs out of concurrent connection capacity
    var lastDisconnectedAt: Date? {
        didSet {
            // Reset lastConnectionInitiationAttempt
            lastConnectionInitiationAttempt = nil
        }
    }
    /// Last advert timestamp, inferred from payloadDataLastUpdatedAt, payloadSharingDataLastUpdatedAt, rssiLastUpdatedAt
    var lastAdvertAt: Date { get {
            max(createdAt, lastDiscoveredAt, payloadDataLastUpdatedAt, rssiLastUpdatedAt)
        }}
    
    /// Time interval since created at timestamp
    var timeIntervalSinceCreated: TimeInterval { get {
            Date().timeIntervalSince(createdAt)
        }}
    /// Time interval since last attribute value update, this is used to identify devices that may have expired and should be removed from the database.
    var timeIntervalSinceLastUpdate: TimeInterval { get {
            Date().timeIntervalSince(lastUpdatedAt)
        }}
    /// Time interval since last payload data update, this is used to identify devices that require a payload update.
    var timeIntervalSinceLastPayloadDataUpdate: TimeInterval { get {
            Date().timeIntervalSince(payloadDataLastUpdatedAt)
        }}
    /// Time interval since last advert detected, this is used to detect concurrent connection quota and prioritise disconnections
    var timeIntervalSinceLastAdvert: TimeInterval { get {
        Date().timeIntervalSince(lastAdvertAt)
        }}
    /// Time interval between last connection request, this is used to priortise disconnections
    var timeIntervalSinceLastConnectRequestedAt: TimeInterval { get {
        Date().timeIntervalSince(lastConnectRequestedAt)
        }}
    /// Time interval between last connected at and last advert, this is used to estimate last period of continuous tracking, to priortise disconnections
    var timeIntervalSinceLastDisconnectedAt: TimeInterval { get {
        guard let lastDisconnectedAt = lastDisconnectedAt else {
            return Date().timeIntervalSince(createdAt)
        }
        return Date().timeIntervalSince(lastDisconnectedAt)
        }}
    /// Time interval between last connected at and last advert, this is used to estimate last period of continuous tracking, to priortise disconnections
    var timeIntervalBetweenLastConnectedAndLastAdvert: TimeInterval { get {
        guard let lastConnectedAt = lastConnectedAt, lastAdvertAt > lastConnectedAt else {
            return TimeInterval(0)
        }
        return lastAdvertAt.timeIntervalSince(lastConnectedAt)
        }}
    /// Protocol is OpenTrace only
    var protocolIsOpenTrace: Bool { get {
        return legacyPayloadCharacteristic != nil && signalCharacteristic == nil && payloadCharacteristic == nil
    }}
    /// Protocol is Herald, potentially with optional support for OpenTrace
    var protocolIsHerald: Bool { get {
        return signalCharacteristic != nil && payloadCharacteristic != nil
    }}
    
    public override var description: String { get {
        return "BLEDevice[id=\(identifier),os=\(operatingSystem.rawValue),payload=\(payloadData?.shortName ?? "nil"),address=\(pseudoDeviceAddress?.data.base64EncodedString() ?? "nil"),physicalAddressCount=\(peripheralIDs.count)]"
    }}
    
    init(_ identifier: TargetIdentifier, delegate: BLEDeviceDelegate) {
        self.delegate = delegate
        super.init(identifier);
    }
    
    func addPeripheralID(_ peripheral: CBPeripheral, when: Date) {
        peripheralIDs.append(BLEDeviceID(peripheral, seen: when))
//        if (peripheralIDs.count > 1) {
            // Slightly redundant, but ensures we call the didUpdate method
            updateLastSeen(peripheral: peripheral, when: when)
//        }
    }
    
    func matchingPeripheral(_ peripheral: CBPeripheral) -> CBPeripheral? {
        for id in peripheralIDs {
            if id.peripheral == peripheral {
                return id.peripheral
            }
        }
        return nil        
    }
    
    func connectedPeripheral() -> CBPeripheral? {
        for id in peripheralIDs {
            if id.peripheral.state == .connected {
                return id.peripheral
            }
        }
        return nil
    }
    
    func hasPeripheral() -> Bool {
        return peripheralIDs.count > 0
    }
    
    func hasConnectedPeripheral() -> Bool {
        for id in peripheralIDs {
            if id.peripheral.state == .connected {
                return true;
            }
        }
        return false
    }
    
    func mostRecentPeripheral() -> CBPeripheral? {
        var peripheral: CBPeripheral?
        var latest: Date = Date.distantPast
        
        for id in peripheralIDs {
            if id.lastSeen > latest {
                latest = id.lastSeen
                peripheral = id.peripheral
            }
        }
        
        return peripheral
    }
    
    func updateLastSeen(peripheral: CBPeripheral, when: Date) {
        for id in peripheralIDs {
            if id.id == peripheral.identifier {
                id.lastSeen = when
                
                lastUpdatedAt = Date()
                delegate.device(self, didUpdate: .peripheral)
                
                return
            }
        }
    }
}

protocol BLEDeviceDelegate {
    func device(_ device: BLEDevice, didUpdate attribute: BLEDeviceAttribute)
}

enum BLEDeviceAttribute : String {
    case peripheral, signalCharacteristic, payloadCharacteristic, payloadSharingCharacteristic, operatingSystem, payloadData, rssi, txPower
}

enum BLEDeviceOperatingSystem : String {
    case android, ios, restored, unknown, shared
}

/// RSSI in dBm.
public typealias BLE_RSSI = Int

public typealias BLE_TxPower = Int

class BLEPseudoDeviceAddress {
    let address: Int64
    let data: Data
    var description: String { get {
        return "BLEPseudoDeviceAddress(address=\(address),data=\(data.base64EncodedString()))"
        }}
    
    init(value: Int64) {
        data = BLEPseudoDeviceAddress.encode(value)
        // Decode is guaranteed to be successful because the data was encoded by itself
        address = BLEPseudoDeviceAddress.decode(data)!
    }
    
    init?(data: Data) {
        guard data.count == 6, let value = BLEPseudoDeviceAddress.decode(data) else {
            return nil
        }
        address = value
        self.data = BLEPseudoDeviceAddress.encode(address)
    }
    
    convenience init?(fromAdvertisementData: [String: Any]) {
        guard let manufacturerData = fromAdvertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else {
            return nil
        }
        guard let manufacturerId = manufacturerData.uint16(0) else {
            return nil
        }
        // HERALD pseudo device address
        if (manufacturerId == BLESensorConfiguration.linuxFoundationManufacturerIdForSensor ||
             (BLESensorConfiguration.legacyHeraldServiceDetectionEnabled && manufacturerId == BLESensorConfiguration.legacyHeraldManufacturerIdForSensor)
           ) && manufacturerData.count == 8 {
            self.init(data: Data(manufacturerData.subdata(in: 2..<8)))
        }
        // Legacy pseudo device address
        else if BLESensorConfiguration.interopOpenTraceEnabled, manufacturerId == BLESensorConfiguration.interopOpenTraceManufacturerId, manufacturerData.count > 2 {
            var addressData = Data(manufacturerData.subdata(in: 2..<min(8, manufacturerData.count)))
            if addressData.count < 6 {
                addressData.append(Data(repeating: 0, count: 6 - addressData.count))
            }
            self.init(data: addressData)
        }
        // Pseudo device address not detected
        else {
            return nil
        }
    }

    private static func encode(_ value: Int64) -> Data {
        var data = Data()
        data.append(value)
        return Data(data.subdata(in: 2..<8))
    }

    private static func decode(_ data: Data) -> Int64? {
        var decoded = Data(repeating: 0, count: 2)
        decoded.append(data)
        return decoded.int64(0)
    }
}


/// Legacy advert only protocol data extracted from service data
class BLELegacyAdvertOnlyProtocolData {
    let service: UUID
    let connectable: Bool
    let data: Data // BIG ENDIAN (network order) AT THIS POINT
    var description: String { get {
        return "BLELegacyAdvertOnlyProtocolData(service=\(service.uuidString),connectable=\(connectable.description),data=\(data.base64EncodedString()))"
        }}
    var payloadData: LegacyPayloadData { get {
        return LegacyPayloadData(service: service, data: data)
    }}
    
    init?(fromAdvertisementData: [String: Any]) {
        // Interoperability is enabled
        guard BLESensorConfiguration.interopAdvertBasedProtocolEnabled else {
            return nil
        }
        // Get service data
        guard let serviceDataDictionary = fromAdvertisementData[CBAdvertisementDataServiceDataKey] as? [CBUUID:NSData] else {
            return nil
        }
        // Advert only protocol is not connectable
        guard let isConnectableValue = fromAdvertisementData[CBAdvertisementDataIsConnectable] as? NSNumber else {
            return nil
        }
        self.connectable = (isConnectableValue != 0)
        // Extract data for specific service data key
        guard let service = UUID(uuidString: BLESensorConfiguration.interopAdvertBasedProtocolServiceUUID.uuidString),
              let serviceData = serviceDataDictionary[BLESensorConfiguration.interopAdvertBasedProtocolServiceDataKey] as Data?,
              serviceData.count > 0 else {
            return nil
        }
        self.service = service
        self.data = serviceData
    }
}
