//
//  SonarPayloadDataIdentifier.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

/// SONAR payload identifier
public protocol SonarPayloadDataIdentifier : PayloadDataIdentifier {
}

public class MockSonarPayloadDataIdentifier : SonarPayloadDataIdentifier {
    
    public func identify(_ timestamp: PayloadTimestamp, _ data: PayloadData) -> PayloadDataSource? {
        return PayloadDataSource(data.subdata(in: 3..<7))
    }
    
    func identifier(_ source: PayloadDataSource) -> Int32 {
        let value: Int32 = source.withUnsafeBytes {
            $0.load(as: Int32.self)
        }.bigEndian
        return value
    }
}
