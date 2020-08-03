//
//  GPSSensor.swift
//  
//
//  Created  on 24/07/2020.
//  Copyright © 2020 . All rights reserved.
//

import Foundation
import CoreLocation

protocol GPSSensor : Sensor {
}

/**
 GPS and location sensor based on CoreLocation.
 Requires : Signing & Capabilities : BackgroundModes : LocationUpdates = YES
 Requires : Info.plist : Privacy - Location When In Use Usage Description
 Requires : Info.plist : Privacy - Location Always and When In Use Usage Description
 */
class ConcreteGPSSensor : NSObject, GPSSensor, CLLocationManagerDelegate {
    private let logger = ConcreteLogger(subsystem: "Sensor", category: "ConcreteGPSSensor")
    private var delegates: [SensorDelegate] = []
    private let locationManager = CLLocationManager()
    private let rangeForBeacon: UUID?

    init(desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyThreeKilometers, distanceFilter: CLLocationDistance = CLLocationDistanceMax, rangeForBeacon: UUID? = nil) {
        logger.debug("init(desiredAccuracy=\(desiredAccuracy == kCLLocationAccuracyThreeKilometers ? "3km" : desiredAccuracy.description),distanceFilter=\(distanceFilter == CLLocationDistanceMax ? "max" : distanceFilter.description),rangeForBeacon=\(rangeForBeacon == nil ? "disabled" : rangeForBeacon!.description))")
        self.rangeForBeacon = rangeForBeacon
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestAlwaysAuthorization()
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.desiredAccuracy = desiredAccuracy
        locationManager.distanceFilter = distanceFilter
        locationManager.allowsBackgroundLocationUpdates = true
        if #available(iOS 11.0, *) {
            logger.debug("init(ios>=11.0)")
            locationManager.showsBackgroundLocationIndicator = false
        } else {
            logger.debug("init(ios<11.0)")
        }
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
    
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//        logger.debug("locationManager:didUpdateLocations(locations=\(locations.description))")
//        guard locations.count > 0 else {
//            return
//        }
//        locations.forEach() { location in
//            let location = Location(
//                value: WGS84PointLocationReference(
//                    latitude: location.coordinate.latitude,
//                    longitude: location.coordinate.longitude,
//                    altitude: location.altitude),
//                time: (start: location.timestamp, end: location.timestamp))
//            delegates.forEach { $0.sensor(.GPS, didVisit: location) }
//        }
//    }
}
