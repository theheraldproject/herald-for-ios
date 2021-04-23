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

public typealias SampledID = Int64

public typealias ValueType = String
