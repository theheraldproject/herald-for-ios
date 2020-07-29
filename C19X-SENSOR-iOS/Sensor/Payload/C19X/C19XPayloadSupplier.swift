//
//  PayloadSupplier.swift
//  
//
//  Created  on 25/07/2020.
//  Copyright © 2020 . All rights reserved.
//

import Foundation

///  payload supplier for integration with .
protocol PayloadDataSupplier : PayloadDataSupplier {
}

///  payload supplier for generating time specific beacon codes based on day codes.
class ConcretePayloadSupplier : PayloadDataSupplier {
    static let length: Int = 8
    private let dayCodes: DayCodes
    private let beaconCodes: BeaconCodes
    private let emptyPayloadData = PayloadData()
    
    init(_ sharedSecret: SharedSecret) {
        dayCodes = ConcreteDayCodes(sharedSecret)
        beaconCodes = ConcreteBeaconCodes(dayCodes)
    }
    
    func payload(_ timestamp: PayloadTimestamp = PayloadTimestamp()) -> PayloadData {
        guard let beaconCode = beaconCodes.get(timestamp) else {
            return emptyPayloadData
        }
        return JavaData.longToByteArray(value: beaconCode)
    }
    
    func payload(_ data: Data) -> [PayloadData] {
        var payloads: [PayloadData] = []
        var indexStart = 0, indexEnd = ConcretePayloadSupplier.length
        while indexEnd <= data.count {
            let payload = PayloadData(data.subdata(in: indexStart..<indexEnd))
            payloads.append(payload)
            indexStart += MockSonarPayloadSupplier.length
            indexEnd += MockSonarPayloadSupplier.length
        }
        return payloads
    }

}
