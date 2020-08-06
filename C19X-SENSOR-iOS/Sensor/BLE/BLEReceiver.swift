//
//  BLEReceiver.swift
//  C19X-SENSOR-iOS
//
//  Created by Freddy Choi on 25/07/2020.
//  Copyright © 2020 C19X. All rights reserved.
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
    private let scanTimerQueue = DispatchQueue(label: "Sensor.BLE.ConcreteBLEReceiver.Timer")
    /// Track scan interval and up time statistics for the receiver, for debug purposes.
    private let statistics = TimeIntervalSample()
    
    
    required init(queue: DispatchQueue, database: BLEDatabase, payloadDataSupplier: PayloadDataSupplier) {
        self.queue = queue
        self.database = database
        self.payloadDataSupplier = payloadDataSupplier
        super.init()
        self.central = CBCentralManager(delegate: self, queue: queue, options: [
            CBCentralManagerOptionRestoreIdentifierKey : "Sensor.BLE.ConcreteBLEReceiver",
            CBCentralManagerOptionShowPowerAlertKey : true])
        database.add(delegate: self)
    }
    
    func add(delegate: SensorDelegate) {
        delegates.append(delegate)
    }
    
    func start() {
        logger.debug("start")
        // Start scanning
        if central.state == .poweredOn {
            scan("start")
        }
    }
    
    func stop() {
        logger.debug("stop")
        guard central.isScanning else {
            logger.fault("stop denied, already stopped")
            return
        }
        // Stop scanning
        scanTimer?.cancel()
        scanTimer = nil
        queue.async { self.central.stopScan() }
        // Cancel all connections, the resulting didDisconnect and didFailToConnect
        database.devices().forEach() { device in
            if let peripheral = device.peripheral, peripheral.state != .disconnected {
                disconnect("stop", peripheral)
            }
        }
    }
    
    /**
     Scan for peripherals advertising the beacon service.
     */
    private func taskScanForPeripherals() {
        // Scan for peripherals -> didDiscover
        central.scanForPeripherals(
            withServices: [BLESensorConfiguration.serviceUUID],
            options: [CBCentralManagerScanOptionSolicitedServiceUUIDsKey: [BLESensorConfiguration.serviceUUID]])
    }
    
    /**
     Register all connected peripherals advertising the sensor service as a device.
     */
    private func taskRegisterConnectedPeripherals() {
        central.retrieveConnectedPeripherals(withServices: [BLESensorConfiguration.serviceUUID]).forEach() { peripheral in
            let targetIdentifier = TargetIdentifier(peripheral: peripheral)
            let device = database.device(targetIdentifier)
            if device.peripheral == nil || device.peripheral != peripheral {
                logger.debug("taskRegisterConnectedPeripherals (identifier=\(targetIdentifier))")
                _ = database.device(peripheral, delegate: self)
            }
        }
    }

    /**
     Resolve peripheral for all database devices. This enables the symmetric connection feature where connections from central to peripheral (BLETransmitter) registers the existence
     of a potential peripheral for resolution by this central (BLEReceiver).
     */
    private func taskResolveDevicePeripherals() {
        let devicesToResolve = database.devices().filter { $0.peripheral == nil }
        devicesToResolve.forEach() { device in
            guard let identifier = UUID(uuidString: device.identifier) else {
                return
            }
            let peripherals = central.retrievePeripherals(withIdentifiers: [identifier])
            if let peripheral = peripherals.last {
                logger.debug("taskResolveDevicePeripherals (resolved=\(device.identifier))")
                _ = database.device(peripheral, delegate: self)
            }
        }
    }
    
    /**
     Remove devices that have not been updated for over an hour, as the UUID is likely to have changed after being out of range for over 20 minutes, so it will require discovery.
     */
    private func taskRemoveExpiredDevices() {
        let devicesToRemove = database.devices().filter { Date().timeIntervalSince($0.lastUpdatedAt) > TimeInterval.hour }
        devicesToRemove.forEach() { device in
            logger.debug("taskRemoveExpiredDevices (removed=\(device.identifier))")
            database.delete(device.identifier)
            if let peripheral = device.peripheral {
                disconnect("taskRemoveExpiredDevices", peripheral)
            }
        }
    }
    
    /**
     Remove devices with the same payload data but different peripherals.
     */
    private func taskRemoveDuplicatePeripherals() {
        var index: [PayloadData:BLEDevice] = [:]
        let devices = database.devices()
        devices.forEach() { device in
            guard let payloadData = device.payloadData else {
                return
            }
            guard let duplicate = index[payloadData] else {
                return
            }
            var keeping = device
            if device.peripheral != nil, duplicate.peripheral == nil {
                keeping = device
            } else if duplicate.peripheral != nil, device.peripheral == nil {
                keeping = duplicate
            } else if device.lastUpdatedAt > duplicate.lastUpdatedAt {
                keeping = device
            } else {
                keeping = duplicate
            }
            let discarding = (keeping.identifier == device.identifier ? duplicate : device)
            index[payloadData] = keeping
            database.delete(discarding.identifier)
            self.logger.debug("taskRemoveDuplicatePeripherals (payload=\(payloadData.description),device=\(device.identifier),duplicate=\(duplicate.identifier),keeping=\((keeping.identifier == device.identifier ? "former" : "latter")))")
            // CoreBluetooth will eventually give warning and disconnect actual duplicate silently.
            // While calling disconnect here is cleaner but it will trigger didDiscover and
            // retain the duplicates. Expect to see message :
            // [CoreBluetooth] API MISUSE: Forcing disconnection of unused peripheral
            // <CBPeripheral: XXX, identifier = XXX, name = iPhone, state = connected>.
            // Did you forget to cancel the connection?
        }
    }
    
    /**
     Wake transmitter on all connected iOS devices
     */
    private func taskWakeTransmitters() {
        database.devices().forEach() { device in
            guard device.operatingSystem == .ios, let peripheral = device.peripheral, peripheral.state == .connected else {
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
        // Define fixed concurrent connection quota
        let concurrentConnectionQuota = 5
        // Get connection status
        var connected: [BLEDevice] = []
        var connecting: [BLEDevice] = []
        var disconnected: [BLEDevice] = []
        database.devices().forEach() { device in
            guard let peripheral = device.peripheral else {
                return
            }
            switch peripheral.state {
            case .connected:
                connected.append(device)
            case .connecting:
                connecting.append(device)
            default:
                disconnected.append(device)
            }
        }
        logger.debug("taskConnect status (connected=\(connected.count),connecting=\(connecting.count),disconnected=\(disconnected.count))")
        connected.forEach() { device in
            logger.debug("taskConnect connected (device=\(device.identifier),operatingSystem=\(device.operatingSystem.rawValue))")
        }
        
        // Establish connections to keep
        // - Unknown or restored devices take highest priority to identify operating system
        // - Android connections are short lived and should be left to complete
        // - iOS connections for getting the payload data should be left to complete
        var keep: [BLEDevice] = []
        let keepUnknown = connected.filter({ $0.operatingSystem == .unknown })
        let keepRestored = connected.filter({ $0.operatingSystem == .restored })
        let keepAndroid = connected.filter({ $0.operatingSystem == .android })
        let keepIosNew = connected.filter({ $0.operatingSystem == .ios && $0.payloadData == nil })
        keep.append(contentsOf: keepUnknown)
        keep.append(contentsOf: keepRestored)
        keep.append(contentsOf: keepAndroid)
        keep.append(contentsOf: keepIosNew)
        logger.debug("taskConnect keep (unknown=\(keepUnknown.count),restored=\(keepRestored.count),android=\(keepAndroid.count),ios=\(keepIosNew.count))")
        
        // Establish connections to discard
        // - iOS devices with payload data, sorted by last updated at timestamp (most recent first)
        var discard: [BLEDevice] = []
        let discardIos = connected.filter({ $0.operatingSystem == .ios && $0.payloadData != nil }).sorted(by: { $0.lastUpdatedAt > $1.lastUpdatedAt })
        discard.append(contentsOf: discardIos)
        
        // Discard connections to meet quota
        let capacity = concurrentConnectionQuota - connected.count
        if capacity <= 0 {
            logger.fault("taskConnect quota exceeded, suspending new connections (connected=\(connected.count),keep=\(keep.count),quota=\(concurrentConnectionQuota))")
            // Keep most recently updated iOS devices first as devices that haven't been updated for a while may be going out of range
            let surplusCapacity = concurrentConnectionQuota - keep.count
            if surplusCapacity > 0 {
                _ = discard.dropFirst(capacity)
            }
            discard.forEach() { device in
                guard let peripheral = device.peripheral else {
                    return
                }
                disconnect("taskConnect|discard", peripheral)
            }
        }
        
        // Establish pending connections
        // - New devices without payload data
        // - Android devices sorted by last payload shared at timestamp (least recent first)
        // - iOS devices sorted by last updated at timestamp (least recent first)
        // - Alternate between Android and iOS for fairness
        var pending: [BLEDevice] = []
        let pendingNew = disconnected.filter({ $0.operatingSystem == .unknown || $0.operatingSystem == .restored || $0.payloadData == nil })
        var pendingIos = disconnected.filter({ $0.operatingSystem == .ios }).sorted(by: { $0.lastUpdatedAt < $1.lastUpdatedAt })
        var pendingAndroid = disconnected.filter({ $0.operatingSystem == .android && $0.timeIntervalSinceLastPayloadShared > BLESensorConfiguration.payloadSharingTimeInterval }).sorted(by: { $0.payloadSharingDataLastUpdatedAt < $1.payloadSharingDataLastUpdatedAt })
        logger.debug("taskConnect pending (unknown/restored=\(pendingNew.count),ios=\(pendingIos.count),android=\(pendingAndroid.count),capacity=\(capacity))")
        var pendingAlternated: [BLEDevice] = []
        while !(pendingIos.isEmpty && pendingAndroid.isEmpty) {
            guard let iosDevice = pendingIos.first else {
                pendingAlternated.append(contentsOf: pendingAndroid)
                pendingAndroid.removeAll()
                break
            }
            guard let androidDevice = pendingAndroid.first else {
                pendingAlternated.append(contentsOf: pendingIos)
                pendingIos.removeAll()
                break
            }
            pendingIos.remove(at: 0)
            pendingAndroid.remove(at: 0)
            if iosDevice.lastUpdatedAt < androidDevice.lastUpdatedAt {
                pendingAlternated.append(iosDevice)
                pendingAlternated.append(androidDevice)
            } else {
                pendingAlternated.append(androidDevice)
                pendingAlternated.append(iosDevice)
            }
        }
        pending.append(contentsOf: pendingNew)
        pending.append(contentsOf: pendingAlternated)
        let pendingQueue = pending.map { $0.operatingSystem.rawValue + ":" + $0.timeIntervalSinceLastUpdate.description }
        logger.debug("taskConnect pending (queue=\(pendingQueue))")
        if pending.count > capacity {
            _ = pending.dropLast(pending.count - capacity)
        }
        pending.forEach() { device in
            guard let peripheral = device.peripheral else {
                return
            }
            connect("taskConnect|pending", peripheral)
        }
        
        // Refresh existing connections
        var refresh: [BLEDevice] = []
        let refreshUnknown = connected.filter({ $0.operatingSystem == .unknown })
        let refreshRestored = connected.filter({ $0.operatingSystem == .restored })
        let refreshAndroid = connected.filter({ $0.operatingSystem == .android })
        refresh.append(contentsOf: refreshUnknown)
        refresh.append(contentsOf: refreshRestored)
        refresh.append(contentsOf: refreshAndroid)
        logger.debug("taskConnect refresh (unknown=\(refreshUnknown.count),restored=\(refreshRestored.count),android=\(refreshAndroid.count))")
        refresh.forEach() { device in
            guard let peripheral = device.peripheral else {
                return
            }
            connect("taskConnect|refresh", peripheral)
        }
    }
    
    /// All work starts from scan loop.
    func scan(_ source: String) {
        statistics.add()
        logger.debug("scan (source=\(source),statistics={\(statistics.description)})")
        guard central.state == .poweredOn else {
            logger.fault("scan failed, bluetooth is not powered on")
            return
        }
        queue.async { self.taskScanForPeripherals() }
        queue.async { self.taskRegisterConnectedPeripherals() }
        queue.async { self.taskResolveDevicePeripherals() }
        queue.async { self.taskRemoveExpiredDevices() }
        queue.async { self.taskRemoveDuplicatePeripherals() }
        queue.async { self.taskWakeTransmitters() }
        queue.async { self.taskConnect() }
        scheduleScan("scan")
    }
    
    /**
     Schedule scan for beacons after a delay of 8 seconds to start scan again just before
     state change from background to suspended. Scan is sufficient for finding Android
     devices repeatedly in both foreground and background states.
     */
    private func scheduleScan(_ source: String) {
        scanTimer?.cancel()
        scanTimer = DispatchSource.makeTimerSource(queue: scanTimerQueue)
        scanTimer?.schedule(deadline: DispatchTime.now() + BLESensorConfiguration.notificationDelay)
        scanTimer?.setEventHandler { [weak self] in
            self?.scan("scheduleScan|"+source)
        }
        scanTimer?.resume()
    }
    
    /// Initiate next action on peripheral based on current state and information available
    private func taskInitiateNextAction(_ source: String, peripheral: CBPeripheral) {
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        let device = database.device(peripheral, delegate: self)
        if device.rssi == nil {
            // 1. RSSI
            logger.debug("taskInitiateNextAction (goal=rssi,peripheral=\(targetIdentifier))")
            readRSSI("taskInitiateNextAction|" + source, peripheral)
        } else if device.signalCharacteristic == nil || device.payloadCharacteristic == nil || device.payloadSharingCharacteristic == nil {
            // 2. Characteristics
            logger.debug("taskInitiateNextAction (goal=characteristics,peripheral=\(targetIdentifier))")
            discoverServices("taskInitiateNextAction|" + source, peripheral)
        } else if device.payloadData == nil {
            // 3. Payload
            logger.debug("taskInitiateNextAction (goal=payload,peripheral=\(targetIdentifier))")
            readPayload("taskInitiateNextAction|" + source, device)
        } else if device.timeIntervalSinceLastPayloadShared > BLESensorConfiguration.payloadSharingTimeInterval {
            // 4. Payload sharing
            logger.debug("taskInitiateNextAction (goal=payloadSharing|\(device.timeIntervalSinceLastPayloadShared.description),peripheral=\(targetIdentifier))")
            readPayloadSharing("taskInitiateNextAction|" + source, device)
        } else if device.operatingSystem != .ios {
            // 5. Disconnect Android
            logger.debug("taskInitiateNextAction (goal=disconnect|\(device.operatingSystem.rawValue),peripheral=\(targetIdentifier))")
            disconnect("taskInitiateNextAction|" + source, peripheral)
        } else {
            // 6. Scan
            logger.debug("taskInitiateNextAction (goal=scan,peripheral=\(targetIdentifier))")
            scheduleScan("taskInitiateNextAction|" + source)
        }
    }
    

    
    /**
     Connect peripheral. Scanning is stopped temporarily, as recommended by Apple documentation, before initiating connect, otherwise
     pending scan operations tend to take priority and connect takes longer to start. Scanning is scheduled to resume later, to ensure scan
     resumes, even if connect fails.
     */
    private func connect(_ source: String, _ peripheral: CBPeripheral) {
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        logger.debug("connect (source=\(source),peripheral=\(targetIdentifier))")
        guard central.state == .poweredOn else {
            logger.fault("connect denied, central not powered on (source=\(source),peripheral=\(targetIdentifier))")
            return
        }
        queue.async {
            self.central.retrievePeripherals(withIdentifiers: [peripheral.identifier]).forEach{
                self.central.connect($0)
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
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        logger.debug("disconnect (source=\(source),peripheral=\(targetIdentifier))")
        guard peripheral.state == .connected || peripheral.state == .connecting else {
            logger.fault("disconnect denied, peripheral not connected or connecting (source=\(source),peripheral=\(targetIdentifier))")
            return
        }
        queue.async { self.central.cancelPeripheralConnection(peripheral) }
    }
    
    /// Read RSSI
    private func readRSSI(_ source: String, _ peripheral: CBPeripheral) {
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        logger.debug("readRSSI (source=\(source),peripheral=\(targetIdentifier))")
        guard peripheral.state == .connected else {
            logger.fault("readRSSI denied, peripheral not connected (source=\(source),peripheral=\(targetIdentifier))")
            scheduleScan("readRSSI")
            return
        }
        queue.async { peripheral.readRSSI() }
    }
    
    /// Discover services
    private func discoverServices(_ source: String, _ peripheral: CBPeripheral) {
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        logger.debug("discoverServices (source=\(source),peripheral=\(targetIdentifier))")
        guard peripheral.state == .connected else {
            logger.fault("discoverServices denied, peripheral not connected (source=\(source),peripheral=\(targetIdentifier))")
            scheduleScan("discoverServices")
            return
        }
        queue.async { peripheral.discoverServices([BLESensorConfiguration.serviceUUID]) }
    }
    
    private func readPayload(_ source: String, _ device: BLEDevice) {
        logger.debug("readPayload (source=\(source),peripheral=\(device.identifier))")
        guard let peripheral = device.peripheral, peripheral.state == .connected else {
            logger.fault("readPayload denied, peripheral not connected (source=\(source),peripheral=\(device.identifier))")
            return
        }
        guard let payloadCharacteristic = device.payloadCharacteristic else {
            logger.fault("readPayload denied, device missing payload characteristic (source=\(source),peripheral=\(device.identifier))")
            discoverServices("readPayload", peripheral)
            return
        }
        if device.operatingSystem == .android, let peripheral = device.peripheral {
            discoverServices("readPayload|android", peripheral)
        } else {
            peripheral.readValue(for: payloadCharacteristic)
        }
    }

    private func readPayloadSharing(_ source: String, _ device: BLEDevice) {
        logger.debug("readPayloadSharing (source=\(source),peripheral=\(device.identifier))")
        guard let peripheral = device.peripheral, peripheral.state == .connected else {
            logger.fault("readPayloadSharing denied, peripheral not connected (source=\(source),peripheral=\(device.identifier))")
            return
        }
        guard let payloadSharingCharacteristic = device.payloadSharingCharacteristic else {
            logger.fault("readPayload denied, device missing payload sharing characteristic (source=\(source),peripheral=\(device.identifier))")
            discoverServices("readPayloadSharing", peripheral)
            return
        }
        if device.operatingSystem == .android, let peripheral = device.peripheral {
            discoverServices("readPayloadSharing|android", peripheral)
        } else {
            peripheral.readValue(for: payloadSharingCharacteristic)
        }
    }

    /**
     Wake transmitter by writing blank data to the beacon characteristic. This will trigger the transmitter to generate a data value update notification
     in 8 seconds, which in turn will trigger this receiver to receive a didUpdateValueFor call to keep both the transmitter and receiver awake, while
     maximising the time interval between bluetooth calls to minimise power usage.
     */
    private func wakeTransmitter(_ source: String, _ device: BLEDevice) {
        guard device.operatingSystem == .ios, let peripheral = device.peripheral, let characteristic = device.signalCharacteristic else {
            return
        }
        logger.debug("wakeTransmitter (source=\(source),peripheral=\(device.identifier),write=\(characteristic.properties.contains(.write))")
        peripheral.writeValue(emptyData, for: characteristic, type: .withResponse)
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
                logger.debug("willRestoreState (peripheral=\(targetIdentifier))")
            }
        }
        // Reconnection check performed in scan following centralManagerDidUpdateState:central.state == .powerOn
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // Bluetooth on -> Scan
        if (central.state == .poweredOn) {
            logger.debug("Update state (state=poweredOn))")
            scan("updateState")
        } else {
            if #available(iOS 10.0, *) {
                logger.debug("Update state (state=\(central.state.description))")
            } else {
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
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Extract discovered data
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        let rssi = RSSI.intValue
        let txPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
        logger.debug("didDiscover (peripheral=\(targetIdentifier),rssi=\(rssi),txPower=\((String(describing: txPower))))")
        
        // Populate device database
        let device = database.device(peripheral, delegate: self)
        device.rssi = BLE_RSSI(rssi)
        if txPower != nil {
            device.txPower = BLE_TxPower(txPower!)
        }
        // Schedule scan (actual connect is initiated from scan via prioritisation logic)
        scheduleScan("didDiscover")
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // connect -> readRSSI -> discoverServices
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        logger.debug("didConnect (peripheral=\(targetIdentifier))")
        taskInitiateNextAction("didConnect", peripheral: peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Connect fail -> Delete | Connect
        // Failure for peripherals advertising the beacon service should be transient, so try again.
        // This is also where iOS reports invalidated devices if connect is called after restore,
        // thus offers an opportunity for house keeping.
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        logger.debug("didFailToConnect (peripheral=\(targetIdentifier),error=\(String(describing: error)))")
        if String(describing: error).contains("Device is invalid") {
            logger.debug("Unregister invalid device (peripheral=\(targetIdentifier))")
            database.delete(targetIdentifier)
        } else {
            connect("didFailToConnect", peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Disconnected -> Connect if iOS
        // Keep connection only for iOS, not necessary for Android as they are always detectable
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        logger.debug("didDisconnectPeripheral (peripheral=\(targetIdentifier),error=\(String(describing: error)))")
        let device = database.device(peripheral, delegate: self)
        if device.operatingSystem == .ios {
            // Invalidate characteristics
            device.signalCharacteristic = nil
            device.payloadCharacteristic = nil
            device.payloadSharingCharacteristic = nil
            // Reconnect
            connect("didDisconnectPeripheral", peripheral)
        }
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        // Read RSSI -> Read Code | Notify delegates -> Scan again
        // This is the primary loop for iOS after initial connection and subscription to
        // the notifying beacon characteristic. The loop is scan -> wakeTransmitter ->
        // didUpdateValueFor -> readRSSI -> notifyDelegates -> scheduleScan -> scan
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        let rssi = RSSI.intValue
        logger.debug("didReadRSSI (peripheral=\(targetIdentifier),rssi=\(rssi),error=\(String(describing: error)))")
        let device = database.device(peripheral, delegate: self)
        device.rssi = BLE_RSSI(rssi)
        taskInitiateNextAction("didReadRSSI", peripheral: peripheral)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // Discover services -> Discover characteristics | Disconnect
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        logger.debug("didDiscoverServices (peripheral=\(targetIdentifier),error=\(String(describing: error)))")
        guard let services = peripheral.services else {
            disconnect("didDiscoverServices|serviceEmpty", peripheral)
            return
        }
        for service in services {
            if (service.uuid == BLESensorConfiguration.serviceUUID) {
                logger.debug("didDiscoverServices, found sensor service (peripheral=\(targetIdentifier))")
                peripheral.discoverCharacteristics(nil, for: service)
                return
            }
        }
        disconnect("didDiscoverServices|serviceNotFound", peripheral)
        // The disconnect calls here shall be handled by didDisconnect which determines whether to retry for iOS or stop for Android
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Discover characteristics -> Notify delegates -> Disconnect | Wake transmitter -> Scan again
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        logger.debug("didDiscoverCharacteristicsFor (peripheral=\(targetIdentifier),error=\(String(describing: error)))")
        guard let characteristics = service.characteristics else {
            disconnect("didDiscoverCharacteristicsFor|characteristicEmpty", peripheral)
            return
        }
        let device = database.device(peripheral, delegate: self)
        for characteristic in characteristics {
            switch characteristic.uuid {
            case BLESensorConfiguration.androidSignalCharacteristicUUID:
                device.operatingSystem = .android
                device.signalCharacteristic = characteristic
                logger.debug("didDiscoverCharacteristicsFor, found android signal characteristic (peripheral=\(targetIdentifier),os=android)")
            case BLESensorConfiguration.iosSignalCharacteristicUUID:
                let notify = characteristic.properties.contains(.notify)
                let write = characteristic.properties.contains(.write)
                device.operatingSystem = .ios
                device.signalCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
                logger.debug("didDiscoverCharacteristicsFor, found ios signal characteristic (peripheral=\(targetIdentifier),os=ios,notify=\(notify),write=\(write))")
            case BLESensorConfiguration.payloadCharacteristicUUID:
                device.payloadCharacteristic = characteristic
                logger.debug("didDiscoverCharacteristicsFor, found payload characteristic (peripheral=\(targetIdentifier))")
            case BLESensorConfiguration.payloadSharingCharacteristicUUID:
                device.payloadSharingCharacteristic = characteristic
                logger.debug("didDiscoverCharacteristicsFor, found payload sharing characteristic (peripheral=\(targetIdentifier))")
            default:
                logger.fault("didDiscoverCharacteristicsFor, found unknown characteristic (peripheral=\(targetIdentifier),characteristic=\(characteristic.uuid))")
            }
        }
        // Android -> Read payload
        if device.operatingSystem == .android {
            if device.payloadData == nil, let payloadCharacteristic = device.payloadCharacteristic {
                peripheral.readValue(for: payloadCharacteristic)
            } else if device.timeIntervalSinceLastPayloadShared > BLESensorConfiguration.payloadSharingTimeInterval, let payloadSharingCharacteristic = device.payloadSharingCharacteristic {
                peripheral.readValue(for: payloadSharingCharacteristic)
            } else {
                disconnect("didDiscoverCharacteristicsFor|android", peripheral)
            }
        }
        // Always -> Scan again
        // For initial connection, the scheduleScan call would have been made just before connect.
        // It is called again here to extend the time interval between scans.
        scheduleScan("didDiscoverCharacteristicsFor")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // Wrote characteristic -> Scan again
        let targetIdentifier = TargetIdentifier(peripheral: peripheral)
        logger.debug("didWriteValueFor (peripheral=\(targetIdentifier),error=\(String(describing: error)))")
        // For all situations, scheduleScan would have been made earlier in the chain of async calls.
        // It is called again here to extend the time interval between scans, as this is usually the
        // last call made in all paths to wake the transmitter.
        scheduleScan("didWriteValueFor")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        // iOS only
        // Modified service -> Invalidate beacon -> Scan
        let device = database.device(peripheral, delegate: self)
        let characteristics = invalidatedServices.map { $0.characteristics }.count
        logger.debug("didModifyServices (peripheral=\(device.identifier),characteristics=\(characteristics))")
        guard characteristics == 0 else {
            return
        }
        device.signalCharacteristic = nil
        device.payloadCharacteristic = nil
        device.payloadSharingCharacteristic = nil
        if peripheral.state == .connected {
            discoverServices("didModifyServices", peripheral)
        } else if peripheral.state != .connecting {
            connect("didModifyServices", peripheral)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // iOS only
        // Updated value -> Read RSSI
        // Beacon characteristic is writable, primarily to enable non-transmitting Android devices to submit their
        // beacon code and RSSI as data to the transmitter via GATT write. The characteristic is also notifying on
        // iOS devices, to offer a mechanism for waking receivers. The process works as follows, (1) receiver writes
        // blank data to transmitter, (2) transmitter broadcasts value update notification after 8 seconds, (3)
        // receiver is woken up to handle didUpdateValueFor notification, (4) receiver calls readRSSI, (5) readRSSI
        // call completes and schedules scan after 8 seconds, (6) scan writes blank data to all iOS transmitters.
        // Process repeats to keep both iOS transmitters and receivers awake while maximising time interval between
        // bluetooth calls to minimise power usage.
        let device = database.device(peripheral, delegate: self)
        logger.debug("didUpdateValueFor (peripheral=\(device.identifier),characteristic=\(characteristic.uuid),error=\(String(describing: error)))")
        switch characteristic.uuid {
        case BLESensorConfiguration.iosSignalCharacteristicUUID:
            // Wake up call from transmitter
            logger.debug("didUpdateValueFor (peripheral=\(device.identifier),characteristic=iosSignalCharacteristic,error=\(String(describing: error)))")
            device.lastNotifiedAt = Date()
            readRSSI("didUpdateValueFor", peripheral)
            return
        case BLESensorConfiguration.androidSignalCharacteristicUUID:
            // Should not happen as Android signal is not notifying
            logger.debug("didUpdateValueFor (peripheral=\(device.identifier),characteristic=androidSignalCharacteristic,error=\(String(describing: error)))")
        case BLESensorConfiguration.payloadCharacteristicUUID:
            // Read payload data
            logger.debug("didUpdateValueFor (peripheral=\(device.identifier),characteristic=payloadCharacteristic,error=\(String(describing: error)))")
            if let data = characteristic.value {
                device.payloadData = PayloadData(data)
            }
            if device.operatingSystem == .android {
                disconnect("didUpdateValueFor|payload|android", peripheral)
            }
        case BLESensorConfiguration.payloadSharingCharacteristicUUID:
            logger.debug("didUpdateValueFor (peripheral=\(device.identifier),characteristic=payloadSharingCharacteristic,error=\(String(describing: error)))")
            if let data = characteristic.value {
                let payloads = payloadDataSupplier.payload(data)
                payloads.forEach() { payload in
                    _ = database.device(payload)
                }
                delegates.forEach { $0.sensor(.BLE, didShare: payloads, fromTarget: device.identifier)}
            }
            device.payloadSharingDataLastUpdatedAt = Date()
            if device.operatingSystem == .android {
                disconnect("didUpdateValueFor|payloadSharing|android", peripheral)
            }
        default:
            logger.fault("didUpdateValueFor, unknown characteristic (peripheral=\(device.identifier),characteristic=\(characteristic.uuid),error=\(String(describing: error)))")
        }
        scheduleScan("didUpdateValueFor")
        return
    }
}

