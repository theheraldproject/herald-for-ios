//
//  RandomSource.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class RandomSource {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "RandomSource")
    private let method: RandomSourceMethod
    private let testValue: UInt8
    
    public init(method: RandomSourceMethod = .SecureRandom, testValue: UInt8 = UInt8.max) {
        self.method = method
        self.testValue = testValue
        if method == .Test {
            logger.fault("RandomSource in Test mode, not for production use")
        }
    }
    
    public func nextBytes(_ bytes: inout [UInt8]) -> Bool {
        switch method {
        case .Random:
            return RandomSource.nextBytesRandom(&bytes)
        case .SecureRandom:
            return RandomSource.nextBytesSecureRandom(&bytes)
        case .Test:
            return nextBytesTest(&bytes)
        }
    }
    
    private static func nextBytesRandom(_ bytes: inout [UInt8]) -> Bool {
        guard bytes.count > 0 else {
            return true
        }
        for i in 0...bytes.count-1 {
            bytes[i] = UInt8.random(in: 0...UInt8.max)
        }
        return true
    }
    
    private static func nextBytesSecureRandom(_ bytes: inout [UInt8]) -> Bool {
        guard errSecSuccess == SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) else {
            return false
        }
        return true
    }

    private func nextBytesTest(_ bytes: inout [UInt8]) -> Bool {
        guard bytes.count > 0 else {
            return true
        }
        for i in 0...bytes.count-1 {
            bytes[i] = testValue
        }
        return true
    }
}

public enum RandomSourceMethod {
    case Random, SecureRandom, Test
}
