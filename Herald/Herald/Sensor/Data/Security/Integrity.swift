//
//  Integrity.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import CommonCrypto

/// Cryptographically secure hash function
public protocol Integrity {
    
    func hash(_ data: Data) -> Data
}

/// SHA256 cryptographic hash function
/// NCSC Foundation Profile for TLS requires integrity check using SHA-256
public class SHA256: Integrity {
    
    public func hash(_ data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes({ _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) })
        return Data(hash)
    }
}
