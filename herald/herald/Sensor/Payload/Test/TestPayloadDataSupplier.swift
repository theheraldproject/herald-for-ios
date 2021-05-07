//
//  TestPayloadDataSupplier.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import UIKit

/// Test payload data supplier for generating fixed payload to support evaluation
public protocol TestPayloadDataSupplier : PayloadDataSupplier {
}

public class ConcreteTestPayloadDataSupplier : TestPayloadDataSupplier {
    let length: Int
    let identifier: Int32
    
    public init(identifier: Int32, length: Int = 129) {
        self.identifier = identifier
        self.length = length
    }
    
    public func legacyPayload(_ timestamp: PayloadTimestamp = PayloadTimestamp(), device: Device?) -> LegacyPayloadData? {
        guard let device = device as? BLEDevice, let rssi = device.rssi, let payload = payload(timestamp, device: device),
              let service = UUID(uuidString: BLESensorConfiguration.interopOpenTraceServiceUUID.uuidString) else {
            return nil
        }
        do {
            let dataToWrite = CentralWriteDataV2(
                mc: deviceModel(),
                rs: Double(rssi),
                id: payload.base64EncodedString(),
                o: "OT_HA",
                v: 2)
            let encodedData = try JSONEncoder().encode(dataToWrite)
            let legacyPayloadData = LegacyPayloadData(service: service, data: encodedData)
            return legacyPayloadData
        } catch {
        }
        return nil
    }
    
    public func payload(_ timestamp: PayloadTimestamp = PayloadTimestamp(), device: Device?) -> PayloadData? {
        let payloadData = PayloadData()
        // First 1 byte = protocolAndVersion (UInt8)
        payloadData.append(UInt8(0))
        // Next 2 bytes = countryCode (UInt16)
        payloadData.append(UInt16(0))
        // Next 4 bytes are used for fixed cross-platform identifier (Int32)
        payloadData.append(Int32(identifier))
        // Fill with blank data to make payload the same size expected length
        payloadData.append(Data(repeating: 0, count: length - payloadData.count))
        return payloadData
    }
    
    private func deviceModel() -> String {
        var deviceInformation = utsname()
        uname(&deviceInformation)
        let mirror = Mirror(reflecting: deviceInformation.machine)
        return mirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else {
                return identifier
            }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
}
