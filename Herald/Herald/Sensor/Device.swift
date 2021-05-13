//
//  Device.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class Device : NSObject {
    /// Device registratiion timestamp
    var createdAt: Date
    /// Last time anything changed, e.g. attribute update
    var lastUpdatedAt: Date
    
    /// Ephemeral device identifier, e.g. peripheral identifier UUID
    public var identifier: TargetIdentifier
    
    init(_ identifier: TargetIdentifier) {
        self.createdAt = Date()
        self.identifier = identifier
        lastUpdatedAt = createdAt
    }
}
