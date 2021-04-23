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
    init(_ value: Int) {
        self.value = value
        super.init(doubleValue: Double(value))
    }
}

/// Physical distance in KM
public class PhysicalDistance: DoubleValue {
    public var value: Double { get { doubleValue() }}
    public override var description: String { get { "PhysicalDistance{value=\(value.description)}" }}

    init(_ value: Double) {
        super.init(doubleValue: value)
    }

}
