//
//  BLEReceiver.swift
//  
//
//  Created  on 25/07/2020.
//  Copyright © 2020 . All rights reserved.
//

import Foundation
import CoreBluetooth
import os

/**
 Beacon receiver scans for peripherals with fixed service UUID.
 */
protocol BLEReceiver {
    
    /**
     Start receiver. The actual start is triggered by bluetooth state changes.
     */
    func start()
    
    /**
     Stop and resets receiver.
     */
    func stop()
    
    /**
     Delegates for receiving beacon detection events.
     */
    func add(_ delegate: SensorDelegate)
    
    /**
     Scan for beacons. This is normally called when bluetooth powers on, but also called by
     background app refresh task in the AppDelegate as backup for keeping the receiver awake.
     */
    func scan(_ source: String)
    
    /**
     Scan for central.
     */
    func scan(_ source: String, central: CBCentral)
}



/**
 Operating system type is either Android or iOS. The distinction is necessary as the
 two are handled very differently to reduce chance of error (Android) and ensure
 background scanning works (iOS).
 */
enum OperatingSystem {
    case android
    case ios
    case restored
    case unknown
}

/**
 Beacon peripheral for collating information (beacon code) acquired from asynchronous callbacks.
 */
class Beacon {
    /// Peripheral underpinning the beacon.
    var peripheral: CBPeripheral {
        didSet { lastUpdatedAt = Date() }
    }

    /**
     Operating system (Android | iOS) distinguished by whether the beacon characteristic supports
     notify (iOS only). Android devices are discoverable by iOS in all circumstances, thus a connect
     if only required on first contact, or after Android BLE address change which makes the peripheral
     appear as a new peripheral. While the beacon code does change on the Android side, the fact
     that the BLE address is constant makes it unnecessary to reconnect to get the latest code, i.e.
     no security benefit. iOS on the other hand requires an open connection with another iOS device
     to ensure background scan (via writeValue to Transmitter, delay on Transmitter, then receive
     didUpdateValueFor, which triggers readRSSI) continues to function when both devices are in
     background mode.
     */
    var operatingSystem: OperatingSystem? {
        didSet { lastUpdatedAt = Date() }
    }
    /// Notifying beacon characteristic (iOS peripherals only).
    var signalCharacteristic: CBCharacteristic? {
        didSet { lastUpdatedAt = Date() }
    }
    /// RSSI value obtained from either scanForPeripheral or readRSSI.
    var rssi: BLE_RSSI? {
        didSet { lastUpdatedAt = Date() }
    }
    /// Beacon code obtained from the lower 64-bits of the beacon characteristic UUID.
    var code: BeaconCode? {
        didSet {
            lastUpdatedAt = Date()
            codeUpdatedAt = Date()
        }
    }
    
    /**
     Last update timestamp for beacon code. Need to track this to invalidate codes from
     yesterday. It is unnecessary to invalidate old codes obtained during a day as the fact
     that the BLE address is constant (Android) or the connection is open (iOS) means
     changing the code will offer no security benefit, but increases connection failure risks,
     especially for Android devices.
     */
    private var codeUpdatedAt = Date.distantPast
    /**
     Last update timestamp for any beacon information. Need to track this to invalidate
     peripherals that have not been seen for a long time to avoid holding on to an ever
     growing table of beacons and pending connections to iOS devices. Invalidated
     beacons can be discovered again in the future by scan instead.
     */
    var lastUpdatedAt = Date.distantPast
    /// Track connection interval and up time statistics for this beacon, for debug purposes.
    let statistics = TimeIntervalSample()
    
