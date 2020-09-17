//
//  SonarPayloadSupplier.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

/// SONAR payload supplier for integration with SONAR protocol. Payload data is 129 bytes.
public protocol SonarPayloadDataSupplier : PayloadDataSupplier {
}

/// Mock SONAR payload supplier for simulating payload transfer of the same size
public class MockSonarPayloadSupplier : SonarPayloadDataSupplier {
    static let length: Int = 129
    let identifier: Int32
    
    public init(identifier: Int32) {
        self.identifier = identifier
    }
    
    private func networkByteOrderData(_ identifier: Int32) -> Data {
        var mutableSelf = identifier.bigEndian // network byte order
        return Data(bytes: &mutableSelf, count: MemoryLayout.size(ofValue: mutableSelf))
    }
    
    public func payload(_ timestamp: PayloadTimestamp = PayloadTimestamp()) -> PayloadData {
        var payloadData = PayloadData()
        // First 3 bytes are reserved in SONAR
        payloadData.append(Data(repeating: 0, count: 3))
        payloadData.append(networkByteOrderData(identifier))
        // Fill with blank data to make payload the same size as that in SONAR
        payloadData.append(Data(repeating: 0, count: MockSonarPayloadSupplier.length - payloadData.count))
        return payloadData
    }
}
