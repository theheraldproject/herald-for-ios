//
//  BLEReceiver.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import CoreBluetooth
import os

/**
 Beacon receiver scans for peripherals with fixed service UUID.
 */
protocol BLEReceiver : Sensor {
}

/**
 Beacon receiver scans for peripherals with fixed service UUID in foreground and background modes. Background scan
 for Android is trivial as scanForPeripherals will always return all Android devices on every call. Background scan for iOS
 devices that are transmitting in background mode is more complex, requiring an open connection to subscribe to a
 notifying characteristic that is used as trigger for keeping both iOS devices in background state (rather than suspended
 or killed). For iOS - iOS devices, on detection, the receiver will (1) write blank data to the transmitter, which triggers the
 transmitter to send a characteristic data update after 8 seconds, which in turns (2) triggers the receiver to receive a value
 update notification, to (3) create the opportunity for a read RSSI call and repeat of this looped process that keeps both
 devices awake.
 
 Please note, the iOS - iOS process is unreliable if (1) the user switches off bluetooth via Airplane mode settings, (2) the
 device reboots, and (3) it will fail completely if the app has been killed by the user. These are conditions that cannot be
 handled reliably by CoreBluetooth state restoration.
 */
class ConcreteBLEReceiver: NSObject, BLEReceiver, BLEDatabaseDelegate, CBCentralManagerDelegate, CBPeripheralDelegate {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "BLE.ConcreteBLEReceiver")
    private var delegates: [SensorDelegate] = []
    /// Dedicated sequential queue for all beacon transmitter and receiver tasks.
    private let queue: DispatchQueue!
    /// Dedicated sequential queue for delegate tasks.
    private let delegateQueue: DispatchQueue
    /// Database of peripherals
    private let database: BLEDatabase
    /// Payload data supplier for parsing shared payloads
    private let payloadDataSupplier: PayloadDataSupplier
    /// Central manager for managing all connections, using a single manager for simplicity.
    private var central: CBCentralManager!
    /// Dummy data for writing to the transmitter to trigger state restoration or resume from suspend state to background state.
    private let emptyData = Data(repeating: 0, count: 0)
    /**
     Shifting timer for triggering peripheral scan just before the app switches from background to suspend state following a
     call to CoreBluetooth delegate methods. Apple documentation suggests the time limit is about 10 seconds.
     */
    private var scanTimer: DispatchSourceTimer?
    /// Dedicated sequential queue for the shifting timer.
    private let scanTimerQueue = DispatchQueue(label: "Sensor.BLE.ConcreteBLEReceiver.ScanTimer")
    /// Dedicated sequential queue for the actual scan call.
    private let scheduleScanQueue = DispatchQueue(label: "Sensor.BLE.ConcreteBLEReceiver.ScheduleScan")
    /// Track scan interval and up time statistics for the receiver, for debug purposes.
    private let statistics = TimeIntervalSample()
    /// Scan result queue for recording discovered devices with no immediate pending action.
    private var scanResults: [BLEDevice] = []
    /// Enable programmatic control of receiver start/stop
    private var receiverEnabled: Bool = false
    
    /// Create a BLE receiver that shares the same sequential dispatch queue as the transmitter because concurrent transmit and receive
    /// operations impacts CoreBluetooth stability. The receiver and transmitter share a common database of devices to enable the transmitter
    /// to register centrals for resolution by the receiver as peripherals to create symmetric connections. The payload data supplier provides
    /// the actual payload data to be transmitted and received via BLE.
    required init(queue: DispatchQueue, delegateQueue: DispatchQueue, database: BLEDatabase, payloadDataSupplier: PayloadDataSupplier) {
        self.queue = queue
        self.delegateQueue = delegateQueue
        self.database = database
        self.payloadDataSupplier = payloadDataSupplier
        super.init()
        if central == nil {
            self.central = CBCentralManager(delegate: self, queue: queue, options: [
                CBCentralManagerOptionRestoreIdentifierKey : "Sensor.BLE.ConcreteBLEReceiver",
                // Set this to false to stop iOS from displaying an alert if the app is opened while bluetooth is off.
                CBCentralManagerOptionShowPowerAlertKey : false]
            )
        }
        database.add(delegate: self)
    }
    
    func add(delegate: SensorDelegate) {
        delegates.append(delegate)
    }
    
    func start() {
        if !receiverEnabled {
            receiverEnabled = true
            logger.debug("start, receiver enabled to follow bluetooth state")
        } else {
            logger.fault("start, receiver already enabled to follow bluetooth state")
        }
        scan("start")
    }
    
    func stop() {
        if receiverEnabled {
            receiverEnabled = false
            logger.debug("stop, receiver disabled")
        } else {
            logger.fault("stop, receiver already disabled")
        }
        guard central != nil, central.isScanning else {
            logger.fault("stop denied, already stopped")
            return
        }
        // Stop scanning
        scanTimer?.cancel()
        scanTimer = nil
        queue.async {
            self.central.stopScan()
        }
        // Cancel all connections, the resulting didDisconnect and didFailToConnect
        database.devices().forEach() { device in
            if let peripheral = device.mostRecentPeripheral(), peripheral.state != CBPeripheralState.disconnected {
                disconnect("stop", peripheral)
            }
        }
    }
    
    func immediateSend(data: Data, _ targetIdentifier: TargetIdentifier) -> Bool {
        logger.debug("immediateSend (targetIdentifier=\(targetIdentifier))")
        let device = database.device(targetIdentifier)
        logger.debug("immediateSend (peripheral=\(device.identifier))")
        guard let peripheral = device.mostRecentPeripheral(), peripheral.state == CBPeripheralState.connected else {
            logger.fault("immediateSend denied, peripheral not connected (peripheral=\(device.identifier))")
            return false
        }
        var toSend = Data([UInt8(BLESensorConfiguration.signalCharacteristicActionWriteImmediate)])
        var length = Int16(data.count)
        toSend.append(Data(bytes: &length, count: MemoryLayout<UInt16>.size))
        toSend.append(data)
        queue.async { peripheral.writeValue(toSend, for: device.signalCharacteristic!, type: CBCharacteristicWriteType.withResponse) }
        return true;
    }
    
    func immediateSendAll(data: Data) -> Bool {
        var toSend = Data([UInt8(BLESensorConfiguration.signalCharacteristicActionWriteImmediate)])
        var length = Int16(data.count)
        toSend.append(Data(bytes: &length, count: MemoryLayout<UInt16>.size))
        toSend.append(data)
        
//        let devicesToSendTo = database.devices().filter { $0.peripheral != nil && $0.peripheral!.state == .connected }
        let devicesToSendTo = database.devices().filter { $0.hasConnectedPeripheral() }
        devicesToSendTo.forEach() { device in
//            queue.async { device.peripheral!.writeValue(toSend, for: device.signalCharacteristic!, type: .withResponse) }
            queue.async { device.connectedPeripheral()!.writeValue(toSend, for: device.signalCharacteristic!, type: CBCharacteristicWriteType.withResponse) }
        }
        return true;
    }
    
    // MARK:- Scan for peripherals and initiate connection if required
    
    /// All work starts from scan loop.
    func scan(_ source: String) {
        guard receiverEnabled else {
            logger.fault("scan disabled (source=\(source),receiverEnabled=false)")
            return
        }
        statistics.add()
        logger.debug("scan (source=\(source),statistics={\(statistics.description)})")
        guard central != nil, central.state == .poweredOn else {
            logger.fault("scan failed, bluetooth is not powered on")
            return
        }
        // Scan for periperals advertising the sensor service.
        // This will find all Android and iOS foreground adverts
        // but it will miss the iOS background adverts unless
        // location has been enabled and screen is on for a moment.
        queue.async { self.taskScanForPeripherals() }
        // Register connected peripherals that are advertising the
        // sensor service. This catches the orphan peripherals that
        // may have been missed by CoreBluetooth during state
        // restoration or internal errors.
        queue.async { self.taskRegisterConnectedPeripherals() }
        // Resolve peripherals by device identifier obtained via
        // the transmitter. When an iOS central connects to this
        // peripheral, the transmitter code registers the central's
        // address as a new device pending resolution here to
        // establish a symmetric connection. This enables either
        // device to detect the other (e.g. with screen on)
        // and triggering both devices to detect each other.
        queue.async { self.taskResolveDevicePeripherals() }
        // Remove devices that have not been seen for a while as
        // the identifier would have changed after about 20 mins,
        // thus it is wasteful to maintain a reference.
        queue.async { self.taskRemoveExpiredDevices() }
        // Remove duplicate devices with the same payload but
        // different identifiers. This happens frequently as
        // device address changes at regular intervals as part
        // of the Bluetooth privacy feature, thus it looks like
        // a new device but is actually associated with the same
        // payload. All references to the duplicate will be
        // removed but the actual connection will be terminated
        // by CoreBluetooth, often showing an API misuse warning
        // which can be ignored.
        queue.async { self.taskRemoveDuplicatePeripherals() }
        // iOS devices are kept in background state indefinitely
        // (instead of dropping into suspended or terminated state)
        // by a series of time delayed BLE operations. While this
        // device is awake, it will write data to other iOS devices
        // to keep them awake, and vice versa.
        queue.async { self.taskWakeTransmitters() }
        // All devices have an upper limit on the number of concurrent
        // BLE connections it can maintain. For iOS, it is usually 12
        // or above. iOS devices maintain an active connection with
        // other iOS devices to keep awake and obtain regular RSSI
        // measurements, thus it can track up to 12 iOS devices at any
        // moment in time. Above this figure, this device will need
        // to rotate (disconnect/connect) connections to multiplex
        // between the iOS devices for coverage. This is unnecessary
        // for tracking Android devices as they are tracked by scan
        // only. A connection to Android is only required for reading
        // its payload upon discovery.
        queue.async { self.taskIosMultiplex() }
        // Connect to discovered devices if the device has pending tasks.
        // The vast majority of devices will be connected immediately upon
        // discovery, if they have a pending task (e.g. to establish its
        // operating system or read its payload). Devices may be discovered
        // but not have a pending task if they have already been fully
        // resolved (e.g. has operating system, payload and recent RSSI
        // measuremnet), these are placed in the scan results queue for
        // regular checking by this connect task (e.g. to read RSSI if
        // the existing value is now out of date).
        queue.async { self.taskConnect() }
        // Schedule this scan call again for execution in at least 8 seconds
        // time to repeat the scan loop. The actual call may be delayed beyond
        // the 8 second delay from this point because all terminating operations
        // (i.e. events that will eventually lead the app to enter suspended
        // state if nothing else happens) calls this function to keep the loop
        // running indefinitely. The 8 or less seconds delay was chosen to
        // ensure the scan call is activated before the app naturally enters
        // suspended state, but not so soon the loop runs too often.
        scheduleScan("scan")
    }
    
    /**
     Schedule scan for beacons after a delay of 8 seconds to start scan again just before
     state change from background to suspended. Scan is sufficient for finding Android
     devices repeatedly in both foreground and background states.
     */
    private func scheduleScan(_ source: String) {
        scheduleScanQueue.sync {
            scanTimer?.cancel()
            scanTimer = DispatchSource.makeTimerSource(queue: scanTimerQueue)
            scanTimer?.schedule(deadline: DispatchTime.now() + BLESensorConfiguration.notificationDelay)
            scanTimer?.setEventHandler { [weak self] in
                self?.scan("scheduleScan|"+source)
            }
            scanTimer?.resume()
        }
    }
    
    /**
     Scan for peripherals advertising the beacon service.
     */
    private func taskScanForPeripherals() {
        // Scan for peripherals -> didDiscover
        var scanForServices: [CBUUID] = [BLESensorConfiguration.linuxFoundationServiceUUID]
        // Optionally, include the old Herald service UUID (prior to v2.1.0)
        if BLESensorConfiguration.legacyHeraldServiceDetectionEnabled {
            scanForServices.append(BLESensorConfiguration.legacyHeraldServiceUUID)
        }
        // Optionally include OpenTrace protocol as scan criteria
        if BLESensorConfiguration.interopOpenTraceEnabled {
            scanForServices.append(BLESensorConfiguration.interopOpenTraceServiceUUID)
        }
        // Optionally include interop advert only protocol as scan criteria
        if BLESensorConfiguration.interopAdvertBasedProtocolEnabled {
            scanForServices.append(BLESensorConfiguration.interopAdvertBasedProtocolServiceUUID)
        }
        central.scanForPeripherals(
            withServices: scanForServices,
            options: [CBCentralManagerScanOptionSolicitedServiceUUIDsKey: [BLESensorConfiguration.linuxFoundationServiceUUID]])
    }
    
    /**
     Register all connected peripherals advertising the sensor service as a device.
     */
    private func taskRegisterConnectedPeripherals() {
        var services: [CBUUID] = [BLESensorConfiguration.linuxFoundationServiceUUID]
        // Optionally, include the old Herald service UUID (prior to v2.1.0)
        if BLESensorConfiguration.legacyHeraldServiceDetectionEnabled {
            services.append(BLESensorConfiguration.legacyHeraldServiceUUID)
        }
        central.retrieveConnectedPeripherals(withServices: services).forEach() { peripheral in
//            let targetIdentifier = TargetIdentifier(peripheral: peripheral)
            let device = database.device(peripheral, delegate: self)
            logger.debug("taskRegisterConnectedPeripherals (device=\(device))")
//            if device.peripheral == nil || device.peripheral != peripheral {
//                logger.debug("taskRegisterConnectedPeripherals (device=\(device))")
//                _ = database.device(peripheral, delegate: self)
//            }
        }
    }

    /**
     Resolve peripheral for all database devices. This enables the symmetric connection feature where connections from central to peripheral (BLETransmitter) registers the existence
     of a potential peripheral for resolution by this central (BLEReceiver).
     */
    private func taskResolveDevicePeripherals() {
        let devicesToResolve = database.devices().filter { !$0.hasPeripheral() }
        devicesToResolve.forEach() { device in
            guard let identifier = UUID(uuidString: device.identifier) else {
                return
            }
            let peripherals = central.retrievePeripherals(withIdentifiers: [identifier])
            if let peripheral = peripherals.last {
                logger.debug("taskResolveDevicePeripherals (resolved=\(device))")
                _ = database.device(peripheral, delegate: self)
            }
        }
    }
    
    /**
     Remove devices that have not been updated for over an hour, as the UUID is likely to have changed after being out of range for over 20 minutes, so it will require discovery.
     */
    private func taskRemoveExpiredDevices() {
        let devicesToRemove = database.devices().filter { Date().timeIntervalSince($0.lastUpdatedAt) > BLESensorConfiguration.peripheralCleanInterval }
        devicesToRemove.forEach() { device in
            logger.debug("taskRemoveExpiredDevices (remove=\(device))")
            database.delete(device)
            if let peripheral = device.connectedPeripheral() {
                disconnect("taskRemoveExpiredDevices", peripheral)
            }
        }
    }
    
    /**
     Remove devices with the same payload data but different peripherals.
     */
    private func taskRemoveDuplicatePeripherals() {
        var index: [PayloadData:BLEDevice] = [:]
        var hasPrinted = false
        let devices = database.devices()
        devices.forEach() { device in
            // Now cannot happen, because identifier never assigned by payloadData
            guard let payloadData = device.payloadData else {
                return
            }
            guard let duplicate = index[payloadData] else {
                index[payloadData] = device
                return
            }
            if !hasPrinted {
                // Only print a list of nearby devices if we do in fact have duplicates - reduces logging
                hasPrinted = true
                database.printDevices()
            }
            // If we get this far, we somehow have a duplicate (Happens depending on detection vs payloadRead speed)
            self.logger.debug("INFO: Two devices with the same PayloadData found for payload: \(payloadData.shortName)")
            self.logger.debug(" - Device identifier: \(device.identifier), lastUpdated: \(device.lastUpdatedAt)")
            for id in device.peripheralIDs {
                self.logger.debug("  - Peripheral ID: \(id.id.uuidString), state: \(id.peripheral.state), lastSeen: \(id.lastSeen)")
            }
            self.logger.debug(" - Duplicate identifier: \(duplicate.identifier), lastUpdated: \(duplicate.lastUpdatedAt)")
            for id in duplicate.peripheralIDs {
                self.logger.debug("  - Peripheral ID: \(id.id.uuidString), state: \(id.peripheral.state), lastSeen: \(id.lastSeen)")
            }
            // Now merge the two devices into one by pseudoDeviceAddress - Android phones
            if let devicePDA = device.pseudoDeviceAddress {
                if nil == duplicate.pseudoDeviceAddress {
                    //            if device.pseudoDeviceAddress != nil and duplicate.pseudoDeviceAddress == nil {
                    for pid in duplicate.peripheralIDs {
                        device.peripheralIDs.append(pid)
                    }
                    duplicate.peripheralIDs.removeAll()
                    duplicate.payloadData = nil
                    database.delete(duplicate)
                } else {
                    self.logger.debug("Android device has rotated Bluetooth MAC Address and pseudoDeviceAddress")
                    // pseudoDeviceAddress has changed
                    if device.timeIntervalSinceCreated > duplicate.timeIntervalSinceCreated {
                        for pid in duplicate.peripheralIDs {
                            device.peripheralIDs.append(pid)
                        }
                        duplicate.peripheralIDs.removeAll()
                        duplicate.payloadData = nil
                        database.delete(duplicate)
                    } else {
                        for pid in device.peripheralIDs {
                            duplicate.peripheralIDs.append(pid)
                        }
                        device.peripheralIDs.removeAll()
                        device.payloadData = nil
                        database.delete(device)
                    }
                }
            } else if let duplicatePDA = duplicate.pseudoDeviceAddress {
                if device.pseudoDeviceAddress == nil {
                    for pid in device.peripheralIDs {
                        duplicate.peripheralIDs.append(pid)
                    }
                    device.peripheralIDs.removeAll()
                    device.payloadData = nil
                    database.delete(device)
                } else {
                    self.logger.debug("Android device has rotated Bluetooth MAC Address and pseudoDeviceAddress")
                    // pseudoDeviceAddress has changed
                    if device.timeIntervalSinceCreated > duplicate.timeIntervalSinceCreated {
                        for pid in duplicate.peripheralIDs {
                            device.peripheralIDs.append(pid)
                        }
                        duplicate.peripheralIDs.removeAll()
                        duplicate.payloadData = nil
                        database.delete(duplicate)
                    } else {
                        for pid in device.peripheralIDs {
                            duplicate.peripheralIDs.append(pid)
                        }
                        device.peripheralIDs.removeAll()
                        device.payloadData = nil
                        database.delete(device)
                    }
                }
            } else {
                // Now handle the possibility they are iOS and the Bluetooth MAC address has rotated
                if ((device.operatingSystem == .ios) && (duplicate.operatingSystem == .ios)) {
                    self.logger.debug("iOS device has rotated Bluetooth MAC Address")
                    if device.timeIntervalSinceCreated > duplicate.timeIntervalSinceCreated {
                        for pid in duplicate.peripheralIDs {
                            device.peripheralIDs.append(pid)
                        }
                        duplicate.peripheralIDs.removeAll()
                        duplicate.payloadData = nil
                        database.delete(duplicate)
                    } else {
                        for pid in device.peripheralIDs {
                            duplicate.peripheralIDs.append(pid)
                        }
                        device.peripheralIDs.removeAll()
                        device.payloadData = nil
                        database.delete(device)
                    }
                } else {
                    self.logger.debug("WARNING could not merge by pseudoDeviceAddress - we need to handle this possibility")
                }
            }
//            var keeping = device
//            var discarding = duplicate
//            // First attempt to evaluate if only one has a Peripheral ID assigned
//            if device.peripheral != nil, duplicate.peripheral == nil {
//                keeping = device
//                discarding = duplicate
//            } else if duplicate.peripheral != nil, device.peripheral == nil {
//                keeping = duplicate
//                discarding = device
//            // Next, check if only one has a pseudoDeviceAddress (getting here implies both have the same Physical address)
//            } else if device.pseudoDeviceAddress != nil, duplicate.pseudoDeviceAddress == nil {
//                keeping = device
//                discarding = duplicate
//            } else if duplicate.pseudoDeviceAddress != nil, device.pseudoDeviceAddress == nil {
//                keeping = duplicate
//                discarding = device
//            } else if (device.payloadData == duplicate.payloadData) {
//                // Only Android have duplicate PDA, and remaining else clauses are for non Android
//                if let devPDA = device.pseudoDeviceAddress, let dupPDA = duplicate.pseudoDeviceAddress {
//                    if (devPDA.data != dupPDA.data) && (device.identifier != duplicate.identifier) {
//                        // Remote Android device has rotated it's Bluetooth ID and PseudoDeviceAddress (This is correct)
//                        // Trust the more recent one (added to the list later)
//                        keeping = duplicate
//                        discarding = device
//                    } else {
//                        // Otherwise our android devices have the same pseudoDeviceAddress (They cannot have the same identifier due to how they are stored)
//                        // Yes this is the same as the above, but the logic is being kept for clarity
//                        keeping = duplicate
//                        discarding = device
//                    }
//                // Next check if the payload update date is more recent (WARNING: New devices have a very OLD update date)
//                } else if device.payloadDataLastUpdatedAt > duplicate.payloadDataLastUpdatedAt {
//                    keeping = device
//                    discarding = duplicate
//                    // Finally, assume that if the entry has been added later, then it must be more up to date
//                    // (This without the second check above (pseudoDeviceAddress) is presumed to be the cause of the iPhone being overactive in 'discovering' Android devices and reading their payload)
//                } else {
//                    keeping = duplicate
//                    discarding = device
//                }
//            }
////            let discarding = (keeping.identifier == device.identifier ? duplicate : device)
//            index[payloadData] = keeping
//            database.delete(discarding)
//            self.logger.debug("taskRemoveDuplicatePeripherals (payload=\(payloadData.shortName),device=\(device.identifier),duplicate=\(duplicate.identifier),keeping=\(keeping.identifier))")
            // CoreBluetooth will eventually give warning and disconnect actual duplicate silently.
            // While calling disconnect here is cleaner but it will trigger didDiscover and
            // retain the duplicates. Expect to see message :
            // [CoreBluetooth] API MISUSE: Forcing disconnection of unused peripheral
            // <CBPeripheral: XXX, identifier = XXX, name = iPhone, state = connected>.
            // Did you forget to cancel the connection?
        }
        
        // TODO Remove old peripheralIDs not seen in a while
    }
    
    /**
     Wake transmitter on all connected iOS devices
     */
    private func taskWakeTransmitters() {
        database.devices().forEach() { device in
            guard device.operatingSystem == .ios, let peripheral = device.connectedPeripheral() else {
                return
            }
            guard device.timeIntervalSinceLastUpdate < TimeInterval.minute else {
                // Throttle back keep awake calls when out of range, issue pending connect instead
                connect("taskWakeTransmitters", peripheral)
                return
            }
            wakeTransmitter("taskWakeTransmitters", device)
        }
    }
    
    /**
     Connect to devices and maintain concurrent connection quota
     */
    private func taskConnect() {
        // Get recently discovered devices
        let didDiscover = taskConnectScanResults()
        // Identify recently discovered devices with pending tasks : connect -> nextTask
        let hasPendingTask = didDiscover.filter({ deviceHasPendingTask($0) })
        // Identify all connected (iOS) devices to trigger refresh : connect -> nextTask
        let toBeRefreshed = database.devices().filter({ !hasPendingTask.contains($0) && $0.hasConnectedPeripheral() })
        // Identify all unconnected devices with unknown operating system, these are
        // created by ConcreteBLETransmitter on characteristic write, to ensure all
        // centrals that connect to this peripheral are recorded, to enable this central
        // to attempt connection to the peripheral, thus establishing a bi-directional
        // connection. This is essential for iOS-iOS background detection, where the
        // discovery of phoneB by phoneA, and a connection from A to B, will trigger
        // B to connect to A, thus assuming location permission has been enabled, it
        // will only require screen ON at either phone to trigger bi-directional connection.
        let asymmetric = database.devices().filter({ !hasPendingTask.contains($0) && $0.operatingSystem == .unknown &&
            $0.hasPeripheral() && !$0.hasConnectedPeripheral() })
        // Connect to recently discovered devices with pending tasks
        hasPendingTask.forEach() { device in
            guard let peripheral = device.mostRecentPeripheral() else {
                return
            }
            connect("taskConnect|hasPending", peripheral);
        }
        // Refresh connection to existing devices to trigger next task
        toBeRefreshed.forEach() { device in
            guard let peripheral = device.mostRecentPeripheral() else {
                return
            }
            connect("taskConnect|refresh", peripheral);
        }
        // Connect to unknown devices that have written to this peripheral
        asymmetric.forEach() { device in
            guard let peripheral = device.mostRecentPeripheral() else {
                return
            }
            connect("taskConnect|asymmetric", peripheral);
        }
    }

    /// Empty scan results to produce a list of recently discovered devices for connection and processing
    private func taskConnectScanResults() -> [BLEDevice] {
        var set: Set<BLEDevice> = []
        var list: [BLEDevice] = []
        while let device = scanResults.popLast() {
            if set.insert(device).inserted, device.hasPeripheral() && !device.hasConnectedPeripheral() {
                list.append(device)
                logger.debug("taskConnectScanResults, didDiscover (device=\(device))")
            }
        }
        return list
    }
    
    /// Check if device has pending task
    /// This must be kept in sync with taskInitiateNextAction, which is error prone for
    /// code maintenance. An alternative implementation will be introduced in the future.
    private func deviceHasPendingTask(_ device: BLEDevice) -> Bool {
        // Resolve operating system
        if device.operatingSystem == .unknown || device.operatingSystem == .restored {
            return true
        }
        // Read payload
        if device.payloadData == nil {
            return true
        }
        // Payload update
        if device.timeIntervalSinceLastPayloadDataUpdate > BLESensorConfiguration.payloadDataUpdateTimeInterval {
            return true
        }
        if BLESensorConfiguration.interopOpenTraceEnabled, device.protocolIsOpenTrace,
           device.timeIntervalSinceLastPayloadDataUpdate > BLESensorConfiguration.interopOpenTracePayloadDataUpdateTimeInterval {
            return true
        }
        // iOS should always be connected
        // TODO re-evaluate this and verify the behaviour still occurs
        if device.operatingSystem == .ios, device.hasPeripheral() && !device.hasConnectedPeripheral() {
            return true
        }
        return false
    }
    
    /// Check if iOS device is waiting for connection and free capacity if required
    private func taskIosMultiplex() {
        // Identify iOS devices
        let devices = database.devices().filter({ $0.operatingSystem == .ios && $0.hasPeripheral() })
        // Get a list of connected devices and uptime
        let connected = devices.filter({ $0.hasConnectedPeripheral() }).sorted(by: { $0.timeIntervalBetweenLastConnectedAndLastAdvert > $1.timeIntervalBetweenLastConnectedAndLastAdvert })
        // Get a list of connecting devices
        let pending = devices.filter({ !$0.hasConnectedPeripheral() }).sorted(by: { $0.lastConnectRequestedAt < $1.lastConnectRequestedAt })
        logger.debug("taskIosMultiplex summary (connected=\(connected.count),pending=\(pending.count))")
        connected.forEach() { device in
            logger.debug("taskIosMultiplex, connected (device=\(device.description),upTime=\(device.timeIntervalBetweenLastConnectedAndLastAdvert))")
        }
        pending.forEach() { device in
            logger.debug("taskIosMultiplex, pending (device=\(device.description),downTime=\(device.timeIntervalSinceLastConnectRequestedAt))")
        }
        // Retry all pending connections if there is surplus capacity
        if connected.count < BLESensorConfiguration.concurrentConnectionQuota {
            pending.forEach() { device in
                guard let toBeConnected = device.mostRecentPeripheral() else {
                    return
                }
                connect("taskIosMultiplex|retry", toBeConnected);
            }
        }
        // Initiate multiplexing when capacity has been reached
        guard connected.count > BLESensorConfiguration.concurrentConnectionQuota, pending.count > 0, let deviceToBeDisconnected = connected.first, let peripheralToBeDisconnected = deviceToBeDisconnected.connectedPeripheral(), deviceToBeDisconnected.timeIntervalBetweenLastConnectedAndLastAdvert > TimeInterval.minute else {
            return
        }
        logger.debug("taskIosMultiplex, multiplexing (toBeDisconnected=\(deviceToBeDisconnected.description))")
        disconnect("taskIosMultiplex", peripheralToBeDisconnected)
        pending.forEach() { device in
            guard let toBeConnected = device.mostRecentPeripheral() else {
                return
            }
            connect("taskIosMultiplex|multiplex", toBeConnected);
        }
    }
    
    /// Initiate next action on peripheral based on current state and information available
    /// This must be kept in sync with deviceHasPendingTask, which is error prone for
    /// code maintenance. An alternative implementation will be introduced in the future.
    private func taskInitiateNextAction(_ source: String, peripheral: CBPeripheral) {
        let device = database.device(peripheral, delegate: self)
        if device.rssi == nil {
            // 1. RSSI
            logger.debug("taskInitiateNextAction (goal=rssi,device=\(device))")
            readRSSI("taskInitiateNextAction|" + source, peripheral)
        } else if !(device.protocolIsHerald || device.protocolIsOpenTrace) {
            // 2. Characteristics
            logger.debug("taskInitiateNextAction (goal=characteristics,device=\(device))")
            discoverServices("taskInitiateNextAction|" + source, peripheral)
        } else if device.payloadData == nil {
            // 3. Payload
            logger.debug("taskInitiateNextAction (goal=payload,device=\(device))")
            readPayload("taskInitiateNextAction|" + source, device)
        } else if device.timeIntervalSinceLastPayloadDataUpdate > BLESensorConfiguration.payloadDataUpdateTimeInterval {
            // 4. Payload update
            logger.debug("taskInitiateNextAction (goal=payloadUpdate,device=\(device),elapsed=\(device.timeIntervalSinceLastPayloadDataUpdate))")
            readPayload("taskInitiateNextAction|" + source, device)
        } else if BLESensorConfiguration.interopOpenTraceEnabled, device.protocolIsOpenTrace,
               device.timeIntervalSinceLastPayloadDataUpdate > BLESensorConfiguration.interopOpenTracePayloadDataUpdateTimeInterval {
            // 5. Payload update for OpenTrace
            logger.debug("taskInitiateNextAction (goal=payloadUpdate|OpenTrace,device=\(device),elapsed=\(device.timeIntervalSinceLastPayloadDataUpdate))")
            readPayload("taskInitiateNextAction|" + source, device)
        } else if device.operatingSystem != .ios {
            // 6. Disconnect Android
            logger.debug("taskInitiateNextAction (goal=disconnect|\(device.operatingSystem.rawValue),device=\(device))")
            disconnect("taskInitiateNextAction|" + source, peripheral)
        } else {
            // 7. Scan
            logger.debug("taskInitiateNextAction (goal=scan,device=\(device))")
            scheduleScan("taskInitiateNextAction|" + source)
        }
    }
    
    /**
     Connect peripheral. Scanning is stopped temporarily, as recommended by Apple documentation, before initiating connect, otherwise
     pending scan operations tend to take priority and connect takes longer to start. Scanning is scheduled to resume later, to ensure scan
     resumes, even if connect fails.
     */
    private func connect(_ source: String, _ peripheral: CBPeripheral) {
        let device = database.device(peripheral, delegate: self)
        logger.debug("connect (source=\(source),device=\(device))")
        guard central.state == .poweredOn else {
            logger.fault("connect denied, central not powered on (source=\(source),device=\(device))")
            return
        }
        queue.async {
            device.lastConnectRequestedAt = Date()
            self.central.retrievePeripherals(withIdentifiers: [peripheral.identifier]).forEach {
                if $0.state != .connected {
                    var performConnection = false
                    // Check to see if Herald has initiated a connection attempt before
                    if let lastAttempt = device.lastConnectionInitiationAttempt {
                        // Has Herald already initiated a connect attempt?
                        if (Date() > lastAttempt + BLESensorConfiguration.connectionAttemptTimeout) {
                            // If timeout reached, force disconnect
                            self.logger.fault("connect, timeout forcing disconnect (source=\(source),device=\(device),elapsed=\(-lastAttempt.timeIntervalSinceNow))")
                            device.lastConnectionInitiationAttempt = nil
                            device.failedConnectionAttempts += 1
                            // determine next connection time now
                            // Removed the following line as the other setting of this now includes the connection timeout within it, so this is superfluous
//                            device.onlyConnectAfter = Date() + TimeInterval(1 + 2^device.failedConnectionAttempts + Int.random(in: 0...5)) // 1 second, 3, 7, 15, 31, 63 and so on, with mean 2.5 seconds jitter added
                            self.queue.async { self.central.cancelPeripheralConnection(peripheral) }
                        } else {
                            // If not timed out yet, keep trying
//                            self.logger.debug("connect, waiting for connection or timeout... (source=\(source),device=\(device),elapsed=\(-lastAttempt.timeIntervalSinceNow))")
                            self.logger.debug("connect, retrying (source=\(source),device=\(device),elapsed=\(-lastAttempt.timeIntervalSinceNow))")
//                            device.lastConnectionInitiationAttempt = Date() // Set on each distinct attempt
//                            device.onlyConnectAfter = Date() + TimeInterval(1 + Int.random(in: 0...5)) // 1 second + mean 2.5 seconds jitter added
                            performConnection = true
                        }
                    } else {
                        // If not, connect now
                        self.logger.debug("connect, initiation (source=\(source),device=\(device))")
//                        device.lastConnectionInitiationAttempt = Date() // Set on each distinct attempt
//                        device.onlyConnectAfter = Date() + TimeInterval(1 + Int.random(in: 0...5)) // 1 second + mean 2.5 seconds jitter added
                        performConnection = true
                    }
                    // Try to connect, but don't attempt if currently attempting a connection (I.e. from a recent previous call that reaches this point)
                    // Note: iOS devices incorrectly report .connecting, so we're relying on the timeout, above, here.
                    //       Also now checking if we're waiting for a timeout, as we didn't handle that case before. (Temporary workaround for https://github.com/theheraldproject/herald-for-ios/issues/188)
                    if (performConnection && $0.state != .connecting && nil == device.lastConnectionInitiationAttempt) {
                        // Allow progressive backoff
                        if (device.onlyConnectAfter < Date()) {
                            // Changed to 3^ in order to back off more quickly (after 6 you'll now be at 94 seconds instead of 33 seconds)
                            // Separated into separate lines as otherwise the XCode compiler complains that it's too complicated...
                            let prog = 3^device.failedConnectionAttempts
                            let seconds = 1  + prog + Int.random(in: 0...5)
                            // Added connection timeout time too as a temporary workaround for https://github.com/theheraldproject/herald-for-ios/issues/188)
                            let delay: TimeInterval = TimeInterval(seconds) + BLESensorConfiguration.connectionAttemptTimeout
                            
                            self.logger.debug("connect, now requesting a central connection (source=\(source),device=\(device),failedAttempts=\(device.failedConnectionAttempts),nextOnlyConnectAfterDelay=\(seconds)")
                            // Add in a delay immediately to prevent thrashing, but don't increase failure count unless THIS connection times out explicitly
                            device.lastConnectionInitiationAttempt = Date() // Set on each distinct attempt
                            
                            // 14, 16, 22, 40, 94 and so on, with mean 2.5 seconds jitter added
                            // Additional timeout added as otherwise the jitter mostly falls WITHIN the .connecting period
                            device.onlyConnectAfter = Date() + delay
                            
                            self.central.connect($0)
                        } else {
                            self.logger.debug("connect, waiting for discovery or backoff delay (source=\(source),device=\(device),connectAfter=\(device.onlyConnectAfter))")
                        }
                    } else {
                        self.logger.debug("connect, waiting for state to leave .connecting state (source=\(source),device=\(device),connectAfter=\(device.onlyConnectAfter),state=\($0.state.description)")
                    }
                } else {
                    // clear failure and progressive backoff counts for this now-connected device
                    device.failedConnectionAttempts = 0
                    device.lastConnectionInitiationAttempt = nil
                    // Minimum 10 second delay (plus mean 2.5 second jitter) between SUCCESSFUL attempts
                    // Note: In reality this will only affect us if reading a payload fails due to the connection failing
                    device.onlyConnectAfter = Date() + TimeInterval(10 + Int.random(in: 0...5))
                    // This ensures post-connection actions take place
                    self.taskInitiateNextAction("connect|" + source, peripheral: $0)
                }
            }
        }
        scheduleScan("connect")
    }
    
    /**
     Disconnect peripheral. On didDisconnect, a connect request will be made for iOS devices to maintain an open connection;
     there is no further action for Android. On didFailedToConnect, a connect request will be made for both iOS and Android
     devices as the error is likely to be transient (as described in Apple documentation), except if the error is "Device in invalid"
     then the peripheral is unregistered by removing it from the beacons table.
     */
    private func disconnect(_ source: String, _ peripheral: CBPeripheral) {
        let device = database.device(peripheral, delegate: self)
        logger.debug("disconnect (source=\(source),peripheral=\(device.identifier))")
        guard peripheral.state == .connected || peripheral.state == .connecting else {
            logger.fault("disconnect denied, peripheral not connected or connecting (source=\(source),peripheral=\(device.identifier),state=\(peripheral.state))")
            return
        }
        queue.async { self.central.cancelPeripheralConnection(peripheral) }
    }
    
    /// Read RSSI
    private func readRSSI(_ source: String, _ peripheral: CBPeripheral) {
        let device = database.device(peripheral, delegate: self)
        logger.debug("readRSSI (source=\(source),peripheral=\(device.identifier))")
        guard peripheral.state == .connected else {
            logger.fault("readRSSI denied, peripheral not connected (source=\(source),peripheral=\(device.identifier))")
            scheduleScan("readRSSI")
            return
        }
        queue.async { peripheral.readRSSI() }
    }
    
    /// Discover services
    private func discoverServices(_ source: String, _ peripheral: CBPeripheral) {
        let device = database.device(peripheral, delegate: self)
        logger.debug("discoverServices (source=\(source),peripheral=\(device.identifier))")
        guard peripheral.state == .connected else {
            logger.fault("discoverServices denied, peripheral not connected (source=\(source),peripheral=\(device.identifier))")
            scheduleScan("discoverServices")
            return
        }
        queue.async {
            var services: [CBUUID] = [BLESensorConfiguration.linuxFoundationServiceUUID]
            // Optionally, include the old Herald service UUID (prior to v2.1.0)
            if BLESensorConfiguration.legacyHeraldServiceDetectionEnabled {
                services.append(BLESensorConfiguration.legacyHeraldServiceUUID)
            }
            // Optionally include OpenTrace protocol as discovery criteria
            if BLESensorConfiguration.interopOpenTraceEnabled {
                services.append(BLESensorConfiguration.interopOpenTraceServiceUUID)
            }
            peripheral.discoverServices(services)
        }
    }
    
    /// Read payload data from device
    private func readPayload(_ source: String, _ device: BLEDevice) {
        logger.debug("readPayload (source=\(source),peripheral=\(device.identifier))")
        guard let peripheral = device.connectedPeripheral() else {
            logger.fault("readPayload denied, peripheral not connected (source=\(source),peripheral=\(device.identifier))")
            return
        }
        guard let payloadCharacteristic = device.payloadCharacteristic != nil ? device.payloadCharacteristic : device.legacyPayloadCharacteristic  else {
            logger.fault("readPayload denied, device missing payload characteristic (source=\(source),peripheral=\(device.identifier))")
            discoverServices("readPayload", peripheral)
            return
        }
        // De-duplicate read payload requests from multiple asynchronous calls
        let timeIntervalSinceLastReadPayloadRequestedAt = Date().timeIntervalSince(device.lastReadPayloadRequestedAt)
        guard timeIntervalSinceLastReadPayloadRequestedAt > 2 else {
            logger.fault("readPayload denied, duplicate request (source=\(source),peripheral=\(device.identifier),elapsed=\(timeIntervalSinceLastReadPayloadRequestedAt)")
            return
        }
        // Initiate read payload
        device.lastReadPayloadRequestedAt = Date()
        if device.operatingSystem == .android, let peripheral = device.mostRecentPeripheral() {
            discoverServices("readPayload|android", peripheral)
        } else {
            queue.async { peripheral.readValue(for: payloadCharacteristic) }
        }
    }
    
    /// Write payload to legacy OpenTrace device
    /// OpenTrace protocol : read payload -> write payload -> disconnect
    private func writeLegacyPayload(_ source: String, _ peripheral: CBPeripheral) {
        let device = database.device(peripheral, delegate: self)
        if device.protocolIsOpenTrace,
           let legacyPayloadCharacteristic = device.legacyPayloadCharacteristic,
           let legacyPayload = payloadDataSupplier.legacyPayload(PayloadTimestamp(), device: device) {
            queue.async {
                self.logger.debug("writeLegacyPayload (source=\(source),peripheral=\(device.identifier),payload=\(legacyPayload.shortName))")
                peripheral.writeValue(legacyPayload.data, for: legacyPayloadCharacteristic, type: .withResponse)
            }
            return
        }
        disconnect("writeLegacyPayload", peripheral)
    }

    /**
     Wake transmitter by writing blank data to the beacon characteristic. This will trigger the transmitter to generate a data value update notification
     in 8 seconds, which in turn will trigger this receiver to receive a didUpdateValueFor call to keep both the transmitter and receiver awake, while
     maximising the time interval between bluetooth calls to minimise power usage.
     */
    private func wakeTransmitter(_ source: String, _ device: BLEDevice) {
        guard device.operatingSystem == .ios, let peripheral = device.mostRecentPeripheral(), let characteristic = device.signalCharacteristic else {
            return
        }
        logger.debug("wakeTransmitter (source=\(source),peripheral=\(device.identifier),write=\(characteristic.properties.contains(.write))")
        queue.async { peripheral.writeValue(self.emptyData, for: characteristic, type: .withResponse) }
    }
    
    // MARK:- BLEDatabaseDelegate
    
    func bleDatabase(didCreate device: BLEDevice) {
        // FEATURE : Symmetric connection on write
        // All CoreBluetooth delegate callbacks in BLETransmitter will register the central interacting with this peripheral
        // in the database and generate a didCreate callback here to trigger scan, which includes a task for resolving all
        // device identifiers to actual peripherals.
        scheduleScan("bleDatabase:didCreate (device=\(device.identifier))")
    }
    
    // MARK:- CBCentralManagerDelegate
    
    /// Reinstate devices following state restoration
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        // Restore -> Populate database
        logger.debug("willRestoreState")
        self.central = central
        central.delegate = self
        if let restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in restoredPeripherals {
                let targetIdentifier = TargetIdentifier(peripheral: peripheral)
                let device = database.device(peripheral, delegate: self)
                if device.operatingSystem == .unknown {
                    device.operatingSystem = .restored
                }
                if peripheral.state == .connected {
                    device.lastConnectedAt = Date()
                }
                logger.debug("willRestoreState (peripheral=\(targetIdentifier))")
            }
        }
        // Reconnection check performed in scan following centralManagerDidUpdateState:central.state == .powerOn
    }
    
    /// Start scan when bluetooth is on.
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Bluetooth on -> Scan
        if (central.state == .poweredOn) {
            logger.debug("Update state (state=poweredOn))")
            delegateQueue.async {
                self.delegates.forEach({ $0.sensor(.BLE, didUpdateState: .on) })
            }
            scan("updateState")
        } else {
            if #available(iOS 10.0, *) {
                logger.debug("Update state (state=\(central.state.description))")
            } else {
                // Required for compatibility with iOS 9.3
                switch central.state {
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
            delegateQueue.async {
                self.delegates.forEach({ $0.sensor(.BLE, didUpdateState: .off) })
            }
        }
    }
        
    /// Device discovery will trigger connection to resolve operating system and read payload for iOS and Android devices.
    /// Connection is kept active for iOS devices for on-going RSSI measurements, and closed for Android devices, as this
    /// iOS device can rely on this discovery callback (triggered by regular scan calls) for on-going RSSI and TX power
    /// updates, thus eliminating the need to keep connections open for Android devices that can cause stability issues for
    /// Android devices.
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Populate device database
        let device = database.device(peripheral, advertisementData: advertisementData, delegate: self)
        device.lastDiscoveredAt = Date()
        device.rssi = BLE_RSSI(RSSI.intValue)
        if let txPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue {
            device.txPower = BLE_TxPower(txPower)
        }
        logger.debug("didDiscover (device=\(device),rssi=\((String(describing: device.rssi))),txPower=\((String(describing: device.txPower))))")
        // Process legacy advert only protocol
        let legacyAdvertOnlyProtocolData = (BLESensorConfiguration.interopAdvertBasedProtocolEnabled ? BLELegacyAdvertOnlyProtocolData(fromAdvertisementData: advertisementData) : nil)
        if BLESensorConfiguration.interopAdvertBasedProtocolEnabled, let legacyAdvertOnlyProtocolData = legacyAdvertOnlyProtocolData {
            device.payloadData = legacyAdvertOnlyProtocolData.payloadData
            logger.debug("didDiscover, legacy payload (device=\(device),service=\(legacyAdvertOnlyProtocolData.service.description),payload=\(legacyAdvertOnlyProtocolData.payloadData.hexEncodedString))")
        }
        if (legacyAdvertOnlyProtocolData == nil || legacyAdvertOnlyProtocolData!.connectable), deviceHasPendingTask(device) {
            connect("didDiscover", peripheral);
        } else {
            scanResults.append(device)
        }
        // Schedule scan (actual connect is initiated from scan via prioritisation logic)
        scheduleScan("didDiscover")
    }
    
    /// Successful connection to a device will initate the next pending action.
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // connect -> readRSSI -> discoverServices
        let device = database.device(peripheral, delegate: self)
        device.lastConnectedAt = Date()
        logger.debug("didConnect (device=\(device))")
        taskInitiateNextAction("didConnect", peripheral: peripheral)
    }
    
    /// Failure to connect to a device will result in de-registration for invalid devices or reconnection attempt otherwise.
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Connect fail -> Delete | Connect
        // Failure for peripherals advertising the beacon service should be transient, so try again.
        // This is also where iOS reports invalidated devices if connect is called after restore,
        // thus offers an opportunity for house keeping.
        let device = database.device(peripheral, delegate: self)
        logger.debug("didFailToConnect (device=\(device),error=\(String(describing: error)))")
        if String(describing: error).contains("Device is invalid") {
            logger.debug("Unregister invalid device (device=\(device))")
            database.delete(device, peripheral: peripheral)
        } else {
            connect("didFailToConnect", peripheral)
        }
    }
    
    /// Graceful disconnection is usually caused by device going out of range or device changing identity, thus a reconnection call is initiated
    /// here for iOS devices to resume connection where possible. This is unnecessary for Android devices as they can be rediscovered by
    /// the regular scan calls. Please note, reconnection to iOS devices is likely to fail following prolonged period of being out of range as
    /// the target device is likely to have changed identity after about 20 minutes. This requires rediscovery which is impossible if the iOS device
    /// is in background state, hence the need for enabling location and screen on to trigger rediscovery (yes, its weird, but it works).
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Disconnected -> Connect if iOS
        // Keep connection only for iOS, not necessary for Android as they are always detectable
        let device = database.device(peripheral, delegate: self)
        device.lastDisconnectedAt = Date()
        logger.debug("didDisconnectPeripheral (device=\(device),error=\(String(describing: error)))")
        if device.operatingSystem == .ios {
            // Invalidate characteristics
            device.signalCharacteristic = nil
            device.payloadCharacteristic = nil
            device.legacyPayloadCharacteristic = nil
            // Reconnect
            connect("didDisconnectPeripheral", peripheral)
        }
    }
    
    // MARK: - CBPeripheralDelegate
    
    /// Read RSSI for proximity estimation.
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        // Read RSSI -> Read Code | Notify delegates -> Scan again
        // This is the primary loop for iOS after initial connection and subscription to
        // the notifying beacon characteristic. The loop is scan -> wakeTransmitter ->
        // didUpdateValueFor -> readRSSI -> notifyDelegates -> scheduleScan -> scan
        let device = database.device(peripheral, delegate: self)
        device.rssi = BLE_RSSI(RSSI.intValue)
        logger.debug("didReadRSSI (device=\(device),rssi=\(String(describing: device.rssi)),error=\(String(describing: error)))")
        taskInitiateNextAction("didReadRSSI", peripheral: peripheral)
    }
    
    /// Service discovery triggers characteristic discovery.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // Discover services -> Discover characteristics | Disconnect
        let device = database.device(peripheral, delegate: self)
        logger.debug("didDiscoverServices (device=\(device),error=\(String(describing: error)))")
        guard let services = peripheral.services else {
            disconnect("didDiscoverServices|serviceEmpty", peripheral)
            return
        }
        for service in services {
            if (service.uuid == BLESensorConfiguration.linuxFoundationServiceUUID) ||
                (BLESensorConfiguration.legacyHeraldServiceDetectionEnabled && service.uuid == BLESensorConfiguration.legacyHeraldServiceUUID) {
                logger.debug("didDiscoverServices, found sensor service (device=\(device))")
                queue.async { peripheral.discoverCharacteristics(nil, for: service) }
                return
            } else if BLESensorConfiguration.interopOpenTraceEnabled, service.uuid == BLESensorConfiguration.interopOpenTraceServiceUUID {
                logger.debug("didDiscoverServices, found legacy service (device=\(device))")
                queue.async { peripheral.discoverCharacteristics(nil, for: service) }
                return
            }
        }
        disconnect("didDiscoverServices|serviceNotFound", peripheral)
        // The disconnect calls here shall be handled by didDisconnect which determines whether to retry for iOS or stop for Android
    }
    
    /// Characteristic discovery provides definitive classification and confirmation of device operating system to inform next actions.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Discover characteristics -> Notify delegates -> Disconnect | Wake transmitter -> Scan again
        let device = database.device(peripheral, delegate: self)
        logger.debug("didDiscoverCharacteristicsFor (device=\(device),error=\(String(describing: error)))")
        guard let characteristics = service.characteristics else {
            disconnect("didDiscoverCharacteristicsFor|characteristicEmpty", peripheral)
            return
        }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case BLESensorConfiguration.androidSignalCharacteristicUUID:
                device.operatingSystem = .android
                device.signalCharacteristic = characteristic
                logger.debug("didDiscoverCharacteristicsFor, found android signal characteristic (device=\(device))")
            case BLESensorConfiguration.iosSignalCharacteristicUUID:
                // Maintain connection with iOS devices for keep awake
                let notify = characteristic.properties.contains(.notify)
                let write = characteristic.properties.contains(.write)
                device.operatingSystem = .ios
                device.signalCharacteristic = characteristic
                queue.async { peripheral.setNotifyValue(true, for: characteristic) }
                logger.debug("didDiscoverCharacteristicsFor, found ios signal characteristic (device=\(device),notify=\(notify),write=\(write))")
            case BLESensorConfiguration.payloadCharacteristicUUID:
                device.payloadCharacteristic = characteristic
                logger.debug("didDiscoverCharacteristicsFor, found payload characteristic (device=\(device))")
            case BLESensorConfiguration.interopOpenTracePayloadCharacteristicUUID:
                device.legacyPayloadCharacteristic = characteristic
                logger.debug("didDiscoverCharacteristicsFor, found legacy payload characteristic (device=\(device))")
            default:
                logger.fault("didDiscoverCharacteristicsFor, found unknown characteristic (device=\(device),characteristic=\(characteristic.uuid))")
            }
        }
        // OpenTrace -> Read payload -> Write payload -> Disconnect
        if device.protocolIsOpenTrace, let legacyPayloadCharacteristic = device.legacyPayloadCharacteristic {
            if device.payloadData == nil || device.timeIntervalSinceLastPayloadDataUpdate > BLESensorConfiguration.interopOpenTracePayloadDataUpdateTimeInterval {
                logger.debug("didDiscoverCharacteristicsFor, read legacy payload characteristic (device=\(device))")
                queue.async { peripheral.readValue(for: legacyPayloadCharacteristic) }
            } else {
                disconnect("didDiscoverCharacteristicsFor|openTrace", peripheral)
            }
        }
        // HERALD Android -> Read payload -> Disconnect
        else if device.protocolIsHerald, device.operatingSystem == .android, let payloadCharacteristic = device.payloadCharacteristic {
            if device.payloadData == nil || device.timeIntervalSinceLastPayloadDataUpdate > BLESensorConfiguration.payloadDataUpdateTimeInterval {
                queue.async { peripheral.readValue(for: payloadCharacteristic) }
            } else {
                disconnect("didDiscoverCharacteristicsFor|android", peripheral)
            }
        }
        // Always -> Scan again
        // For initial connection, the scheduleScan call would have been made just before connect.
        // It is called again here to extend the time interval between scans.
        scheduleScan("didDiscoverCharacteristicsFor")
    }
    
    /// This iOS device will write to connected iOS devices to keep them awake, and this call back provides a backup mechanism for keeping this
    /// device awake for longer in the event that other devices are no longer responding or in range.
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // Wrote characteristic -> Scan again
        let device = database.device(peripheral, delegate: self)
        logger.debug("didWriteValueFor (device=\(device),error=\(String(describing: error)))")
        // OpenTrace -> read -> write -> disconnect
        if device.protocolIsOpenTrace {
            disconnect("didWriteValueFor|legacy", peripheral)
        }
        // For all situations, scheduleScan would have been made earlier in the chain of async calls.
        // It is called again here to extend the time interval between scans, as this is usually the
        // last call made in all paths to wake the transmitter.
        scheduleScan("didWriteValueFor")
    }
    
    /// Other iOS devices may refresh (stop/restart) their adverts at regular intervals, thus triggering this service modification callback
    /// to invalidate existing characteristics and reconnect to refresh the device data.
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        // iOS only
        // Modified service -> Invalidate beacon -> Scan
        let device = database.device(peripheral, delegate: self)
        let characteristics = invalidatedServices.map { $0.characteristics }.count
        logger.debug("didModifyServices (device=\(device),characteristics=\(characteristics))")
        guard characteristics == 0 else {
            return
        }
        device.signalCharacteristic = nil
        device.payloadCharacteristic = nil
        device.legacyPayloadCharacteristic = nil
        if peripheral.state == .connected {
            discoverServices("didModifyServices", peripheral)
        } else if peripheral.state != .connecting {
            connect("didModifyServices", peripheral)
        }
    }
    
    /// All read characteristic requests will trigger this call back to handle the response.
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Updated value -> Read RSSI | Read Payload
        // Beacon characteristic is writable, primarily to enable non-transmitting Android devices to submit their
        // beacon code and RSSI as data to the transmitter via GATT write. The characteristic is also notifying on
        // iOS devices, to offer a mechanism for waking receivers. The process works as follows, (1) receiver writes
        // blank data to transmitter, (2) transmitter broadcasts value update notification after 8 seconds, (3)
        // receiver is woken up to handle didUpdateValueFor notification, (4) receiver calls readRSSI, (5) readRSSI
        // call completes and schedules scan after 8 seconds, (6) scan writes blank data to all iOS transmitters.
        // Process repeats to keep both iOS transmitters and receivers awake while maximising time interval between
        // bluetooth calls to minimise power usage.
        let device = database.device(peripheral, delegate: self)
        logger.debug("didUpdateValueFor (device=\(device),characteristic=\(characteristic.uuid),error=\(String(describing: error)))")
        switch characteristic.uuid {
        case BLESensorConfiguration.iosSignalCharacteristicUUID:
            // Wake up call from transmitter
            logger.debug("didUpdateValueFor (device=\(device),characteristic=iosSignalCharacteristic,error=\(String(describing: error)))")
            device.lastNotifiedAt = Date()
            readRSSI("didUpdateValueFor", peripheral)
            return
        case BLESensorConfiguration.androidSignalCharacteristicUUID:
            // Should not happen as Android signal is not notifying
            logger.fault("didUpdateValueFor (device=\(device),characteristic=androidSignalCharacteristic,error=\(String(describing: error)))")
        case BLESensorConfiguration.payloadCharacteristicUUID:
            // Read payload data
            logger.debug("didUpdateValueFor (device=\(device),characteristic=payloadCharacteristic,error=\(String(describing: error)))")
            if let data = characteristic.value {
                device.payloadData = PayloadData(data)
            }
            if device.operatingSystem == .android {
                disconnect("didUpdateValueFor|payload|android", peripheral)
            }
        case BLESensorConfiguration.interopOpenTracePayloadCharacteristicUUID:
            // Read legacy payload data
            logger.debug("didUpdateValueFor (device=\(device),characteristic=legacyPayloadCharacteristic,error=\(String(describing: error)))")
            if let data = characteristic.value, let service = UUID(uuidString: BLESensorConfiguration.interopOpenTraceServiceUUID.uuidString) {
                device.payloadData = LegacyPayloadData(service: service, data: data)
            }
            // Write legacy payload data after read
            writeLegacyPayload("didUpdateValueFor|legacyPayload", peripheral)
            return
        default:
            logger.fault("didUpdateValueFor, unknown characteristic (device=\(device),characteristic=\(characteristic.uuid),error=\(String(describing: error)))")
        }
        scheduleScan("didUpdateValueFor")
        return
    }
}

