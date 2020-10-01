//
//  SonarPayloadDataIdentifier.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

/// Simple payload identifier for matching contact identifier in payload data against matching keys
public protocol SimplePayloadDataIdentifier : PayloadDataIdentifier {
}

public class ConcreteSimplePayloadDataIdentifier : SimplePayloadDataIdentifier {
    private var matchingKeys: [Int:[MatchingKey]] = [:]
    
    public func add(_ matchingKey: MatchingKey, onDate: Date) {
        let day = K.day(onDate)
        if matchingKeys[day] == nil {
            matchingKeys[day] = []
        }
        matchingKeys[day]?.append(matchingKey)
        
    }
    
    public func identify(_ timestamp: PayloadTimestamp, _ data: PayloadData) -> PayloadDataSource? {
        let day = K.day(timestamp)
        let contactIdentifier = ContactIdentifier(data.subdata(in: 7..<23))
        return PayloadDataSource(data.subdata(in: 3..<7))
    }
}

