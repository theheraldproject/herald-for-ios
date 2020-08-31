//
//  SonarPayloadSupplier.swift
//
//  Copyright © 2020 {COPYRIGHT}. All rights reserved.
//

import Foundation

/// SONAR payload supplier for integration with SONAR protocol
protocol SonarPayloadDataSupplier : PayloadDataSupplier {
}

/// Mock SONAR payload supplier for simulating payload transfer of the same size
class MockSonarPayloadSupplier : SonarPayloadDataSupplier {
    static let length: Int = 129
    let identifier: Int32
    
    init(identifier: Int32) {
        self.identifier = identifier
    }
    
    private func networkByteOrderData(_ identifier: Int32) -> Data {
        var mutableSelf = identifier.bigEndian // network byte order
        return Data(bytes: &mutableSelf, count: MemoryLayout.size(ofValue: mutableSelf))
    }
    
    func payload(_ timestamp: PayloadTimestamp = PayloadTimestamp()) -> PayloadData {
        var payloadData = PayloadData()
        // First 3 bytes are reserved in SONAR
        payloadData.append(Data(repeating: 0, count: 3))
        payloadData.append(networkByteOrderData(identifier))
        // Fill with blank data to make payload the same size as that in SONAR
        payloadData.append(Data(repeating: 0, count: MockSonarPayloadSupplier.length - payloadData.count))
        return payloadData
    }

    func payload(_ data: Data) -> [PayloadData] {
        var payloads: [PayloadData] = []
        var indexStart = 0, indexEnd = MockSonarPayloadSupplier.length
        while indexEnd <= data.count {
            let payload = PayloadData(data.subdata(in: indexStart..<indexEnd))
            payloads.append(payload)
            indexStart += MockSonarPayloadSupplier.length
            indexEnd += MockSonarPayloadSupplier.length
        }
        return payloads
    }
}
