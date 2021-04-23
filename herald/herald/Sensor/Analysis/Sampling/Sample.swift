//
//  Sample.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class Sample<T: DoubleValue> {
    public let taken:Date
    public let value:T
    public var description: String { get {
        return "(" + taken.description + "," + String(describing: value) + ")"
    } }
    var valueType: T.Type { get {
        return T.self
    } }
    
    public init(taken: Date, value: T) {
        self.taken = taken
        self.value = value
    }
    
    public init(timeIntervalSince1970: TimeInterval, value: T) {
        self.taken = Date(timeIntervalSince1970: timeIntervalSince1970)
        self.value = value
    }
    
    public init(secondsSinceUnixEpoch: Int64, value: T) {
        self.taken = Date(timeIntervalSince1970: TimeInterval(secondsSinceUnixEpoch))
        self.value = value
    }
    
    public init(sample: Sample<T>) {
        self.taken = sample.taken
        self.value = sample.value
    }
    
    public init(value: T) {
        self.taken = Date()
        self.value = value
    }
}

public class DoubleValue {
    private var value: Double = 0
    
    public init() {
    }
    
    public init(doubleValue: Double) {
        self.value = doubleValue
    }
    
    public func doubleValue() -> Double {
        return value
    }
}

public typealias SampledID = Int64
