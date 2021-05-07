//
//  BloomFilter.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Bloom filter for probabalistic matching of large data sets.
/// False positive matches are possible, but false negatives are not.
/// In other words, a query returns either "possibly in set" or "definitely not in set".
class BloomFilter {
    private let bits: UInt64
    private var filter: [UInt8]

    init(_ bytes: Int) {
        bits = UInt64(bytes * 8)
        filter = Array<UInt8>(repeating: UInt8(0), count: bytes)
    }
    
    private func setBit(_ index: UInt64, _ value: Bool) {
        let bit = index.remainderReportingOverflow(dividingBy: bits).partialValue
        let byteUInt = bit.dividedReportingOverflow(by: 8).partialValue
        let bitInByte = bit - (byteUInt * 8)
        let byte = Int(byteUInt)
        switch bitInByte {
        case 0:
            filter[byte] = (value ? (filter[byte] | 0b10000000) : (filter[byte] & 0b01111111))
        case 1:
            filter[byte] = (value ? (filter[byte] | 0b01000000) : (filter[byte] & 0b10111111))
        case 2:
            filter[byte] = (value ? (filter[byte] | 0b00100000) : (filter[byte] & 0b11011111))
        case 3:
            filter[byte] = (value ? (filter[byte] | 0b00010000) : (filter[byte] & 0b11101111))
        case 4:
            filter[byte] = (value ? (filter[byte] | 0b00001000) : (filter[byte] & 0b11110111))
        case 5:
            filter[byte] = (value ? (filter[byte] | 0b00000100) : (filter[byte] & 0b11111011))
        case 6:
            filter[byte] = (value ? (filter[byte] | 0b00000010) : (filter[byte] & 0b11111101))
        default:
            filter[byte] = (value ? (filter[byte] | 0b00000001) : (filter[byte] & 0b11111110))
        }
    }
    
    private func getBit(_ index: UInt64) -> Bool {
        let bit = index.remainderReportingOverflow(dividingBy: bits).partialValue
        let byteUInt = bit.dividedReportingOverflow(by: 8).partialValue
        let bitInByte = bit - (byteUInt * 8)
        let byte = Int(byteUInt)
        switch bitInByte {
        case 0:
            return (filter[byte] & 0b10000000) != 0
        case 1:
            return (filter[byte] & 0b01000000) != 0
        case 2:
            return (filter[byte] & 0b00100000) != 0
        case 3:
            return (filter[byte] & 0b00010000) != 0
        case 4:
            return (filter[byte] & 0b00001000) != 0
        case 5:
            return (filter[byte] & 0b00000100) != 0
        case 6:
            return (filter[byte] & 0b00000010) != 0
        default:
            return (filter[byte] & 0b00000001) != 0
        }
    }
    
    func add(_ data: Data) {
        let bytes = [UInt8](data)
        setBit(XXH3.digest64(bytes), true)
        setBit(XXH3.digest64(bytes.reversed()), true)
    }
    
    func contains(_ data: Data) -> Bool {
        let bytes = [UInt8](data)
        return getBit(XXH3.digest64(bytes)) && getBit(XXH3.digest64(bytes.reversed()))
    }
}
