//
//  Sensor.swift
//  
//
//  Created  on 24/07/2020.
//  Copyright © 2020 . All rights reserved.
//

import Foundation

/// Sensor for detecting and tracking various kinds of disease transmission vectors, e.g. contact with people, time at location.
protocol Sensor {
    /// Add delegate for responding to sensor events.
    func add(delegate: SensorDelegate)
    
    /// Start sensing.
    func start()
    
    /// Stop sensing.
    func stop()
}

/// Sensor delegate for receiving sensor events.
protocol SensorDelegate {
    /// Detection of a target with an ephemeral identifier, e.g. BLE central detecting a BLE peripheral.
    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier)
    
    /// Read payload data from target, e.g. encrypted device identifier from BLE peripheral after successful connection.
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier)
    
    /// Read payload data of other targets recently acquired by a target, e.g. Android peripheral sharing payload data acquired from nearby iOS peripherals.
    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier)

    /// Measure proximity to target, e.g. a sample of RSSI values from BLE peripheral.
    func sensor(_ sensor: SensorType, didMeasureProximity: ProximityData, fromTarget: TargetIdentifier)
    
    /// Detection of time spent at location, e.g. at specific restaurant between 02/06/2020 19:00 and 02/06/2020 21:00
    func sensor(_ sensor: SensorType, didVisit: LocationData)
}

/// Sensor array for combining multiple detection and tracking methods.
class SensorArray : NSObject, Sensor {
    private let logger = ConcreteLogger(subsystem: "Sensor", category: "SensorArray")
    private var sensorArray: [Sensor] = []
    
    override init() {
        logger.debug("init")
//        sensorArray.append(ConcreteGPSSensor(desiredAccuracy: 1, distanceFilter: 1, rangeForBeacon: UUID(uuidString: "0022D481-83FE-1F13-0000-000000000000")))
        sensorArray.append(ConcreteBLESensor())
    }
    
    func add(delegate: SensorDelegate) {
        sensorArray.forEach { $0.add(delegate: delegate) }
    }
    
    func start() {
        logger.debug("start")
        sensorArray.forEach { $0.start() }
    }
    
    func stop() {
        logger.debug("stop")
        sensorArray.forEach { $0.stop() }
    }
}

// MARK:- SensorDelegate data

/// Sensor type as qualifier for target identifier.
enum SensorType : String {
    /// Bluetooth Low Energy (BLE)
    case BLE
    /// GPS location sensor
    case GPS
    /// Physical beacon, e.g. iBeacon
    case BEACON
    /// Ultrasound audio beacon.
    case ULTRASOUND
}

/// Ephemeral identifier for detected target (e.g. smartphone, beacon, place). This is likely to be an UUID but using String for variable identifier length.
typealias TargetIdentifier = String

/// Encrypted payload data received from target. This is likely to be an encrypted datagram of the target's actual permanent identifier.
typealias PayloadData = Data
extension PayloadData {
    var description: String {
        self.base64EncodedString()
    }
}

/// Payload data supplier, e.g. BeaconCodes in  and BroadcastPayloadSupplier in Sonar.
protocol PayloadDataSupplier {
    /// Get payload for given timestamp. Use this for integration with any payload generator, e.g. BeaconCodes or SonarBroadcastPayloadService
    func payload(_ timestamp: PayloadTimestamp) -> PayloadData
}

/// Payload timestamp, should normally be Date, but it may change to UInt64 in the future to use server synchronised relative timestamp.
typealias PayloadTimestamp = Date

/// Raw data for estimating proximity between sensor and target, e.g. sample of RSSI for BLE.
struct ProximityData {
    /// Unit of measurement, e.g. RSSI
    let unit: MeasurementUnit
    /// Measurement values, e.g. raw RSSI values.
    let values: [Double]
    /// Get plain text description of proximity data
    var description: String { get {
        unit.rawValue + ":" + values.description
    }}
}

/// Measurement unit for interpreting the proximity data values.
enum MeasurementUnit : String {
    /// Received signal strength indicator, e.g. BLE signal strength as proximity estimator.
    case RSSI
    /// Roundtrip time, e.g. Audio signal echo time duration as proximity estimator.
    case RTT
    /// GPS coordinates (latitude,longitude,altitude) in WGS84 decimal format and meters from sea level.
    case WGS84_POINT
    /// GPS coordinates and region radius, e.g. latitude and longitude in decimal format and radius in meters.
    case WGS84_AREA
    /// Free text place name.
    case PLACENAME
}

/// Raw location data for estimating
struct LocationData {
    /// Unit of measurement, e.g. WGS84_DECIMAL
    let unit: MeasurementUnit
    /// Measurement values, e.g. GPS coordinates in comma separated string format for latitude and longitude
    let values: [String]
    /// Time spent at location.
    let time: (start: Date, end: Date)
    /// Get plain text description of proximity data
    var description: String { get {
        unit.rawValue + "[from=" + time.start.description + ",to=" + time.end.description + "]:" + values.description
    }}
}

