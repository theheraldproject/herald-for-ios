//
//  DateExtensions.swift
//
//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

extension Date {
    
    var secondsSinceUnixEpoch: Int64 { get { Int64(floor(timeIntervalSince1970)) }}

    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }
}
