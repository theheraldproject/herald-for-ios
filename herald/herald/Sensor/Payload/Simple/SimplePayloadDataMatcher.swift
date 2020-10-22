//
//  SonarPayloadDataIdentifier.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

/// Simple payload matcher for matching contact identifier in payload data against matching keys
protocol SimplePayloadDataMatcher : PayloadDataMatcher {
}

class ConcreteSimplePayloadDataMatcher : SimplePayloadDataMatcher {
    private var bloomFilters: [Int:BloomFilter] = [:]
    
    /// Create matcher for matching contact identifiers against identifiers associated with matching keys
    init(_ matchingKeys: [Date:[MatchingKey]]) {
        matchingKeys.forEach { date, matchingKeysOnDate in
            let day = K.day(date)
            let bloomFilter = BloomFilter(1024*1024*8)
            bloomFilters[day] = bloomFilter
            matchingKeysOnDate.forEach { matchingKey in
                K.contactKeys(matchingKey).map({ K.contactIdentifier($0) }).forEach { contactIdentifier in
                    bloomFilter.add(contactIdentifier)
                }
            }
        }
    }
    
    func matches(_ timestamp: PayloadTimestamp, _ data: PayloadData) -> Bool {
        let day = K.day(timestamp)
        guard let bloomFilter = bloomFilters[day] else {
            return false
        }
        let contactIdentifier = ContactIdentifier(data.subdata(in: 7..<23))
        return bloomFilter.contains(contactIdentifier)
    }
}

