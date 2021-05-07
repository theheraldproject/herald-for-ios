//
//  PayloadDataFormatter.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: MIT
//

import Foundation

public protocol PayloadDataFormatter {
    func shortFormat(_ payloadData: PayloadData) -> String
}

public struct ConcretePayloadDataFormatter : PayloadDataFormatter {
    public init() {}
    
    public func shortFormat(_ payloadData: PayloadData) -> String {
        return payloadData.shortName
    }
}
