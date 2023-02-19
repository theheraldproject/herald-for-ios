//
//  PayloadDataFormatter.swift
//
//  Copyright 2021-2023 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
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
