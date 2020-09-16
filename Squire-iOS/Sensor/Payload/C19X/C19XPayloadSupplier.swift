//
//  PayloadSupplier.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

///  payload supplier for integration with  backend. Payload data is 8 bytes.
protocol PayloadDataSupplier : PayloadDataSupplier {
}

///  payload supplier for generating time specific beacon codes based on day codes.
class ConcretePayloadDataSupplier : PayloadDataSupplier {
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
}
