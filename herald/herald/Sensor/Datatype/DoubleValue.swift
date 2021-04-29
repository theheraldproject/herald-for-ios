//
//  DoubleValue.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Generic mutable double value
public class DoubleValue: CustomStringConvertible {
    public var value: Double
    public var description: String { get { value.description }}
    
    public init(_ value: Double) {
        self.value = value
    }

    public init(_ value: Int) {
        self.value = Double(value)
    }
}

/// Received signal strength indicator (RSSI)
public class RSSI: DoubleValue {
    public override var description: String { get { "RSSI{value=\(value.description)}" }}
}

/// Physical distance in metres
public class Distance: DoubleValue {
    public override var description: String { get { "Distance{value=\(value.description)}" }}
}
