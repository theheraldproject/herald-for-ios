////
//  InertiaSensor.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: MIT
//

import Foundation
import CoreMotion

/**
 Inertia sensor for collecting movement data from accelerometer.
 */
protocol InertiaSensor : Sensor {
}

/**
 Inertia sensor based on CoreMotion
 Requires : Info.plist : Required Device Capabilities : Accelerometer
*/
class ConcreteInertiaSensor : NSObject, InertiaSensor {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Motion.ConcreteInertiaSensor")
    private let operationQueue = OperationQueue()
    private let delegateQueue = DispatchQueue(label: "Sensor.Motion.ConcreteInertiaSensor.DelegateQueue")
    private var delegates: [SensorDelegate] = []
    private let updateInterval: TimeInterval
    private let motionManager = CMMotionManager()

    /// Create inertia sensor with given update interval
    init(updateInterval: TimeInterval = TimeInterval(0.25)) {
        self.updateInterval = updateInterval
        super.init()
    }

    func add(delegate: SensorDelegate) {
        delegates.append(delegate)
    }
    
    func start() {
        guard motionManager.isAccelerometerAvailable else {
            logger.fault("start, accelerometer is not available")
            return
        }
        logger.debug("start")
        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.stopAccelerometerUpdates()
        motionManager.startAccelerometerUpdates(to: operationQueue, withHandler: handleAccelerometerUpdates)
    }
    
    func stop() {
        logger.debug("stop")
        motionManager.stopAccelerometerUpdates()
    }

    private func handleAccelerometerUpdates(data: CMAccelerometerData?, error: Error?) {
        guard error == nil else {
            return
        }
        guard let data = data else {
            return
        }
        let timestamp = Date()
        // The values reported by the accelerometers are measured in increments
        // of the gravitational acceleration, with the value 1.0 representing an
        // acceleration of 9.8 meters per second (per second) in the given direction.
        // The actual values for each axis is opposite on Android and iOS, i.e.
        // positive value on iOS = negative value on Android. The callback shall
        // standardise on Android notation, where y = 9.8 means the phone is being
        // held vertically with the top edge towards the sky.
        let x = -data.acceleration.x * 9.8
        let y = -data.acceleration.y * 9.8
        let z = -data.acceleration.z * 9.8
        let inertiaLocationReference = InertiaLocationReference(x: x, y: y, z: z)
        let location = Location(value: inertiaLocationReference, time: (start: timestamp, end: timestamp))
        self.delegateQueue.async {
            self.delegates.forEach { $0.sensor(.ACCELEROMETER, didVisit: location) }
        }
    }
}
