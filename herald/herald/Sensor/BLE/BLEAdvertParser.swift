//
//  BLEAdvertParser.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

class BLEAdvertParser {
    
    static func extractSegments(_ raw: Data, _ offset: Int) -> [BLEAdvertSegment] {
        var position = offset
        var segments: [BLEAdvertSegment] = []
        while (position < raw.count) {
            if ((position + 2) <= raw.count) {
                let segmentLength = Int(raw[position] & 0xFF)
                position+=1
                let segmentType = raw[position] & 0xFF
                position+=1
                // Note: Unsupported types are handled as 'unknown'
                // check reported length with actual remaining data length
                if ((position + segmentLength - 1) <= raw.count) {
                    let segmentData = subDataBigEndian(raw, position, segmentLength - 1) // Note: type IS INCLUDED in length
                    let rawData = Data(subDataBigEndian(raw, position - 2, segmentLength + 1))
                    position += (segmentLength - 1)
                    segments.append(BLEAdvertSegment(type: BLEAdvertSegmentType(rawValue: segmentType) ?? .unknown, dataLength: segmentLength - 1, data: segmentData, raw: rawData))
                } else {
                    // error in data length - advance to end
                    position = raw.count
                }
            } else {
                // invalid segment - advance to end
                position = raw.count
            }
        }
        return segments
    }
        
    static func extractManufacturerData(segments: [BLEAdvertSegment]) -> [BLEAdvertManufacturerData] {
        // find the manufacturerData code segment in the list
        var manufacturerData: [BLEAdvertManufacturerData] = []
        segments.forEach() { segment in
            guard segment.type == .manufacturerData, segment.data.count >= 2 else {
                return // there may be a valid segment of same type... Happens for manufacturer data
            }
            // Create a manufacturer data segment
            let intValue = Int(((segment.data[1] & 0xFF) << 8) | (segment.data[0] & 0xFF))
            manufacturerData.append(BLEAdvertManufacturerData(manufacturer: intValue, data: subDataBigEndian(segment.data,2,segment.dataLength - 2), raw: segment.raw))
        }
        return manufacturerData;
    }

    static func subDataBigEndian(_ raw: Data, _ offset: Int, _ length: Int) -> Data {
        guard offset >= 0, length > 0 else {
            return Data()
        }
        guard offset + length <= raw.count else {
            return Data()
        }
        return raw.subdata(in: offset..<offset+length)
    }

    static func subDataLittleEndian(_ raw: Data, _ offset: Int, _ length: Int) -> Data {
        guard offset >= 0, length > 0 else {
            return Data()
        }
        guard offset + length <= raw.count else {
            return Data()
        }
        return Data(raw.subdata(in: offset..<offset+length).reversed())
    }
}


class BLEAdvertSegment {
    let type: BLEAdvertSegmentType
    let dataLength: Int
    let data: Data // BIG ENDIAN (network order) AT THIS POINT
    let raw: Data
    var description: String { get {
        return "BLEAdvertSegment{type=\(type),dataLength=\(dataLength.description),data=\(data.hexEncodedString),raw=\(raw.hexEncodedString)}"
    }}

    init(type: BLEAdvertSegmentType, dataLength: Int, data: Data, raw: Data) {
        self.type = type
        self.dataLength = dataLength
        self.data = data
        self.raw = raw
    }
}

/// BLE Advert types - Note: We only list those we use in Herald
/// See https://www.bluetooth.com/specifications/assigned-numbers/generic-access-profile/
enum BLEAdvertSegmentType: UInt8 {
    case
    unknown = 0x00, // Valid - this number is not assigned
    serviceUUID16IncompleteList = 0x02,
    serviceUUID16CompleteList = 0x03,
    serviceUUID32IncompleteList = 0x04,
    serviceUUID32CompleteList = 0x05,
    serviceUUID128IncompleteList = 0x06,
    serviceUUID128CompleteList = 0x07,
    deviceNameShortened = 0x08,
    deviceNameComplete = 0x09,
    txPowerLevel = 0x0A,
    deviceClass = 0x0D,
    simplePairingHash = 0x0E,
    simplePairingRandomiser = 0x0F,
    deviceID = 0x10,
    serviceUUID16Data = 0x16,
    meshMessage = 0x2A,
    meshBeacon = 0x2B,
    bigInfo = 0x2C,
    broadcastCode = 0x2D,
    manufacturerData = 0xFF
}

class BLEAdvertManufacturerData {
    let manufacturer: Int
    let data: Data // BIG ENDIAN (network order) AT THIS POINT
    let raw: Data
    var description: String { get {
        return "BLEAdvertManufacturerData{manufacturer=\(manufacturer.description),data=\(data.hexEncodedString),raw=\(raw.hexEncodedString)}"
    }}

    init(manufacturer: Int, data: Data, raw: Data) {
        self.manufacturer = manufacturer
        self.data = data
        self.raw = raw
    }
}
