//
//  BLETransmitter.swift
//  C19X-SENSOR-iOS
//
//  Created by Freddy Choi on 25/07/2020.
//  Copyright © 2020 C19X. All rights reserved.
//

import Foundation
import CoreBluetooth

/**
 Beacon transmitter broadcasts a fixed service UUID to enable background scan by iOS. When iOS
 enters background mode, the UUID will disappear from the broadcast, so Android devices need to
 search for Apple devices and then connect and discover services to read the UUID.
*/
protocol BLETransmitter : Sensor {
}

/**
 Transmitter offers three services:
 1. Signal characteristic for maintaining connection between iOS devices and also enable non-transmitting Android devices (receive only,
 like the Samsung J6) to make their presence known by writing their beacon code and RSSI as data to this characteristic.
 2. Payload characteristic for publishing beacon identity data.
 3. Payload sharing characteristic for publishing beacon identity data recently acquired by this beacon.
 
 Keeping the transmitter and receiver working in iOS background mode is a major challenge, in particular when both
 iOS devices are in background mode. The transmitter on iOS offers a notifying beacon characteristic that is triggered
 by writing anything to the characteristic. On characteristic write, the transmitter will call updateValue after 8 seconds
 to notify the receivers, to wake up the receivers with a didUpdateValueFor call. The process can repeat as a loop
 between the transmitter and receiver to keep both devices awake. This is unnecessary for Android-Android and also
 Android-iOS and iOS-Android detection, which can rely solely on scanForPeripherals for detection.
 
 The notification based wake up method relies on an open connection which seems to be fine for iOS but may cause
 problems for Android. Experiments have found that Android devices cannot accept new connections (without explicit
 disconnect) indefinitely and the bluetooth stack ceases to function after around 500 open connections. The device
 will need to be rebooted to recover. However, if each connection is disconnected, the bluetooth stack can work
 indefinitely, but frequent connect and disconnect can still cause the same problem. The recommendation is to
 (1) always disconnect from Android as soon as the work is complete, (2) minimise the number of connections to
 an Android device, and (3) maximise time interval between connections. With all these in mind, the transmitter
 on Android does not support notify and also a connect is only performed on first contact to get the bacon code.
 */
class ConcreteBLETransmitter : NSObject, BLETransmitter, CBPeripheralManagerDelegate {
    private let logger = ConcreteLogger(subsystem: "Sensor", category: "BLE.ConcreteBLETransmitter")
    private var delegates: [SensorDelegate] = []
    /// Dedicated sequential queue for all beacon transmitter and receiver tasks.
    private let queue: DispatchQueue
    private let database: BLEDatabase
    /// Beacon code generator for creating cryptographically secure public codes that can be later used for on-device matching.
    private let payloadDataSupplier: PayloadDataSupplier
    /// Peripheral manager for managing all connections, using a single manager for simplicity.
    private var peripheral: CBPeripheralManager!
    /// Beacon service and characteristics being broadcasted by the transmitter.
    private var signalCharacteristic: CBMutableCharacteristic?
    private var payloadCharacteristic: CBMutableCharacteristic?
    private var payloadSharingCharacteristic: CBMutableCharacteristic?
    private var advertisingStartedAt: Date = Date.distantPast
    /// Dummy data for writing to the receivers to trigger state restoration or resume from suspend state to background state.
    private let emptyData = Data(repeating: 0, count: 0)
    /**
     Shifting timer for triggering notify for subscribers several seconds after resume from suspend state to background state,
     but before re-entering suspend state. The time limit is under 10 seconds as desribed in Apple documentation.
     */
    private var notifyTimer: DispatchSourceTimer?
    /// Dedicated sequential queue for the shifting timer.
    private let notifyTimerQueue = DispatchQueue(label: "Sensor.BLE.ConcreteBLETransmitter.Timer")

    /**
     Create a transmitter  that uses the same sequential dispatch queue as the receiver.
     Transmitter starts automatically when Bluetooth is enabled.
     */
    init(queue: DispatchQueue, database: BLEDatabase, payloadDataSupplier: PayloadDataSupplier) {
        self.queue = queue
        self.database = database
        self.payloadDataSupplier = payloadDataSupplier
        super.init()
        // Create a peripheral that supports state restoration
        self.peripheral = CBPeripheralManager(delegate: self, queue: queue, options: [
            CBPeripheralManagerOptionRestoreIdentifierKey : "Sensor.BLE.ConcreteBLETransmitter",
            CBPeripheralManagerOptionShowPowerAlertKey : true
        ])
    }
    
