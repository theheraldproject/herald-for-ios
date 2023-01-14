//
//  SensorDelegate.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Sensor delegate for receiving sensor events.
public protocol SensorDelegate {
    /// Detection of a target with an ephemeral identifier, e.g. BLE central detecting a BLE peripheral.
    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier)
    
    /// Indicates whether a device has dropped out of being accessible (E.g. removed from BLEDatabase)
    func sensor(_ sensor: SensorType, available: Bool, didDeleteOrDetect: TargetIdentifier)
    
    /// Read payload data from target, e.g. encrypted device identifier from BLE peripheral after successful connection.
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier)
    
    /// Read payload data of other targets recently acquired by a target, e.g. Android peripheral sharing payload data acquired from nearby iOS peripherals.
    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier)
    
    /// Write signal requests - immediate send
    func sensor(_ sensor: SensorType, didReceive: Data, fromTarget: TargetIdentifier)

    /// Measure proximity to target, e.g. a sample of RSSI values from BLE peripheral.
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier)
    
    /// Detection of time spent at location, e.g. at specific restaurant between 02/06/2020 19:00 and 02/06/2020 21:00
    func sensor(_ sensor: SensorType, didVisit: Location?)
    
    /// Measure proximity to target with payload data. Combines didMeasure and didRead into a single convenient delegate method
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData)
    
    /// Sensor state update
    func sensor(_ sensor: SensorType, didUpdateState: SensorState)
}

/// Sensor delegate functions are all optional.
public extension SensorDelegate {
    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {}
    func sensor(_ sensor: SensorType, available: Bool, didDeleteOrDetect: TargetIdentifier) {}
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {}
    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {}
    func sensor(_ sensor: SensorType, didReceive: Data, fromTarget: TargetIdentifier) {}
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {}
    func sensor(_ sensor: SensorType, didVisit: Location?) {}
    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData) {}
    func sensor(_ sensor: SensorType, didUpdateState: SensorState) {}
}

// MARK:- SensorDelegate data

/// Sensor type as qualifier for target identifier.
public enum SensorType : String {
    /// Bluetooth Low Energy (BLE)
    case BLE
    /// Bluetooth Mesh (5.0+)
    case BLMESH
    /// Mobility sensor - uses Location API measure range travelled
    case MOBILITY
    /// GPS location sensor - not used by default in Herald
    case GPS
    /// Physical beacon, e.g. iBeacon
    case BEACON
    /// Ultrasound audio beacon.
    case ULTRASOUND
    /// Accelerometer motion sensor
    case ACCELEROMETER
    /// Other - Incase of an extension between minor versions of Herald
    case OTHER
    /// Sensor array consisting of multiple sensors
    case ARRAY
}

/// Sensor state
public enum SensorState : String {
    /// Sensor is powered on, active and operational
    case on
    /// Sensor is powered off, inactive and not operational
    case off
    /// Sensor is not available
    case unavailable
}

/// Ephemeral identifier for detected target (e.g. smartphone, beacon, place). This is likely to be an UUID but using String for variable identifier length.
public typealias TargetIdentifier = String

// MARK:- Proximity data

/// Raw data for estimating proximity between sensor and target, e.g. RSSI for BLE.
public struct Proximity {
    /// Unit of measurement, e.g. RSSI
    public let unit: ProximityMeasurementUnit
    /// Measured value, e.g. raw RSSI value.
    public let value: Double
    /// Calibration data (optional), e.g. transmit power
    public let calibration: Calibration?
    /// Get plain text description of proximity data
    public var description: String { get {
        guard let calibration = calibration else {
            return "\(unit.rawValue):\(value.description)"
        }
        return "\(unit.rawValue):\(value.description)[\(calibration.description)]"
    }}
    
    public init(unit: ProximityMeasurementUnit, value: Double, calibration: Calibration? = nil) {
        self.unit = unit
        self.value = value
        self.calibration = calibration
    }
}

/// Measurement unit for interpreting the proximity data values.
public enum ProximityMeasurementUnit : String {
    /// Received signal strength indicator, e.g. BLE signal strength as proximity estimator.
    case RSSI
    /// Roundtrip time, e.g. Audio signal echo time duration as proximity estimator.
    case RTT
}

/// Calibration data for interpreting proximity value between sensor and target, e.g. Transmit power for BLE.
public struct Calibration {
    /// Unit of measurement, e.g. transmit power
    public let unit: CalibrationMeasurementUnit
    /// Measured value, e.g. transmit power in BLE advert
    public let value: Double
    /// Get plain text description of calibration data
    public var description: String { get {
        unit.rawValue + ":" + value.description
    }}
}

/// Measurement unit for calibrating the proximity transmission data values, e.g. BLE transmit power
public enum CalibrationMeasurementUnit : String {
    /// Bluetooth transmit power for describing expected RSSI at 1 metre for interpretation of measured RSSI value.
    case BLETransmitPower
}

// MARK:- Location data

/// Raw location data for estimating indirect exposure, e.g.
public struct Location {
    /// Measurement values, e.g. GPS coordinates in comma separated string format for latitude and longitude
    let value: LocationReference
    /// Time spent at location.
    let time: (start: Date, end: Date)
    /// Get plain text description of proximity data
    public var description: String { get {
        value.description + ":[from=" + time.start.description + ",to=" + time.end.description + "]"
    }}
}

public protocol LocationReference {
    var description: String { get }
}

/// GPS coordinates (latitude,longitude,altitude) in WGS84 decimal format and meters from sea level.
public struct WGS84PointLocationReference : LocationReference {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    public var description: String { get {
        "WGS84(lat=\(latitude),lon=\(longitude),alt=\(altitude))"
        }}
}

/// GPS coordinates and region radius, e.g. latitude and longitude in decimal format and radius in meters.
public struct WGS84CircularAreaLocationReference : LocationReference {
    let latitude: Double
    let longitude: Double
    let altitude: Double
    let radius: Double
    public var description: String { get {
        "WGS84(lat=\(latitude),lon=\(longitude),alt=\(altitude),radius=\(radius))"
        }}
}

/// Free text place name.
public struct PlacenameLocationReference : LocationReference {
    let name: String
    public var description: String { get {
        "PLACE(name=\(name))"
        }}
}

/// Distance travelled in any direction in metres, as indicator of range of movement.
public struct MobilityLocationReference : LocationReference {
    let distance: Distance
    public var description: String { get {
        "Mobility(distance=\(distance))"
        }}
}

/// Acceleration (x,y,z) in meters per second at point in time
public struct InertiaLocationReference : LocationReference {
    let x: Double
    let y: Double
    let z: Double
    var magnitude: Double { get {
        sqrt(x * x + y * y + z * z)
    }}
    public var description: String { get {
        "Inertia(magnitude=\(magnitude),x=\(x),y=\(y),z=\(z))"
        }}
}
