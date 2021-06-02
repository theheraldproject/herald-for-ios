//
//  Encryption.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import CommonCrypto

/// Cryptographically secure encryption and decryption algorithm
public protocol Encryption {
    
    /// Encrypt data
    func encrypt(data: Data, with: EncryptionKey) -> Data?
    
    /// Decrypt data
    func decrypt(data: Data, with: EncryptionKey) -> Data?
}

public typealias EncryptionKey = Data

/// AES128 encryption algorithm
public class AES128: Encryption {
    private let random = SecureRandomFunction()
    
    // MARK: - Encryption
    
    public func encrypt(data: Data, with: EncryptionKey) -> Data? {
        // Convert key data to hash to ensure key length is 256 bits
        let key = SHA256().hash(with)
        // Generate random initialisation vector (128 bits = 16 bytes)
        var iv = Data(repeating: 0, count: 16)
        guard random.nextBytes(&iv) else {
            return nil
        }
        // Encrypt data with key and iv
        guard let encrypted = crypt(input: data, key: key, iv: iv, operation: CCOperation(kCCEncrypt)) else {
            return nil
        }
        // Build result = iv + encrypted
        var result = Data()
        result.append(iv)
        result.append(encrypted)
        return result
    }
    
    public func decrypt(data: Data, with: EncryptionKey) -> Data? {
        // Convert key data to hash to ensure key length is 256 bits
        let key = SHA256().hash(with)
        // Get iv from first 16 bytes of data
        guard data.count > 16 else {
            return nil
        }
        let iv = data.prefix(16)
        // Get encrypted data after iv
        let encrypted = data.suffix(from: 16)
        // Decrypt data
        guard let decrypted = crypt(input: encrypted, key: key, iv: iv, operation: CCOperation(kCCDecrypt)) else {
            return nil
        }
        return decrypted
    }
    
    // MARK: - Internal functions
    
    /// AES encryption/decryption algorithm
    /// NCSC Foundation Profile for TLS requires encryption with AES with 128-bit key in CBC mode
    private func crypt(input: Data, key: Data, iv: Data, operation: CCOperation) -> Data? {
        // Key must be 16, 24, or 32 bytes (128, 192, or 256 bits)
        guard [16,24,32].contains(key.count) else {
            return nil
        }
        // Initialisation vector (IV) must be 16 bytes (128 bits)
        guard iv.count == 16 else {
            return nil
        }
        // Prepare output buffer (minimum 16 bytes)
        var outputCount = max(16, input.count * 2)
        var output = Array<UInt8>(repeating: 0, count: outputCount)
        // Use CommonCrypto to perform cryptographic operation
        let inputPointer = (input as NSData).bytes
        let keyPointer = (key as NSData).bytes
        let ivPointer = (iv as NSData).bytes
        let status = CCCrypt(operation, CCAlgorithm(kCCAlgorithmAES128), CCOptions(kCCOptionPKCS7Padding),
                             keyPointer, key.count, ivPointer,
                             inputPointer, input.count,
                             &output, output.count, &outputCount)
        guard status == kCCSuccess else {
            return nil
        }
        // Convert CommonCrypto output to Data
        var outputData: Data?
        output.withUnsafeBufferPointer() { pointer in
            if let baseAddress = pointer.baseAddress {
                outputData = Data(bytes: baseAddress, count: outputCount)
            }
        }
        return outputData
    }
}
