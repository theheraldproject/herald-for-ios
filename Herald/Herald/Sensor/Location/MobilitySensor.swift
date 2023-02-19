//
//  MobilitySensor.swift
//
//  Copyright 2021-2023 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import CoreLocation

protocol MobilitySensor : Sensor {
}

/**
 Mobility sensor based on CoreLocation to assess range of travel as indicator for assisting prioritisation
 in contact tracing work. Does NOT make use of the GPS position.
 Requires : Signing & Capabilities : BackgroundModes : LocationUpdates = YES
 Requires : Info.plist : Privacy - Location When In Use Usage Description
 Requires : Info.plist : Privacy - Location Always and When In Use Usage Description
 */
class ConcreteMobilitySensor : NSObject, MobilitySensor, CLLocationManagerDelegate {
    /// Minimum mobility sensing resolution is 3km as defined by CoreLocation.
    public static let minimumResolution: Distance = Distance(kCLLocationAccuracyThreeKilometers)

    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "ConcreteMobilitySensor")
    private var delegates: [SensorDelegate] = []
    private let locationManager = CLLocationManager()
    private let rangeForBeacon: UUID?
    /// Mobility sensing is only concerned with distance travelled, not actual location.
    /// Last location is only being used here to enable calculation of cummulative distance travelled.
    private let resolution: Distance
    private var lastLocation: CLLocation?
    private var lastUpdate: Date?
    private var cummulativeDistance: Distance = Distance(0)

    init(resolution: Distance = minimumResolution, rangeForBeacon: UUID? = nil) {
        self.resolution = resolution
        self.rangeForBeacon = rangeForBeacon
        super.init()
        let accuracy = ConcreteMobilitySensor.locationAccuracy(resolution)
        logger.debug("init(resolution=\(resolution),accuracy=\(accuracy),rangeForBeacon=\(rangeForBeacon == nil ? "disabled" : rangeForBeacon!.description))")
        locationManager.delegate = self
        if #available(iOS 13.4, *) {
            self.locationManager.requestWhenInUseAuthorization()
        } else {
            self.locationManager.requestAlwaysAuthorization()
        }
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = accuracy
        locationManager.distanceFilter = resolution.value
        locationManager.allowsBackgroundLocationUpdates = true
        if #available(iOS 11.0, *) {
            logger.debug("init(ios>=11.0)")
            locationManager.showsBackgroundLocationIndicator = false
        } else {
            logger.debug("init(ios<11.0)")
        }
    }
    
    public func coordinationProvider() -> CoordinationProvider? {
        // Class does not have a coordination provider
        return nil
    }
    
    /// Establish location accuracy required based on distance resolution required
    private static func locationAccuracy(_ resolution: Distance) -> CLLocationAccuracy {
        if resolution.value < 10 {
            return kCLLocationAccuracyBest
        }
        if resolution.value < 100 {
            return kCLLocationAccuracyNearestTenMeters
        }
        if resolution.value < 1000 {
            return kCLLocationAccuracyHundredMeters
        }
        if resolution.value < 3000 {
            return kCLLocationAccuracyKilometer
        }
        return kCLLocationAccuracyThreeKilometers
    }
    
    func add(delegate: SensorDelegate) {
        delegates.append(delegate)
    }
    
    func start() {
        logger.debug("start")
        locationManager.startUpdatingLocation()
        logger.debug("startUpdatingLocation")

        // Start beacon ranging
        guard let beaconUUID = rangeForBeacon else {
            return
        }
        if #available(iOS 13.0, *) {
            locationManager.startRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: beaconUUID))
            logger.debug("startRangingBeacons(ios>=13.0,beaconUUID=\(beaconUUID.description))")
        } else {
            let beaconRegion = CLBeaconRegion(proximityUUID: beaconUUID, identifier: beaconUUID.uuidString)
            locationManager.startRangingBeacons(in: beaconRegion)
            logger.debug("startRangingBeacons(ios<13.0,beaconUUID=\(beaconUUID.uuidString)))")
        }
    }
    
    func stop() {
        logger.debug("stop")
        locationManager.stopUpdatingLocation()
        logger.debug("stopUpdatingLocation")
        // Start beacon ranging
        guard let beaconUUID = rangeForBeacon else {
            return
        }
        if #available(iOS 13.0, *) {
            locationManager.stopRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: beaconUUID))
            logger.debug("stopRangingBeacons(ios>=13.0,beaconUUID=\(beaconUUID.description))")
        } else {
            let beaconRegion = CLBeaconRegion(proximityUUID: beaconUUID, identifier: beaconUUID.uuidString)
            locationManager.stopRangingBeacons(in: beaconRegion)
            logger.debug("stopRangingBeacons(ios<13.0,beaconUUID=\(beaconUUID.description))")
        }
    }
    
    // MARK:- CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        var state = SensorState.off
        
        if status == CLAuthorizationStatus.authorizedWhenInUse {
            self.locationManager.requestAlwaysAuthorization()
            state = .on
        }
        
        if status == CLAuthorizationStatus.authorizedAlways {
            state = .on
        }
        if status == CLAuthorizationStatus.notDetermined {
            if #available(iOS 13.4, *) {
                self.locationManager.requestWhenInUseAuthorization()
            } else {
                self.locationManager.requestAlwaysAuthorization()
            }
            locationManager.stopUpdatingLocation()
            locationManager.startUpdatingLocation()
        }
        if status != CLAuthorizationStatus.notDetermined {
            delegates.forEach({ $0.sensor(.MOBILITY, didUpdateState: state) })
        }
    }

    @available(iOS 14.0, *)
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        var state = SensorState.off
        if manager.authorizationStatus == CLAuthorizationStatus.authorizedWhenInUse {
            self.locationManager.requestAlwaysAuthorization()
            state = .on
        }
        
        if manager.authorizationStatus == CLAuthorizationStatus.authorizedAlways {
            state = .on
        }
        if manager.authorizationStatus == CLAuthorizationStatus.notDetermined {
            locationManager.requestWhenInUseAuthorization()
            locationManager.stopUpdatingLocation()
            locationManager.startUpdatingLocation()
        }
        if manager.authorizationStatus != CLAuthorizationStatus.notDetermined {
            delegates.forEach({ $0.sensor(.MOBILITY, didUpdateState: state) })
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Only process location data if mobility sensor has been enabled
        guard let resolution = BLESensorConfiguration.mobilitySensorEnabled else {
            return
        }
        guard locations.count > 0 else {
            return
        }
        // Accumulate distance travelled and report at required resolution
        // Note, the actual location and direction of travel is not being
        // reported in mobility detection, just the cummulative distance
        // travelled in resolution units.
        locations.forEach() { location in
            guard let lastLocation = lastLocation, let lastUpdate = lastUpdate else {
                self.lastLocation = location
                self.lastUpdate = location.timestamp
                return
            }
            // Accumulate distance travelled as indicator of mobility.
            // Note, distance travelled is calculated as a straight
            // line along Earth's curvature, and the distance calculation
            // does not take into account the accuracy of the location
            // data. This is a deliberate design decision to decouple
            // mobility data from actual location data.
            let distance = location.distance(from: lastLocation)
            cummulativeDistance.value += distance
            logger.debug("didUpdateLocations(distance=\(distance))")
            // Mobility data is only reported in unit lengths to further
            // decouple mobility data from actual location data.
            if cummulativeDistance.value >= resolution.value {
                let didVisit = Location(value: MobilityLocationReference(distance: cummulativeDistance), time: (start: lastUpdate, end: location.timestamp))
                delegates.forEach { $0.sensor(.MOBILITY, didVisit: didVisit) }
                cummulativeDistance = Distance(0)
                self.lastUpdate = location.timestamp
            }
            self.lastLocation = location
        }
    }
}
//
//extension CLLocationAccuracy {
//    var description: String { get {
//        if self == kCLLocationAccuracyBest {
//            return "best"
//        }
//        if self == kCLLocationAccuracyNearestTenMeters {
//            return "10m"
//        }
//        if self == kCLLocationAccuracyHundredMeters {
//            return "100m"
//        }
//        if self == kCLLocationAccuracyKilometer {
//            return "1km"
//        }
//        if self == kCLLocationAccuracyThreeKilometers {
//            return "3km"
//        }
//        return "unknown"
//    }}
//}
