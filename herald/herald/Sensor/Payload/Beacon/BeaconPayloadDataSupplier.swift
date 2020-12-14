//
//  BeaconPayloadDataSupplier.swift
//
//  Copyright 2020 VMware, Inc.
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
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Payload.ConcreteBeaconPayloadDataSupplierV1")
    private static let protocolAndVersion : UInt8 = 0x30 // V1 of Beacon protocol
    private let payloadLength: Int = 9 // default, may be more with extended data area
    private var commonHeader: Data // 5 bytes
    private var codePayload: Data // 4 bytes
    private var extendedData: ExtendedData? // 0+ bytes
    private var fullPayload: Data // 9+ bytes
    
    public init(countryCode: UInt16, stateCode: UInt16, code: UInt32, extendedData: ExtendedData? = nil) {
        // Generate common header
        // All data is big endian
        var protocolAndVersionValue = ConcreteBeaconPayloadDataSupplierV1.protocolAndVersion.bigEndian
        let protocolAndVersionData = Data(bytes: &protocolAndVersionValue, count: MemoryLayout.size(ofValue: protocolAndVersionValue))
        var countryCodeValue = countryCode.littleEndian
        let countryCodeData = Data(bytes: &countryCodeValue, count: MemoryLayout.size(ofValue: countryCodeValue))
        var stateCodeValue = stateCode.littleEndian
        let stateCodeData = Data(bytes: &stateCodeValue, count: MemoryLayout.size(ofValue: stateCodeValue))
        // Common header = protocolAndVersion + countryCode + stateCode
        var commonHeader = Data()
        commonHeader.append(protocolAndVersionData)
        commonHeader.append(countryCodeData)
        commonHeader.append(stateCodeData)
        self.commonHeader = commonHeader

        // Generate beacon payload
        var codeValue = code.littleEndian
        self.codePayload = Data(bytes: &codeValue, count: MemoryLayout.size(ofValue: codeValue))
        // Beacon payload = commonHeader + Beacon Registration Code + Extended Data
        var fullPayload = Data()
        fullPayload.append(commonHeader)
        fullPayload.append(codePayload)
        self.extendedData = extendedData
        if let extended = extendedData {
            // append to payload
            if extended.hasData() {
                fullPayload.append(extended.payload()!)
            }
        }
        self.fullPayload = fullPayload
    }
    
    // MARK:- SimplePayloadDataSupplier
    
    public func legacyPayload(_ timestamp: PayloadTimestamp = PayloadTimestamp(), device: Device?) -> PayloadData? {
        return nil
    }
    
    public func payload(_ timestamp: PayloadTimestamp = PayloadTimestamp(), device: Device?) -> PayloadData? {
        var payloadData = PayloadData()
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
