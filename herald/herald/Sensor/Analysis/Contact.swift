//
//  Contact.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

/// Contact record describing a period of exposure
struct Contact {
    let startTime: Date
    let endTime: Date
    let proximity: Proximity
    let target: PayloadDataSource
    let targetStatus: ContactHealthStatus
}

enum ContactHealthStatus: String {
    case notInfectious, infectious
}