    func add(delegate: SensorDelegate) {
        delegates.append(delegate)
    }
    
    func start() {
        logger.debug("start")
        guard peripheral.state == .poweredOn else {
            logger.fault("start denied, not powered on")
            return
        }
        if signalCharacteristic != nil, payloadCharacteristic != nil, payloadSharingCharacteristic != nil {
            logger.debug("starting advert with existing characteristics")
            if !peripheral.isAdvertising {
                startAdvertising(withNewCharacteristics: false)
            } else {
                queue.async {
                    self.peripheral.stopAdvertising()
                    self.peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey : [BLESensorConfiguration.serviceUUID]])
                }
            }
            logger.debug("start successful, for existing characteristics")
        } else {
            startAdvertising(withNewCharacteristics: true)
            logger.debug("start successful, for new characteristics")
        }
        signalCharacteristic?.subscribedCentrals?.forEach() { central in
            // FEATURE : Symmetric connection on subscribe
            _ = database.device(central.identifier.uuidString)
        }
        notifySubscribers("start")
    }
    
    func stop() {
        logger.debug("stop")
        guard peripheral.isAdvertising else {
            logger.fault("stop denied, already stopped (source=%s)")
            return
        }
        stopAdvertising()
    }
    
    private func startAdvertising(withNewCharacteristics: Bool) {
        logger.debug("startAdvertising (withNewCharacteristics=\(withNewCharacteristics))")
        if withNewCharacteristics || signalCharacteristic == nil || payloadCharacteristic == nil || payloadSharingCharacteristic == nil{
            signalCharacteristic = CBMutableCharacteristic(type: BLESensorConfiguration.iosSignalCharacteristicUUID, properties: [.write, .notify], value: nil, permissions: [.writeable])
            payloadCharacteristic = CBMutableCharacteristic(type: BLESensorConfiguration.payloadCharacteristicUUID, properties: [.read], value: nil, permissions: [.readable])
            payloadSharingCharacteristic = CBMutableCharacteristic(type: BLESensorConfiguration.payloadSharingCharacteristicUUID, properties: [.read], value: nil, permissions: [.readable])
        }
        let service = CBMutableService(type: BLESensorConfiguration.serviceUUID, primary: true)
        service.characteristics = [signalCharacteristic!, payloadCharacteristic!, payloadSharingCharacteristic!]
        queue.async {
            self.peripheral.stopAdvertising()
            self.peripheral.removeAllServices()
            self.peripheral.add(service)
            self.peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey : [BLESensorConfiguration.serviceUUID]])
        }
    }
    
    private func stopAdvertising() {
        logger.debug("stopAdvertising()")
        queue.async {
            self.peripheral.stopAdvertising()
        }
        notifyTimer?.cancel()
        notifyTimer = nil
    }
    
    /// All work starts from notify subscribers loop.
    /// Generate updateValue notification after 8 seconds to notify all subscribers and keep the iOS receivers awake.
    private func notifySubscribers(_ source: String) {
        notifyTimer?.cancel()
        notifyTimer = DispatchSource.makeTimerSource(queue: notifyTimerQueue)
        notifyTimer?.schedule(deadline: DispatchTime.now() + BLESensorConfiguration.notificationDelay)
        notifyTimer?.setEventHandler { [weak self] in
            guard let s = self, let logger = self?.logger, let signalCharacteristic = self?.signalCharacteristic else {
                return
            }
            // Notify subscribers to keep them awake
            s.queue.async {
                logger.debug("notifySubscribers (source=\(source))")
                s.peripheral.updateValue(s.emptyData, for: signalCharacteristic, onSubscribedCentrals: nil)
            }
            // Restart advert if required
            let advertUpTime = Date().timeIntervalSince(s.advertisingStartedAt)
            if s.peripheral.isAdvertising, advertUpTime > BLESensorConfiguration.advertRestartTimeInterval {
                logger.debug("advertRestart (upTime=\(advertUpTime))")
                s.startAdvertising(withNewCharacteristics: true)
            }
        }
        notifyTimer?.resume()
    }
    
    // MARK:- CBPeripheralManagerDelegate
    
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        logger.debug("willRestoreState")
        self.peripheral = peripheral
        peripheral.delegate = self
        if let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] {
            for service in services {
                logger.debug("willRestoreState (service=\(service.uuid.uuidString))")
                if let characteristics = service.characteristics {
                    for characteristic in characteristics {
                        logger.debug("willRestoreState (characteristic=\(characteristic.uuid.uuidString))")
                        switch characteristic.uuid {
                        case BLESensorConfiguration.androidSignalCharacteristicUUID:
                            if let mutableCharacteristic = characteristic as? CBMutableCharacteristic {
                                signalCharacteristic = mutableCharacteristic
                                logger.debug("willRestoreState (androidSignalCharacteristic=\(characteristic.uuid.uuidString))")
                            } else {
                                logger.fault("willRestoreState characteristic not mutable (androidSignalCharacteristic=\(characteristic.uuid.uuidString))")
                            }
                        case BLESensorConfiguration.iosSignalCharacteristicUUID:
                            if let mutableCharacteristic = characteristic as? CBMutableCharacteristic {
                                signalCharacteristic = mutableCharacteristic
                                logger.debug("willRestoreState (iosSignalCharacteristic=\(characteristic.uuid.uuidString))")
                            } else {
                                logger.fault("willRestoreState characteristic not mutable (iosSignalCharacteristic=\(characteristic.uuid.uuidString))")
                            }
                        case BLESensorConfiguration.payloadCharacteristicUUID:
                            if let mutableCharacteristic = characteristic as? CBMutableCharacteristic {
                                payloadCharacteristic = mutableCharacteristic
                                logger.debug("willRestoreState (payloadCharacteristic=\(characteristic.uuid.uuidString))")
                            } else {
                                logger.fault("willRestoreState characteristic not mutable (payloadCharacteristic=\(characteristic.uuid.uuidString))")
                            }
                        case BLESensorConfiguration.payloadSharingCharacteristicUUID:
                            if let mutableCharacteristic = characteristic as? CBMutableCharacteristic {
                                payloadSharingCharacteristic = mutableCharacteristic
                                logger.debug("willRestoreState (payloadSharingCharacteristic=\(characteristic.uuid.uuidString))")
                            } else {
                                logger.fault("willRestoreState characteristic not mutable (payloadSharingCharacteristic=\(characteristic.uuid.uuidString))")
                            }
                        default:
                            logger.debug("willRestoreState (unknownCharacteristic=\(characteristic.uuid.uuidString))")
                        }
                    }
                }
            }
        }
    }

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // Bluetooth on -> Advertise
        if (peripheral.state == .poweredOn) {
            logger.debug("Update state (state=poweredOn)")
            start()
        } else {
            if #available(iOS 10.0, *) {
                logger.debug("Update state (state=\(peripheral.state.description))")
            } else {
                switch peripheral.state {
                    case .poweredOff:
                        logger.debug("Update state (state=poweredOff)")
                    case .poweredOn:
                        logger.debug("Update state (state=poweredOn)")
                    case .resetting:
                        logger.debug("Update state (state=resetting)")
                    case .unauthorized:
                        logger.debug("Update state (state=unauthorized)")
                    case .unknown:
                        logger.debug("Update state (state=unknown)")
                    case .unsupported:
                        logger.debug("Update state (state=unsupported)")
                    default:
                        logger.debug("Update state (state=undefined)")
                }
            }
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        logger.debug("peripheralManagerDidStartAdvertising (error=\(String(describing: error)))")
        if error == nil {
            advertisingStartedAt = Date()
        }
    }
    
    /**
     Write request offers a mechanism for non-transmitting BLE devices (e.g. Samsung J6 can only receive) to make
     its presence known by submitting its beacon code and RSSI as data. This also offers a mechanism for iOS to
     write blank data to transmitter to keep bringing it back from suspended state to background state which increases
     its chance of background scanning over a long period without being killed off.
     */
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        // Write -> Notify delegates -> Write response -> Notify subscribers
        for request in requests {
            let targetIdentifier = TargetIdentifier(central: request.central)
            logger.debug("didReceiveWrite (central=\(targetIdentifier))")
            if let data = request.value {
                // Receive beacon code and RSSI as data from receiver (e.g. Android device with no BLE transmit capability)
                if let payloadDataBundle = PayloadDataBundle(data) {
                    logger.debug("didReceiveWrite -> didDetect=\(targetIdentifier)")
                    delegates.forEach { $0.sensor(.BLE, didDetect: targetIdentifier) }
                    
                    if let rssi = payloadDataBundle.rssi {
                        let proximity = Proximity(unit: .RSSI, value: Double(rssi))
                        logger.debug("didReceiveWrite -> didMeasure=\(proximity.description),fromTarget=\(targetIdentifier)")
                        delegates.forEach { $0.sensor(.BLE, didMeasure: proximity, fromTarget: targetIdentifier) }
                    }
                    
                    if let payloadData = payloadDataBundle.payloadData {
                        logger.debug("didReceiveWrite -> didRead=\(payloadData.description),fromTarget=\(targetIdentifier)")
                        delegates.forEach { $0.sensor(.BLE, didRead: payloadData, fromTarget: targetIdentifier) }
                    }
                }
                // Receiver writes blank data on detection of transmitter to bring iOS transmitter back from suspended state
                peripheral.respond(to: request, withResult: .success)
            } else {
                peripheral.respond(to: request, withResult: .invalidAttributeValueLength)
            }
            // FEATURE : Symmetric connection on write
            _ = database.device(request.central.identifier.uuidString)
        }
        notifySubscribers("didReceiveWrite")
    }
    
    /// Determine what payload data to share with peer
    private func payloadSharingData(_ central: CBCentral) -> (identifiers: [TargetIdentifier], data: Data) {
        let peer = database.device(central.identifier.uuidString)
        // Get other devices that were seen recently by this device
        var unknownDevices: [BLEDevice] = []
        var knownDevices: [BLEDevice] = []
        database.devices().forEach() { device in
            // Device was seen recently
            guard device.timeIntervalSinceLastUpdate < BLESensorConfiguration.payloadSharingTimeInterval else {
                return
            }
            // Device has payload
            guard let payload = device.payloadData else {
                return
            }
            // Device is iOS (Android is always discoverable)
            guard device.operatingSystem == .ios else {
                return
            }
            // Payload is new to peer
            if peer.payloadSharingData.contains(payload) {
                knownDevices.append(device)
            } else {
                unknownDevices.append(device)
            }
        }
        // Most recently seen unknown devices first
        var devices: [BLEDevice] = []
        unknownDevices.sort { $1.lastUpdatedAt > $0.lastUpdatedAt }
        knownDevices.sort { $1.lastUpdatedAt > $0.lastUpdatedAt }
        devices.append(contentsOf: unknownDevices)
        devices.append(contentsOf: knownDevices)
        // Limit how much to share to avoid oversized data transfers over BLE (512 bytes limit according to spec, 510 with response, iOS requires response)
        var identifiers: [TargetIdentifier] = []
        var data = Data()
        devices.forEach() { device in
            guard let payload = device.payloadData else {
                return
            }
            guard data.count + payload.count < (2*129) else {
                return
            }
            identifiers.append(device.identifier)
            data.append(payload)
            device.payloadSharingData.append(payload) 
        }
        return (identifiers, data)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        // Read -> Notify subscribers
        let targetIdentifier = TargetIdentifier(request.central.identifier.uuidString)
        switch request.characteristic.uuid {
        case BLESensorConfiguration.payloadCharacteristicUUID:
            logger.debug("Read (central=\(targetIdentifier),characteristic=payload,offset=\(request.offset))")
            let data = payloadDataSupplier.payload(PayloadTimestamp())
            guard request.offset < data.count else {
                logger.fault("Read, invalid offset (central=\(targetIdentifier),characteristic=payload,offset=\(request.offset),data=\(data.description))")
                peripheral.respond(to: request, withResult: .invalidOffset)
                return
            }
            request.value = (request.offset == 0 ? data : data.subdata(in: request.offset..<data.count))
            peripheral.respond(to: request, withResult: .success)
        case BLESensorConfiguration.payloadSharingCharacteristicUUID:
            let (identifiers, data) = payloadSharingData(request.central)
            logger.debug("Read (central=\(targetIdentifier),characteristic=payloadSharing,offset=\(request.offset),shared=\(identifiers))")
            guard identifiers.count > 0, data.count > 0 else {
                peripheral.respond(to: request, withResult: .success)
                return
            }
            guard request.offset < data.count else {
                logger.fault("Read, invalid offset (central=\(targetIdentifier),characteristic=payloadSharing,offset=\(request.offset),data=\(data.description))")
                peripheral.respond(to: request, withResult: .invalidOffset)
                return
            }
            request.value = (request.offset == 0 ? data : data.subdata(in: request.offset..<data.count))
            peripheral.respond(to: request, withResult: .success)
        default:
            logger.fault("Read (central=\(request.central.identifier.uuidString),characteristic=unknown)")
            peripheral.respond(to: request, withResult: .requestNotSupported)
        }
        // FEATURE : Symmetric connection on read
        _ = database.device(request.central.identifier.uuidString)
        notifySubscribers("didReceiveRead")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        // Subscribe -> Notify subscribers
        // iOS receiver subscribes to the signal characteristic on first contact. This ensures the first call keeps
        // the transmitter and receiver awake. Future loops will rely on didReceiveWrite as the trigger.
        logger.debug("Subscribe (central=\(central.identifier.uuidString))")
        // FEATURE : Symmetric connection on subscribe
        _ = database.device(central.identifier.uuidString)
        notifySubscribers("didSubscribeTo")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        // Unsubscribe -> Notify subscribers
        logger.debug("Unsubscribe (central=\(central.identifier.uuidString))")
        // FEATURE : Symmetric connection on unsubscribe
        _ = database.device(central.identifier.uuidString)
        notifySubscribers("didUnsubscribeFrom")
    }
}