    /**
     Beacon identifier is the same as the peripheral identifier.
     */
    var uuidString: String { get { peripheral.identifier.uuidString } }
    /**
     Beacon is ready if all the information is available (operatingSystem, RSSI, code), and
     the code was acquired today (day code changes at midnight everyday).
     */
    var isReady: Bool { get {
        guard operatingSystem != nil, code != nil, rssi != nil else {
            return false
        }
        let today = UInt64(Date().timeIntervalSince1970).dividedReportingOverflow(by: UInt64(86400))
        let createdOnDay = UInt64(codeUpdatedAt.timeIntervalSince1970).dividedReportingOverflow(by: UInt64(86400))
        return createdOnDay == today
    } }
    var isExpired: Bool { get {
        // Expiry after an hour because device UUID would have changed after about 20 minutes
        Date().timeIntervalSince(lastUpdatedAt) > TimeInterval.hour
    } }
    var timeIntervalSinceLastUpdate: TimeInterval { get {
        Date().timeIntervalSince(lastUpdatedAt)
    }}
    
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
    }
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
class ConcreteBLEReceiver: NSObject, BLEReceiver, CBCentralManagerDelegate, CBPeripheralDelegate {
    private let logger = ConcreteLogger(subsystem: "Sensor", category: "BLE.ConcreteBLEReceiver")
    /// Dedicated sequential queue for all beacon transmitter and receiver tasks.
    private let queue: DispatchQueue!
    /// Database of peripherals
    private let database: BLEDatabase
    /// Central manager for managing all connections, using a single manager for simplicity.
    private var central: CBCentralManager!
    /// Table of known beacons, indexed by the peripheral UUID.
    private var beacons: [String: Beacon] = [:]
    /// Dummy data for writing to the transmitter to trigger state restoration or resume from suspend state to background state.
    private let emptyData = Data(repeating: 0, count: 0)
    /**
     Shifting timer for triggering peripheral scan just before the app switches from background to suspend state following a
     call to CoreBluetooth delegate methods. Apple documentation suggests the time limit is about 10 seconds.
     */
    private var scanTimer: DispatchSourceTimer?
    /// Dedicated sequential queue for the shifting timer.
    private let scanTimerQueue = DispatchQueue(label: "Sensor.BLE.ConcreteBLEReceiver.Timer")
    /// Delegates for receiving beacon detection events.
    private var delegates: [SensorDelegate] = []
    /// Track scan interval and up time statistics for the receiver, for debug purposes.
    private let statistics = TimeIntervalSample()
    
    
    required init(queue: DispatchQueue, database: BLEDatabase) {
        self.queue = queue
        self.database = database
        super.init()
        self.central = CBCentralManager(delegate: self, queue: queue, options: [
            CBCentralManagerOptionRestoreIdentifierKey : "Sensor.BLE.ConcreteBLEReceiver",
            CBCentralManagerOptionShowPowerAlertKey : true])
    }
    
    func add(_ delegate: SensorDelegate) {
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
        beacons.values.forEach() { beacon in
            if beacon.peripheral.state != .disconnected {
                disconnect("stop", beacon.peripheral)
            }
        }
    }
    
    func scan(_ source: String, central: CBCentral) {
        let uuid = central.identifier.uuidString
        if beacons[uuid] == nil {
            logger.debug("scan hint found unknown peripheral (source=\(source),peripheral=\(uuid))")
            queue.async {
                let peripherals = self.central.retrievePeripherals(withIdentifiers: [central.identifier])
                if let peripheral = peripherals.last {
                    self.logger.debug("scan hint resolved unknown peripheral (source=\(source),peripheral=\(peripheral.identifier.description))")
                    peripheral.delegate = self
                    self.beacons[uuid] = Beacon(peripheral: peripheral)
                    self.beacons[uuid]?.operatingSystem = .unknown
                    self.connect("scanHint|central|unknown|" + peripheral.state.description, peripheral)
                } else {
                    self.logger.fault("scan hint cannot resolve unknown peripheral (source=\(source),peripheral=\(uuid))")
                }
            }
        }
    }
    
