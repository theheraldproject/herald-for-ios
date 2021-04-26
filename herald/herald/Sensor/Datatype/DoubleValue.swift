//
//  DoubleValue.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class DoubleValue: CustomStringConvertible {
    private let internalDoubleValue: Double
    public var description: String { get { internalDoubleValue.description }}
    
    public init(doubleValue: Double) {
        self.internalDoubleValue = doubleValue
    }
    
    public func doubleValue() -> Double {
        return internalDoubleValue
    }
}

public class RSSI: DoubleValue {
    public let value: Int
    public override var description: String { get { "RSSI{value=\(value.description)}" }}
    public init(_ value: Double) {
        self.value = Int(round(value))
        super.init(doubleValue: value)
    }
    public init(_ value: Int) {
        self.value = value
        super.init(doubleValue: Double(value))
    }
}

/// Physical distance in metres
public class Distance: DoubleValue {
    public var value: Double { get { doubleValue() }}
    public override var description: String { get { "Distance{value=\(value.description)}" }}
    public init(_ value: Double) {
        super.init(doubleValue: value)
    }
}
