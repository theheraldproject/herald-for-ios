//
//  Device.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

public class Device : NSObject {
    /// Device registratiion timestamp
    var createdAt: Date
    /// Last time anything changed, e.g. attribute update
    var lastUpdatedAt: Date
    
    /// Ephemeral device identifier, e.g. peripheral identifier UUID
    var identifier: TargetIdentifier
    
    init(_ identifier: TargetIdentifier) {
        self.createdAt = Date()
        self.identifier = identifier
        lastUpdatedAt = createdAt
    }
}
