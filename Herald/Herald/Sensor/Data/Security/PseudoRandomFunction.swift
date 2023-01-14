//
//  PseudoRandomFunction.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public protocol PseudoRandomFunction {
    
    /// Get next bytes from random function
    func nextBytes(_ data: inout Data) -> Bool
}

public extension PseudoRandomFunction {

    func nextBytes(_ count: Int) -> Data {
        var data = Data(repeating: 0, count: max(0, count))
        if !nextBytes(&data) {
            let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Data.Security.PseudoRandomFunction")
            logger.fault("Random function failed, reverting to UInt8 random")
            for i in 0...data.count-1 {
                data[i] = UInt8.random(in: UInt8.min...UInt8.max)
            }
        }
        return data
    }
    
    func nextInt64() -> Int64 {
        return nextBytes(8).int64(0)!
    }
}

public class SecureRandomFunction: PseudoRandomFunction {

    public init() {
    }
    
    public func nextBytes(_ data: inout Data) -> Bool {
        var bytes = [UInt8](repeating: 0, count: data.count)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard errSecSuccess == status else {
            return false
        }
        withUnsafeMutablePointer(to: &data) { pointer in
            for i in 0...pointer.pointee.count-1 {
                pointer.pointee[i] = bytes[i]
            }
        }
        return true
    }
}

/// Test random source that produces the same ressult for all calls
public class TestRandomFunction: PseudoRandomFunction {
    private let value: UInt8
    
    public init(_ value: UInt8 = UInt8.max) {
        self.value = value
    }
    
    public func nextBytes(_ data: inout Data) -> Bool {
        for i in 0...data.count - 1 {
            data[i] = value
        }
        return true
    }
}