    func scan(_ source: String) {
        statistics.add()
        logger.debug("scan (source=\(source),statistics={\(statistics.description)})")
        guard central.state == .poweredOn else {
            logger.fault("scan failed, bluetooth is not powered on")
            return
        }
        queue.async {
            // Scan for peripherals -> didDiscover
            self.central.scanForPeripherals(
                withServices: [BLESensorConfiguration.serviceUUID],
                options: [CBCentralManagerScanOptionSolicitedServiceUUIDsKey: [BLESensorConfiguration.serviceUUID]])
        }
        queue.async {
            // Connected peripherals -> Check registration
            self.central.retrieveConnectedPeripherals(withServices: [BLESensorConfiguration.serviceUUID]).forEach() { peripheral in
                let uuid = peripheral.identifier.uuidString
                if self.beacons[uuid] == nil {
                    self.logger.fault("scan found connected but unknown peripheral (peripheral=\(uuid))")
                    peripheral.delegate = self
                    self.beacons[uuid] = Beacon(peripheral: peripheral)
                    self.beacons[uuid]?.operatingSystem = .unknown
                }
            }
        }
        queue.async {
            // All peripherals -> Discard expired beacons
            self.beacons.values.filter{$0.isExpired}.forEach { beacon in
                let uuid = beacon.uuidString
                self.logger.debug("scan found expired peripheral (peripheral=\(uuid))")
                self.beacons[uuid] = nil
                self.disconnect("scan|expired", beacon.peripheral)
            }
        }
        queue.async {
            // All peripherals -> De-duplicate based on beacon code
            var codes: [BeaconCode:Beacon] = [:]
            self.beacons.forEach() { uuid, beacon in
                guard let code = beacon.code else {
                    return
                }
                guard let duplicate = codes[code] else {
                    codes[code] = beacon
                    return
                }
                if let lastUpdatedAt = self.beacons[uuid]?.lastUpdatedAt, lastUpdatedAt > duplicate.lastUpdatedAt {
                    self.logger.debug("scan found duplicate peripheral (code=\(code.description),peripheral=\(uuid.description),duplicateOf=\(duplicate.uuidString),keeping=former)")
                    self.beacons[duplicate.uuidString] = nil
                    codes[code] = beacon
                } else {
                    self.logger.debug("scan found duplicate peripheral (code=\(code.description),peripheral=\(uuid.description),duplicateOf=\(duplicate.uuidString),keeping=latter)")
                    self.beacons[uuid] = nil
                }
                // CoreBluetooth will eventually give warning and disconnect actual duplicate silently.
                // While calling disconnect here is cleaner but it will trigger didDiscover and
                // retain the duplicates. Expect to see message :
                // [CoreBluetooth] API MISUSE: Forcing disconnection of unused peripheral
                // <CBPeripheral: XXX, identifier = XXX, name = iPhone, state = connected>.
                // Did you forget to cancel the connection?
            }
        }
        queue.async {
            // All peripherals -> Check pending actions
            self.beacons.values.forEach() { beacon in
                if beacon.operatingSystem == nil {
                    beacon.operatingSystem = .unknown
                }
                if let operatingSystem = beacon.operatingSystem {
                    switch operatingSystem {
                    case .ios:
                        // iOS peripherals (Connected) -> Wake transmitter
                        if beacon.peripheral.state == .connected {
                            if beacon.timeIntervalSinceLastUpdate < TimeInterval.minute {
                                // Throttle back keep awake calls when out of range
                                self.wakeTransmitter("scan|ios", beacon)
                            } else {
                                // Add pending connect when out of range
                                self.connect("scan|ios|pending|" + beacon.peripheral.state.description, beacon.peripheral)
                            }
                        }
                        // iOS peripherals (Not connected) -> Connect
                        else if beacon.peripheral.state != .connecting {
                            self.connect("scan|ios|" + beacon.peripheral.state.description, beacon.peripheral)
                        }
                        break
                    case .restored:
                        if beacon.peripheral.state != .connected && beacon.peripheral.state != .connecting {
                            self.connect("scan|restored|" + beacon.peripheral.state.description, beacon.peripheral)
                        }
                        break
                    case .unknown:
                        if beacon.peripheral.state != .connected && beacon.peripheral.state != .connecting {
                            self.connect("scan|unknown|" + beacon.peripheral.state.description, beacon.peripheral)
                        }
                        break
                    default:
                        break
                    }
                }
            }
        }
    }
    
