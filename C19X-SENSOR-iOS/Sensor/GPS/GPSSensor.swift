//
//  GPSSensor.swift
//  C19X-SENSOR-iOS
//
//  Created by Freddy Choi on 24/07/2020.
//  Copyright © 2020 C19X. All rights reserved.
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

    init(desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyThreeKilometers, distanceFilter: CLLocationDistance = CLLocationDistanceMax) {
        logger.debug("init(desiredAccuracy=\(desiredAccuracy == kCLLocationAccuracyThreeKilometers ? "3km" : desiredAccuracy.description),distanceFilter=\(distanceFilter == CLLocationDistanceMax ? "max" : distanceFilter.description))")
        super.init()
        locationManager.delegate = self
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
    }
    
    func stop() {
        logger.debug("stop")
        locationManager.stopUpdatingLocation()
    }
    
    // MARK:- CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        logger.debug("locationManager:didUpdateLocations(locations=\(locations.description))")
        guard locations.count > 0 else {
            return
        }
        let timestamps = locations.map { $0.timestamp }.sorted()
        guard let start = timestamps.first, let end = timestamps.last else {
            return
        }
        let values = locations.map { $0.coordinate.latitude.description + "," + $0.coordinate.longitude.description + "," + $0.altitude.description }
        let locationData = LocationData(unit: .WGS84_POINT, values: values, time: (start: start, end: end))
        delegates.forEach { $0.sensor(.GPS, didVisit: locationData) }
    }
}
