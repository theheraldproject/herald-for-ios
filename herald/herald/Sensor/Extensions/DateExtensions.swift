//
//  DateExtensions.swift
//
//  Copyright 2021 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

extension Date {

    static func - (lhs: Date, rhs: Date) -> TimeInterval {
        return lhs.timeIntervalSinceReferenceDate - rhs.timeIntervalSinceReferenceDate
    }
}
