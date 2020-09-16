//
//  Sensor.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation
import UIKit

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
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier)
    
    /// Detection of time spent at location, e.g. at specific restaurant between 02/06/2020 19:00 and 02/06/2020 21:00
    func sensor(_ sensor: SensorType, didVisit: Location)
    
    /// Measure proximity to target with payload data. Combines didMeasure and didRead into a single convenient delegate method
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData)
    
    /// Sensor state update
    func sensor(_ sensor: SensorType, didUpdateState: SensorState)
}

/// Sensor delegate functions are all optional.
extension SensorDelegate {
    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {}
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {}
    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {}
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {}
    func sensor(_ sensor: SensorType, didVisit: Location) {}
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData) {}
    func sensor(_ sensor: SensorType, didUpdateState: SensorState) {}
}

// MARK:- SensorArray

/// Sensor array for combining multiple detection and tracking methods.
class SensorArray : NSObject, Sensor {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "SensorArray")
    private var sensorArray: [Sensor] = []
    public let payloadData: PayloadData
    public static let deviceDescription = "\(UIDevice.current.name) (iOS \(UIDevice.current.systemVersion))"

    init(_ payloadDataSupplier: PayloadDataSupplier) {
        logger.debug("init")
        // Location sensor is necessary for enabling background BLE advert detection
        sensorArray.append(ConcreteGPSSensor(rangeForBeacon: UUID(uuidString:  BLESensorConfiguration.serviceUUID.uuidString)))
        // BLE sensor for detecting and tracking proximity
        sensorArray.append(ConcreteBLESensor(payloadDataSupplier))
        // Payload data at initiation time for identifying this device in the logs
        payloadData = payloadDataSupplier.payload(PayloadTimestamp())
        super.init()
        
        // Loggers
        add(delegate: ContactLog(filename: "contacts.csv"))
        add(delegate: StatisticsLog(filename: "statistics.csv", payloadData: payloadData))
        add(delegate: DetectionLog(filename: "detection.csv", payloadData: payloadData))
        _ = BatteryLog(filename: "battery.csv")
        logger.info("DEVICE (payloadPrefix=\(payloadData.shortName),description=\(SensorArray.deviceDescription))")
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

/// Sensor state
enum SensorState : String {
    /// Sensor is powered on, active and operational
    case on
    /// Sensor is powered off, inactive and not operational
    case off
    /// Sensor is not available
    case unavailable
}

/// Ephemeral identifier for detected target (e.g. smartphone, beacon, place). This is likely to be an UUID but using String for variable identifier length.
typealias TargetIdentifier = String

// MARK:- Proximity data

/// Raw data for estimating proximity between sensor and target, e.g. RSSI for BLE.
struct Proximity {
    /// Unit of measurement, e.g. RSSI
    let unit: ProximityMeasurementUnit
    /// Measured value, e.g. raw RSSI value.
    let value: Double
    /// Get plain text description of proximity data
    var description: String { get {
        unit.rawValue + ":" + value.description
    }}
}

/// Measurement unit for interpreting the proximity data values.
enum ProximityMeasurementUnit : String {
    /// Received signal strength indicator, e.g. BLE signal strength as proximity estimator.
    case RSSI
    /// Roundtrip time, e.g. Audio signal echo time duration as proximity estimator.
    case RTT
}

// MARK:- Location data

/// Raw location data for estimating indirect exposure, e.g.
struct Location {
    /// Measurement values, e.g. GPS coordinates in comma separated string format for latitude and longitude
    let value: LocationReference
    /// Time spent at location.
    let time: (start: Date, end: Date)
    /// Get plain text description of proximity data
    var description: String { get {
        value.description + ":[from=" + time.start.description + ",to=" + time.end.description + "]"
    }}
}

protocol LocationReference {
    var description: String { get }
}

/// GPS coordinates (latitude,longitude,altitude) in WGS84 decimal format and meters from sea level.
struct WGS84PointLocationReference : LocationReference {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    var description: String { get {
        "WGS84(lat=\(latitude),lon=\(longitude),alt=\(altitude))"
        }}
}

/// GPS coordinates and region radius, e.g. latitude and longitude in decimal format and radius in meters.
struct WGS84CircularAreaLocationReference : LocationReference {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let radius: Double
    var description: String { get {
        "WGS84(lat=\(latitude),lon=\(longitude),alt=\(altitude),radius=\(radius))"
        }}
}

/// Free text place name.
struct PlacenameLocationReference : LocationReference {
    let name: String
    var description: String { get {
        "PLACE(name=\(name))"
        }}
}