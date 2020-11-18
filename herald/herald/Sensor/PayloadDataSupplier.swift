//
//  PayloadDataSupplier.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import Foundation

/// Payload data supplier for generating payload data that is shared with other devices to provide device identity information while maintaining privacy and security.
/// Implement this to integration your solution with this transport.
public protocol PayloadDataSupplier {
    /// Legacy payload supplier callback - for those transitioning their apps to Herald. Note: Device may be null if Payload in use is same for all receivers
    func legacyPayload(_ timestamp: PayloadTimestamp, device: Device?) -> PayloadData?
    
    /// Get payload for given timestamp. Use this for integration with any payload generator. Note: Device may be null if Payload in use is same for all receivers
    func payload(_ timestamp: PayloadTimestamp, device: Device?) -> PayloadData?
    
    /// Parse raw data into payloads. This is used to split concatenated payloads that are transmitted via share payload. The default implementation assumes payload data is fixed length.
    func payload(_ data: Data) -> [PayloadData]
}

/// Implements payload splitting function, assuming fixed length payloads.
public extension PayloadDataSupplier {
    /// Default implementation assumes fixed length payload data.
    func payload(_ data: Data) -> [PayloadData] {
        // Get example payload to determine length
        let fixedLengthPayload = payload(PayloadTimestamp(), device: nil)
        // Split data into payloads based on fixed length
        var payloads: [PayloadData] = []
        if let fixedLengthPayload = fixedLengthPayload {
            let payloadLength = fixedLengthPayload.count
            var indexStart = 0, indexEnd = payloadLength
            while indexEnd <= data.count {
                let payload = PayloadData(data.subdata(in: indexStart..<indexEnd))
                payloads.append(payload)
                indexStart += payloadLength
                indexEnd += payloadLength
            }
        }
        return payloads
    }
}

/// Payload timestamp, should normally be Date, but it may change to UInt64 in the future to use server synchronised relative timestamp.
public typealias PayloadTimestamp = Date

/// Encrypted payload data received from target. This is likely to be an encrypted datagram of the target's actual permanent identifier.
public typealias PayloadData = Data

public extension PayloadData {
    var shortName: String {
        guard count > 0 else {
            return ""
        }
        guard count > 3 else {
            return base64EncodedString()
        }
        return String(subdata(in: 3..<count).base64EncodedString().prefix(6))
    }
}