/// RSSI and Payload data transmitted from receiver via write to signal characteristic
class PayloadDataBundle {
    let rssi: BLE_RSSI?
    let payloadData: PayloadData?
    
    init?(_ data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= 4 else {
            rssi = nil
            payloadData = nil
            return nil
        }
        // RSSI is a 32-bit Java int (little-endian) at index 0
        rssi = BLE_RSSI(PayloadDataBundle.getInt32(8, bytes: bytes))
        guard bytes.count > 4 else {
            payloadData = nil
            return
        }
        // Payload data is the remainder
        // e.g. C19X beacon code is a 64-bit Java long (little-endian) at index 4
        payloadData = PayloadData(data.subdata(in: 4..<data.count))
    }

    /// Get Int32 from byte array (little-endian).
    static func getInt32(_ index: Int, bytes:[UInt8]) -> Int32 {
        return Int32(bitPattern: getUInt32(index, bytes: bytes))
    }
    
    /// Get UInt32 from byte array (little-endian).
    static func getUInt32(_ index: Int, bytes:[UInt8]) -> UInt32 {
        let returnValue = UInt32(bytes[index]) |
            UInt32(bytes[index + 1]) << 8 |
            UInt32(bytes[index + 2]) << 16 |
            UInt32(bytes[index + 3]) << 24
        return returnValue
    }
    
    /// Get Int64 from byte array (little-endian).
    static func getInt64(_ index: Int, bytes:[UInt8]) -> Int64 {
        return Int64(bitPattern: getUInt64(index, bytes: bytes))
    }
    
    /// Get UInt64 from byte array (little-endian).
    static func getUInt64(_ index: Int, bytes:[UInt8]) -> UInt64 {
        let returnValue = UInt64(bytes[index]) |
            UInt64(bytes[index + 1]) << 8 |
            UInt64(bytes[index + 2]) << 16 |
            UInt64(bytes[index + 3]) << 24 |
            UInt64(bytes[index + 4]) << 32 |
            UInt64(bytes[index + 5]) << 40 |
            UInt64(bytes[index + 6]) << 48 |
            UInt64(bytes[index + 7]) << 56
        return returnValue
    }
}
