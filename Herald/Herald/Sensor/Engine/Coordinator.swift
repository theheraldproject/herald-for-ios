//
//  Coordinator.swift
//
//  Copyright 2023 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//
//  Created by Adam Fowler on 07/02/2023.
//

import Foundation

///
/// Provides timed action collection and coordination based upon the concept of Features and Providers
///
//class Coordinator: NSObject {
//    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Engine.Coordinator")
//    private var running: Bool = false
//    private var providers: [CoordinationProvider] = []
//    private var featureProviders: [FeatureTag : CoordinationProvider] = [:]
//    
//    func add(sensor: Sensor) {
//        if let provider = sensor.coordinationProvider() {
//            providers.append(provider)
//        }
//    }
//    
//    func remove(sensor: Sensor) {
//        
//    }
//    
//    func start() {
//        featureProviders.removeAll()
//        for provider in providers {
//            for feature in provider.connectionsProvided() {
//                featureProviders[feature] = provider
//            }
//        }
//    }
//    
//    func iteration() {
//        if !running {
//            logger.debug("Coordinator iteration called when running=false")
//            return
//        }
//        var assignPrereqs: [CoordinationProvider: [PrioritisedPrerequisite]] = [:]
//        var connsRequired: [PrioritisedPrerequisite] = []
//        for provider in providers {
//            for conn in provider.requiredConnections() {
//                connsRequired.append(conn)
//            }
//        }
//        
//        for prereq in connsRequired {
//            var featureProvider: CoordinationProvider = featureProviders[PrioritisedPrerequisite]
//        }
//    }
//    
//    func stop() {
//        
//    }
//}
