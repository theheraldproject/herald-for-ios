//
//  SHA.swift
//
//  Copyright © 2020 {COPYRIGHT}. All rights reserved.
//

import Foundation
import CommonCrypto

/**
 SHA hashing algorithm bridge for CommonCrypto implementations.
 */
class SHA {
    /**
     Compute SHA256 hash of data.
     */
    static func hash(data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }
}
