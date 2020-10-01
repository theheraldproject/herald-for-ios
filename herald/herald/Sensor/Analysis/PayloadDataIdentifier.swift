////
//  PayloadDataIdentifier.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

/// Payload data identifier for establising the source of the payload data.
/// Please note, identity in this context is an abstract concept. It doesn't necessarily mean the actual source (i.e. phone, person).
/// It could simply be a randomly generated identifier for distinguishing different sources.
public protocol PayloadDataIdentifier {
    
    /// Get payload data source for payload data captured at a given time. Use this to resolve the source of a payload for matching and cumulative risk calculation.
    func identify(_ timestamp: PayloadTimestamp, _ data: PayloadData) -> PayloadDataSource?    
}

/// Source of the payload data
public typealias PayloadDataSource = Data
