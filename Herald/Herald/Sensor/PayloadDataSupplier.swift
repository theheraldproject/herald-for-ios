//
//  PayloadDataSupplier.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Payload data supplier for generating payload data that is shared with other devices to provide device identity information while maintaining privacy and security.
/// Implement this to integration your solution with this transport.
public protocol PayloadDataSupplier {
    /// Legacy payload supplier callback - for those transitioning their apps to Herald. Note: Device may be null if Payload in use is same for all receivers
    func legacyPayload(_ timestamp: PayloadTimestamp, device: Device?) -> LegacyPayloadData?
    
    /// Get payload for given timestamp. Use this for integration with any payload generator. Note: Device may be null if Payload in use is same for all receivers
    func payload(_ timestamp: PayloadTimestamp, device: Device?) -> PayloadData?
    
    /// Parse raw data into payloads. This is used to split concatenated payloads that are transmitted via share payload. The default implementation assumes payload data is fixed length.
    func payload(_ data: Data) -> [PayloadData]
}

/// Implements payload splitting function, assuming fixed length payloads.
public extension PayloadDataSupplier {
    
    /// Default implementation returns nil.
    func legacyPayload(_ timestamp: PayloadTimestamp, device: Device?) -> LegacyPayloadData? {
        return nil
    }
    
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
public class PayloadData : Hashable, Equatable {
    public var data: Data
    public var shortName: String {
        guard data.count > 0 else {
            return ""
        }
        guard data.count > 3 else {
            return data.base64EncodedString()
        }
        return String(data.subdata(in: 3..<data.count).base64EncodedString().prefix(6))
    }

    public init(_ data: Data) {
        self.data = data
    }

    public init?(base64Encoded: String) {
        guard let data = Data(base64Encoded: base64Encoded) else {
            return nil
        }
        self.data = data
    }

    public init(repeating: UInt8, count: Int) {
        self.data = Data(repeating: repeating, count: count)
    }

    public init() {
        self.data = Data()
    }
    
    // MARK:- Data
    
    public var count: Int { get { data.count }}
    
    public var hexEncodedString: String { get { data.hexEncodedString }}
    
    public func base64EncodedString() -> String {
        return data.base64EncodedString()
    }
    
    public func subdata(in range: Range<Data.Index>) -> Data {
        return data.subdata(in: range)
    }
    
    // MARK:- Hashable
    
    public var hashValue: Int { get { data.hashValue } }
    
    public func hash(into hasher: inout Hasher) {
        data.hash(into: &hasher)
    }
    
    // MARK:- Equatable
    
    public static func ==(lhs: PayloadData, rhs: PayloadData) -> Bool {
        return lhs.data == rhs.data
    }
    
    // MARK:- Append
    public func append(_ other: PayloadData) {
        data.append(other.data)
    }
    
    public func append(_ other: Data) {
        data.append(other)
    }

    public func append(_ other: Int8) {
        data.append(other)
    }

    public func append(_ other: Int16) {
        data.append(other)
    }
    
    public func append(_ other: Int32) {
        data.append(other)
    }
    
    public func append(_ other: Int64) {
        data.append(other)
    }

    public func append(_ other: UInt8) {
        data.append(other)
    }

    public func append(_ other: UInt16) {
        data.append(other)
    }
    
    public func append(_ other: UInt32) {
        data.append(other)
    }
    
    public func append(_ other: UInt64) {
        data.append(other)
    }
    
    @available(iOS 14.0, *)
    public func append(_ other: Float16) {
        data.append(other)
    }
    
    public func append(_ other: Float32) {
        data.append(other)
    }
}

/// Payload data associated with legacy service
public class LegacyPayloadData : PayloadData {
    public let service: UUID
    public var protocolName: ProtocolName { get {
        switch service.uuidString {
        case BLESensorConfiguration.linuxFoundationServiceUUID.uuidString:
            return .HERALD
        case BLESensorConfiguration.legacyHeraldServiceUUID.uuidString:
            if BLESensorConfiguration.legacyHeraldServiceDetectionEnabled {
                return .HERALD
            } else {
                return .UNKNOWN
            }
        case BLESensorConfiguration.interopOpenTraceServiceUUID.uuidString:
            return .OPENTRACE
        case BLESensorConfiguration.interopAdvertBasedProtocolServiceUUID.uuidString:
            return .ADVERT
        default:
            return .UNKNOWN
        }
    }}
    
    public enum ProtocolName : String {
        case UNKNOWN, NOT_AVAILABLE, HERALD, OPENTRACE, ADVERT
    }
    
    public init(service: UUID, data: Data) {
        self.service = service
        super.init(data)
    }
    
    public override var shortName: String { get {
        // Decoder for test payload to assist debugging of OpenTrace interop
        if service.uuidString == BLESensorConfiguration.interopOpenTraceServiceUUID.uuidString {
            if let base64EncodedPayloadData = try? JSONDecoder().decode(CentralWriteDataV2.self, from: data).id,
               let payloadData = PayloadData(base64Encoded: base64EncodedPayloadData) {
                return payloadData.shortName
            }
            if let base64EncodedPayloadData = try? JSONDecoder().decode(PeripheralCharacteristicsDataV2.self, from: data).id,
               let payloadData = PayloadData(base64Encoded: base64EncodedPayloadData) {
                return payloadData.shortName
            }
        }
        return super.shortName
    }}
}


// MARK:- OpenTrace protocol data objects

struct CentralWriteDataV2: Codable {
    var mc: String // phone model of central
    var rs: Double // rssi
    var id: String // tempID
    var o: String // organisation
    var v: Int // protocol version
}

struct PeripheralCharacteristicsDataV2: Codable {
    var mp: String // phone model of peripheral
    var id: String // tempID
    var o: String // organisation
    var v: Int // protocol version
}
