//
//  SonarPayloadDataIdentifier.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
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
                K.forEachContactIdentifier(matchingKey) { contactIdentifier, _ in
                    bloomFilter.add(contactIdentifier)
                }
            }
        }
    }
    
    // MARK:- SimplePayloadDataMatcher
    
    func matches(_ timestamp: PayloadTimestamp, _ data: PayloadData) -> Bool {
        let day = K.day(timestamp)
        guard let bloomFilter = bloomFilters[day] else {
            return false
        }
        let contactIdentifier = ContactIdentifier(data.subdata(in: 5..<ConcreteSimplePayloadDataSupplier.payloadLength))
        return bloomFilter.contains(contactIdentifier)
    }
}

