//
//  BeaconPayloadDataSupplier.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import CommonCrypto
import Accelerate

/// Beacon payload data supplier. Payload data is 9+ bytes.
public protocol BeaconPayloadDataSupplier : PayloadDataSupplier {
}

/// Beacon payload data supplier.
public class ConcreteBeaconPayloadDataSupplierV1 : BeaconPayloadDataSupplier {
    private static let protocolAndVersion : UInt8 = 0x30 // V1 of Beacon protocol

    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Payload.ConcreteBeaconPayloadDataSupplierV1")
    private let payloadLength: Int = 9 // default, may be more with extended data area
    private let fullPayload: Data // 9+ bytes
    
    public init(countryCode: UInt16, stateCode: UInt16, code: UInt32, extendedData: ExtendedData? = nil) {
        // Generate common header
        // Common header = protocolAndVersion + countryCode + stateCode
        var commonHeader = Data()
        commonHeader.append(ConcreteBeaconPayloadDataSupplierV1.protocolAndVersion)
        commonHeader.append(countryCode)
        commonHeader.append(stateCode)

        // Generate beacon payload
        // Beacon payload = commonHeader + Beacon Registration Code + Extended Data
        var fullPayload = Data()
        fullPayload.append(commonHeader)
        fullPayload.append(code)
        if let extended = extendedData {
            // append to payload
            if extended.hasData() {
                fullPayload.append(extended.payload()!.data)
            }
        }
        self.fullPayload = fullPayload
    }
    
    // MARK:- SimplePayloadDataSupplier
    
    public func legacyPayload(_ timestamp: PayloadTimestamp = PayloadTimestamp(), device: Device?) -> PayloadData? {
        return nil
    }
    
    public func payload(_ timestamp: PayloadTimestamp = PayloadTimestamp(), device: Device?) -> PayloadData? {
        let payloadData = PayloadData()
        payloadData.append(fullPayload)
        return payloadData
    }
    
    /// Default implementation assumes fixed length payload data with no extended data
    public func payload(_ data: Data) -> [PayloadData] {
        // Split data into payloads based on fixed length
        var payloads: [PayloadData] = []
        var indexStart = 0, indexEnd = 9 // TODO dynamically check from payload extended data
        while indexEnd <= data.count {
            let payload = PayloadData(data.subdata(in: indexStart..<indexEnd))
            payloads.append(payload)
            indexStart += payloadLength
            indexEnd += payloadLength
        }
        return payloads
    }
}
