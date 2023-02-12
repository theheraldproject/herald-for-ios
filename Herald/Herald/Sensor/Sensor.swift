//
//  Sensor.swift
//
//  Copyright 2020-2023 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Sensor for detecting and tracking various kinds of disease transmission vectors, e.g. contact with people, time at location.
public protocol Sensor {
    /// Add delegate for responding to sensor events.
    func add(delegate: SensorDelegate)
    
    /// Start sensing.
    func start()
    
    /// Stop sensing.
    func stop()
    
    /// Retrieve a CoordinationProvider
    func coordinationProvider() -> CoordinationProvider?
}

