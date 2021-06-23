//
//  PayloadDataMatcher.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Payload data matcher for testing whether payload data exists in a matching set, e.g. keys associated with infectious users.
protocol PayloadDataMatcher {
    
    /// Test if payload data captured at a specific time is in the matching set.
    func matches(_ timestamp: PayloadTimestamp, _ data: PayloadData) -> Bool
}
