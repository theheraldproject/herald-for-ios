//
//  JavaData.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Java compatible data conversion for interoperability with Android and Java Server.
class JavaData {
    
    /// Convert 32-byte array to Java long value.
    static func byteArrayToLong(digest: Data) -> Int64 {
        let data = [UInt8](digest)
        let valueData: [UInt8] = [data[0], data[1], data[2], data[3], data[4], data[5], data[6], data[7]].reversed()
        let value = valueData.withUnsafeBytes { $0.load(as: Int64.self) }
        return value
    }
    
    /// Convert Java long value to 32-byte array.
    static func longToByteArray(value: Int64) -> Data {
        let valueData = (withUnsafeBytes(of: value) { Data($0) }).reversed()
        let data = Data(valueData)
        return data
    }

}
