//
//  SonarPayloadSupplier.swift
//  C19X-SENSOR-iOS
//
//  Created by Freddy Choi on 24/07/2020.
//  Copyright © 2020 C19X. All rights reserved.
//

import Foundation

/// SONAR payload supplier for integration with Sonar
protocol SonarPayloadDataSupplier : PayloadDataSupplier {
}

/// Mock SONAR payload supplier for simulating payload transfer of the same size to test C19X-SENSOR
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
        payloadData.append(networkByteOrderData(identifier))
        //payloadData.append(Int32(timestamp.timeIntervalSince1970).networkByteOrderData)
        // Fill with blank data to make payload the same size as that in Sonar
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
