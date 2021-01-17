//
//  MobilitySensor.swift
//
//  Copyright 2021 VMware, Inc.
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
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "ConcreteMobilitySensor")
    private var delegates: [SensorDelegate] = []
    private let locationManager = CLLocationManager()
    private let rangeForBeacon: UUID?

    init(resolution: Distance = CLLocationDistanceMax, rangeForBeacon: UUID? = nil) {
        let accuracy = ConcreteMobilitySensor.locationAccuracy(resolution)
        logger.debug("init(resolution=\(resolution),accuracy=\(accuracy.description),rangeForBeacon=\(rangeForBeacon == nil ? "disabled" : rangeForBeacon!.description))")
        self.rangeForBeacon = rangeForBeacon
        super.init()
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = accuracy
        locationManager.distanceFilter = resolution
        locationManager.allowsBackgroundLocationUpdates = true
        if #available(iOS 11.0, *) {
            logger.debug("init(ios>=11.0)")
            locationManager.showsBackgroundLocationIndicator = false
        } else {
            logger.debug("init(ios<11.0)")
        }
    }
    
    /// Establish location accuracy required based on distance resolution required
    private static func locationAccuracy(_ resolution: Distance) -> CLLocationAccuracy {
        if resolution < 10 {
            return kCLLocationAccuracyBest
        }
        if resolution < 100 {
            return kCLLocationAccuracyNearestTenMeters
        }
        if resolution < 1000 {
            return kCLLocationAccuracyHundredMeters
        }
        if resolution < 3000 {
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
        
        if status == CLAuthorizationStatus.authorizedWhenInUse ||
            status == CLAuthorizationStatus.authorizedAlways {
            state = .on
        }
        if status == CLAuthorizationStatus.notDetermined {
            locationManager.requestAlwaysAuthorization()
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
        if manager.authorizationStatus == CLAuthorizationStatus.authorizedWhenInUse ||
            manager.authorizationStatus == CLAuthorizationStatus.authorizedAlways {
            state = .on
        }
        if manager.authorizationStatus == CLAuthorizationStatus.notDetermined {
            locationManager.requestAlwaysAuthorization()
            locationManager.stopUpdatingLocation()
            locationManager.startUpdatingLocation()
        }
        if manager.authorizationStatus != CLAuthorizationStatus.notDetermined {
            delegates.forEach({ $0.sensor(.MOBILITY, didUpdateState: state) })
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard locations.count > 0 else {
            return
        }
        logger.debug("locationManager:didUpdateLocations(count=\(locations.count))")
        // Note, the actual location, direction of travel, or distance travelled is not being
        // used for mobility detection, just the fact that movement has occurred.
        let timestamp = Date()
        let mobilityLocationReference = MobilityLocationReference(distance: locationManager.distanceFilter)
        let location = Location(value: mobilityLocationReference, time: (start: timestamp, end: timestamp))
        delegates.forEach { $0.sensor(.MOBILITY, didVisit: location) }
          // Commented out as we don't use or need the actual location of a device in Herald for mobility events
//        locations.forEach() { location in
//            let location = Location(
//                value: WGS84PointLocationReference(
//                    latitude: location.coordinate.latitude,
//                    longitude: location.coordinate.longitude,
//                    altitude: location.altitude),
//                time: (start: location.timestamp, end: location.timestamp))
//            delegates.forEach { $0.sensor(.GPS, didVisit: location) }
//        }
    }
}

extension CLLocationAccuracy {
    var description: String { get {
        if self == kCLLocationAccuracyBest {
            return "best"
        }
        if self == kCLLocationAccuracyNearestTenMeters {
            return "10m"
        }
        if self == kCLLocationAccuracyHundredMeters {
            return "100m"
        }
        if self == kCLLocationAccuracyKilometer {
            return "1km"
        }
        if self == kCLLocationAccuracyThreeKilometers {
            return "3km"
        }
        return "unknown"
    }}
}
