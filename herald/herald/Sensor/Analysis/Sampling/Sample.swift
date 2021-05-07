//
//  Sample.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class Sample {
    public let taken:Date
    public let value:DoubleValue
    public let valueType: ValueType
    public var description: String { get {
        return "(" + taken.description + "," + String(describing: value) + ")"
    } }
    
    public init(taken: Date, value: DoubleValue) {
        self.taken = taken
        self.value = value
        self.valueType = ValueType(describing: type(of: value))
    }
    
    public convenience init(timeIntervalSince1970: TimeInterval, value: DoubleValue) {
        self.init(taken: Date(timeIntervalSince1970: timeIntervalSince1970), value: value)
    }
    
    public convenience init(secondsSinceUnixEpoch: Int64, value: DoubleValue) {
        self.init(taken: Date(timeIntervalSince1970: TimeInterval(secondsSinceUnixEpoch)), value: value)
    }
    
    public convenience init(sample: Sample) {
        self.init(taken: sample.taken, value: sample.value)
    }
    
    public convenience init(value: DoubleValue) {
        self.init(taken: Date(), value: value)
    }
}

public class SampledID: Equatable, Comparable, Hashable, CustomStringConvertible {
    public let value: Int64
    public var description: String { get { value.description }}
    
    public init(_ value: Int64) {
        self.value = value
    }
    
    public init(_ data: Data) {
        var hashValue: [UInt8] = [0,0,0,0,0,0,0,0]
        for i in 0...data.count-1 {
            let j = i % 8
            hashValue[j] = hashValue[j] ^ data[i]
        }
        self.value = Data(hashValue).int64(0)!
    }
    
    public static func == (lhs: SampledID, rhs: SampledID) -> Bool {
        return lhs.value == rhs.value
    }
    
    public static func < (lhs: SampledID, rhs: SampledID) -> Bool {
        return lhs.value < rhs.value
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

public typealias ValueType = String