    private func logBeaconState() {
        logger.debug("Beacon state report ========")
        beacons.keys.sorted{$0 < $1}.forEach() { uuid in
            if let beacon = beacons[uuid] {
                logger.debug("Beacon state (uuid=\(uuid),state=\(beacon.peripheral.state.description))")
            }
        }
        central.retrieveConnectedPeripherals(withServices: [BLESensorConfiguration.serviceUUID]).forEach() { peripheral in
            guard beacons[peripheral.identifier.uuidString] == nil else {
                return
            }
            logger.debug("Beacon state (uuid=\(peripheral.identifier.uuidString),state=.unknown)")
        }
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
    
    /**
     Connect peripheral. Scanning is stopped temporarily, as recommended by Apple documentation, before initiating connect, otherwise
     pending scan operations tend to take priority and connect takes longer to start. Scanning is scheduled to resume later, to ensure scan
     resumes, even if connect fails.
     */
    private func connect(_ source: String, _ peripheral: CBPeripheral) {
        let uuid = peripheral.identifier.uuidString
        logger.debug("connect (source=\(source),peripheral=\(uuid))")
        guard central.state == .poweredOn else {
            logger.fault("connect denied, central stopped (source=\(source),peripheral=\(uuid))")
            return
        }
        scheduleScan("connect")
        queue.async {
            self.central.retrievePeripherals(withIdentifiers: [peripheral.identifier]).forEach{ self.central.connect($0) }
        }
    }
    
    /**
     Disconnect peripheral. On didDisconnect, a connect request will be made for iOS devices to maintain an open connection;
     there is no further action for Android. On didFailedToConnect, a connect request will be made for both iOS and Android
     devices as the error is likely to be transient (as described in Apple documentation), except if the error is "Device in invalid"
     then the peripheral is unregistered by removing it from the beacons table.
     */
    private func disconnect(_ source: String, _ peripheral: CBPeripheral) {
        let uuid = peripheral.identifier.uuidString
        logger.debug("disconnect (source=\(source),peripheral=\(uuid))")
        queue.async { self.central.cancelPeripheralConnection(peripheral) }
    }
    
    /// Read RSSI
    private func readRSSI(_ source: String, _ peripheral: CBPeripheral) {
        let uuid = peripheral.identifier.uuidString
        guard peripheral.state == .connected else {
            return
        }
        logger.debug("readRSSI (source=\(source),peripheral=\(uuid))")
        peripheral.readRSSI()
    }
    
    /// Read beacon code
    private func readCode(_ source: String, _ peripheral: CBPeripheral) {
        let uuid = peripheral.identifier.uuidString
        guard peripheral.state == .connected else {
            return
        }
        logger.debug("readCode (source=\(source),peripheral=\(uuid))")
        peripheral.discoverServices([BLESensorConfiguration.serviceUUID])
    }
    
    /**
     Wake transmitter by writing blank data to the beacon characteristic. This will trigger the transmitter to generate a data value update notification
     in 8 seconds, which in turn will trigger this receiver to receive a didUpdateValueFor call to keep both the transmitter and receiver awake, while
     maximising the time interval between bluetooth calls to minimise power usage.
     */
    private func wakeTransmitter(_ source: String, _ beacon: Beacon) {
        guard let operatingSystem = beacon.operatingSystem, operatingSystem == .ios, let characteristic = beacon.signalCharacteristic else {
            return
        }
        logger.debug("wakeTransmitter (source=\(source),peripheral=\(beacon.uuidString))")
        beacon.peripheral.writeValue(emptyData, for: characteristic, type: .withResponse)
    }
    
    /// Notify receiver delegates of beacon detection
    private func notifyDelegates(_ source: String, _ beacon: Beacon) {
        guard beacon.isReady, let code = beacon.code, let rssi = beacon.rssi else {
            return
        }
        // Discard invalid RSSI values
        if rssi >= BLE_RSSI(0) {
            logger.debug("Discarded beacon, invalid RSSI value (source=\(source),peripheral=\(String(describing: beacon.uuidString)),code=\(String(describing: code)),rssi=\(String(describing: rssi)))")
            beacon.rssi = nil
            return
        }
        // Notify delegates for valid RSSI values
        beacon.statistics.add()
        for delegate in self.delegates {
            //delegate.(didDetect: code, rssi: rssi)
        }
        // Invalidate RSSI after notify
        beacon.rssi = nil
        logger.debug("Detected beacon (source=\(source),peripheral=\(String(describing: beacon.uuidString)),code=\(String(describing: code)),rssi=\(String(describing: rssi)),statistics={\(String(describing: beacon.statistics.description))})")
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        // Restore -> Populate beacons
        logger.debug("willRestoreState")
        self.central = central
        central.delegate = self
        if let restoredPeripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in restoredPeripherals {
                peripheral.delegate = self
                let uuid = peripheral.identifier.uuidString
                if let beacon = beacons[uuid] {
                    beacon.peripheral = peripheral
                    logger.debug("willRestoreState known (peripheral=\(uuid),state=\(peripheral.state.description))")
                } else {
                    beacons[uuid] = Beacon(peripheral: peripheral)
                    beacons[uuid]?.operatingSystem = .restored
                    logger.debug("willRestoreState unknown (peripheral=\(uuid),state=\(peripheral.state.description))")
                }
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
        // Discover -> Notify delegates | Wake transmitter | Connect -> Scan again
        let uuid = peripheral.identifier.uuidString
        let rssi = RSSI.intValue
        let txPower = (advertisementData[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
        logger.debug("didDiscover (peripheral=\(uuid),rssi=\(rssi),state=\(peripheral.state.description))")
        // Register beacon -> Set delegate -> Update RSSI
        peripheral.delegate = self
        if beacons[uuid] == nil {
            beacons[uuid] = Beacon(peripheral: peripheral)
        }
        guard let beacon = beacons[uuid] else {
            return
        }
        beacon.rssi = rssi
        // Beacon is ready -> Notify delegates -> Wake transmitter -> Scan again
        // Beacon is "ready" when it has all the required information (operatingSystem, code, rssi)
        // and the codeUpdatedAt date is today.
        if let operatingSystem = beacon.operatingSystem, beacon.isReady {
            // Android -> Notify delegates -> Scan again
            // Android peripheral is detected by iOS central for every call to scanForPeripherals, in both foreground and background modes.
            // Android BLE address changes over time, thus triggering expire, then connect and therefore no need to connect every time to
            // check for beacon code expiry, which also minimises connect calls to Android devices.
            if operatingSystem == .android {
                notifyDelegates("didDiscover|android", beacon)
                scheduleScan("didDiscover|android")
            }
            // iOS -> Notify delegates [-> Wake transmitter] -> Scan again
            // NB: Wake transmitter moved to scan|ios
            // iOS peripheral is kept awake by writing empty data to the beacon characteristic, which triggers a value update notification
            // after 8 seconds. The notification triggers the receiver's didUpdateValueFor callback, which wakes up the receiver to initiate
            // a readRSSI call. Please note, a beacon code update on the transmitter will trigger the receiver's didModifyService callback,
            // which wakes up the receiver to initiate a readCode (if already connected) or connect call.
            else if operatingSystem == .ios {
                notifyDelegates("didDiscover|ios", beacon)
                scheduleScan("didDiscover|ios")
            }
        }
        // Beacon is not ready | Beacon is new -> Connect
        else if !beacon.isReady || beacon.peripheral.state != .connected {
            connect("didDiscover", peripheral)
        }
        // Default -> Scan again
        scheduleScan("didDiscover")
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        // Connect -> Read Code | Read RSSI
        let uuid = peripheral.identifier.uuidString
        logger.debug("didConnect (peripheral=\(uuid))")
        guard let beacon = beacons[uuid] else {
            // This should never happen
            return
        }
        if !beacon.isReady {
            // Not ready -> Read Code (RSSI should already be available from didDiscover)
            readCode("didConnect", peripheral)
        } else {
            // Ready -> Read RSSI -> Read Code
            // This is the path after restore, didFailToConnect, disconnect[iOS], didModifyService where
            // the RSSI value may be available but need to be refreshed
            readRSSI("didConnect", peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        // Connect fail -> Unregister | Connect
        // Failure for peripherals advertising the beacon service should be transient, so try again.
        // This is also where iOS reports invalidated devices if connect is called after restore,
        // thus offers an opportunity for house keeping.
        let uuid = peripheral.identifier.uuidString
        logger.debug("didFailToConnect (peripheral=\(uuid),error=\(String(describing: error)))")
        if String(describing: error).contains("Device is invalid") {
            logger.debug("Unregister invalid device (peripheral=\(uuid))")
            beacons[uuid] = nil
        } else {
            connect("didFailToConnect", peripheral)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Disconnected -> Connect if iOS
        // Keep connection only for iOS, not necessary for Android as they are always detectable
        let uuid = peripheral.identifier.uuidString
        logger.debug("didDisconnectPeripheral (peripheral=\(uuid),error=\(String(describing: error)))")
        if let beacon = beacons[uuid], let operatingSystem = beacon.operatingSystem, operatingSystem == .ios {
            connect("didDisconnectPeripheral", peripheral)
        }
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        // Read RSSI -> Read Code | Notify delegates -> Scan again
        // This is the primary loop for iOS after initial connection and subscription to
        // the notifying beacon characteristic. The loop is scan -> wakeTransmitter ->
        // didUpdateValueFor -> readRSSI -> notifyDelegates -> scheduleScan -> scan
        let uuid = peripheral.identifier.uuidString
        let rssi = RSSI.intValue
        logger.debug("didReadRSSI (peripheral=\(uuid),rssi=\(rssi),error=\(String(describing: error)))")
        if let beacon = beacons[uuid] {
            beacon.rssi = rssi
            if !beacon.isReady {
                readCode("didReadRSSI", peripheral)
                return
            } else {
                notifyDelegates("didReadRSSI", beacon)
                if let operatingSystem = beacon.operatingSystem, operatingSystem == .android {
                    disconnect("didReadRSSI", peripheral)
                }
            }
        }
        // For initial connection, the scheduleScan call would have been made just before connect.
        // It is called again here to extend the time interval between scans.
        scheduleScan("didReadRSSI")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // Discover services -> Discover characteristics | Disconnect
        let uuid = peripheral.identifier.uuidString
        logger.debug("didDiscoverServices (peripheral=\(uuid),error=\(String(describing: error)))")
        guard let services = peripheral.services else {
            //beacons[uuid] = nil
            disconnect("didDiscoverServices|serviceEmpty", peripheral)
            return
        }
        for service in services {
//            os_log("didDiscoverServices, found service (peripheral=%s,service=%s)", log: log, type: .debug, uuid, service.uuid.description)
            if (service.uuid == BLESensorConfiguration.serviceUUID) {
                logger.debug("didDiscoverServices, found beacon service (peripheral=\(uuid))")
                peripheral.discoverCharacteristics(nil, for: service)
                return
            }
        }
        //beacons[uuid] = nil
        disconnect("didDiscoverServices|serviceNotFound", peripheral)
        // The disconnect calls here shall be handled by didDisconnect which determines whether to retry for iOS or stop for Android
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Discover characteristics -> Notify delegates -> Disconnect | Wake transmitter -> Scan again
        let uuid = peripheral.identifier.uuidString
        logger.debug("didDiscoverCharacteristicsFor (peripheral=\(uuid),error=\(String(describing: error)))")
        guard let beacon = beacons[uuid], let characteristics = service.characteristics else {
            disconnect("didDiscoverCharacteristicsFor|characteristicEmpty", peripheral)
            beacons[uuid] = nil
            return
        }
        for characteristic in characteristics {
//            os_log("didDiscoverCharacteristicsFor, found characteristic (peripheral=%s,characteristic=%s)", log: log, type: .debug, uuid, characteristic.uuid.description)
            if characteristic.uuid == BLESensorConfiguration.signalCharacteristicUUID {
                let notifies = characteristic.properties.contains(.notify)
                // Characteristic notifies -> Operating system is iOS, else Android
                beacon.operatingSystem = (notifies ? .ios : .android)
                logger.debug("didDiscoverCharacteristicsFor, found signal characteristic (peripheral=\(uuid),notifies=\(notifies),os=\(beacon.operatingSystem!))")
                // Characteristic notifies -> Subscribe
                if notifies {
                    beacon.signalCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }
                notifyDelegates("didDiscoverCharacteristicsFor", beacon)
            }
        }
        // Android -> Disconnect
        if let operatingSystem = beacon.operatingSystem, operatingSystem == .android {
            disconnect("didDiscoverCharacteristicsFor", peripheral)
        }
        // Always -> Scan again
        // For initial connection, the scheduleScan call would have been made just before connect.
        // It is called again here to extend the time interval between scans.
        scheduleScan("didDiscoverCharacteristicsFor")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // Wrote characteristic -> Scan again
        let uuid = peripheral.identifier.uuidString
        logger.debug("didWriteValueFor (peripheral=\(uuid),error=\(String(describing: error)))")
        // For all situations, scheduleScan would have been made earlier in the chain of async calls.
        // It is called again here to extend the time interval between scans, as this is usually the
        // last call made in all paths to wake the transmitter.
        scheduleScan("didWriteValueFor")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        // iOS only
        // Modified service -> Invalidate beacon -> Read Code | Connect
        let uuid = peripheral.identifier.uuidString
        let characteristics = invalidatedServices.map{$0.characteristics}.count
        guard characteristics == 0 else {
            // Value of characteristic > 0 implies invalidation of service with existing beacon code, wait
            // for characteristic == 0 to read code, as that implies a new service with a new beacon code
            // will be ready for read. Otherwise, this will result in two readCode requests for every beacon
            // code update.
            return
        }
        logger.debug("didModifyServices (peripheral=\(uuid))")
        if let beacon = beacons[uuid] {
            beacon.code = nil
            if peripheral.state == .connected {
                readCode("didModifyServices", peripheral)
            } else if peripheral.state != .connecting {
                connect("didModifyServices", peripheral)
            }
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
        let uuid = peripheral.identifier.uuidString
        logger.debug("didUpdateValueFor (peripheral=\(uuid),error=\(String(describing: error)))")
        readRSSI("didUpdateValueFor", peripheral)
    }
}
