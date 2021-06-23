//
//  BLEUtilities.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import CoreBluetooth

/**
 Extension to make the state human readable in logs.
 */
@available(iOS 10.0, *)
extension CBManagerState: CustomStringConvertible {
    /**
     Get plain text description of state.
     */
    public var description: String {
        switch self {
        case .poweredOff: return ".poweredOff"
        case .poweredOn: return ".poweredOn"
        case .resetting: return ".resetting"
        case .unauthorized: return ".unauthorized"
        case .unknown: return ".unknown"
        case .unsupported: return ".unsupported"
        @unknown default: return "undefined"
        }
    }
}

extension CBPeripheralManagerState : CustomStringConvertible {
    /**
     Get plain text description of state.
     */
    public var description: String {
        switch self {
        case .poweredOff: return ".poweredOff"
        case .poweredOn: return ".poweredOn"
        case .resetting: return ".resetting"
        case .unauthorized: return ".unauthorized"
        case .unknown: return ".unknown"
        case .unsupported: return ".unsupported"
        @unknown default: return "undefined"
        }
    }
}

extension CBCentralManagerState : CustomStringConvertible {
    /**
     Get plain text description of state.
     */
    public var description: String {
        switch self {
        case .poweredOff: return ".poweredOff"
        case .poweredOn: return ".poweredOn"
        case .resetting: return ".resetting"
        case .unauthorized: return ".unauthorized"
        case .unknown: return ".unknown"
        case .unsupported: return ".unsupported"
        @unknown default: return "undefined"
        }
    }
}


/**
 Extension to make the state human readable in logs.
 */
extension CBPeripheralState: CustomStringConvertible {
    /**
     Get plain text description fo state.
     */
    public var description: String {
        switch self {
        case .connected: return ".connected"
        case .connecting: return ".connecting"
        case .disconnected: return ".disconnected"
        case .disconnecting: return ".disconnecting"
        @unknown default: return "undefined"
        }
    }
}

/**
 Extension to make the time intervals more human readable in code.
 */
extension TimeInterval {
    public static var never: TimeInterval { get { TimeInterval(Int.max) } }
    public static var fortnight: TimeInterval { get { TimeInterval(1209600) }}
    public static var week: TimeInterval { get { TimeInterval(604800) }}
    public static var day: TimeInterval { get { TimeInterval(86400) } }
    public static var hour: TimeInterval { get { TimeInterval(3600) } }
    public static var minute: TimeInterval { get { TimeInterval(60) } }
}

/**
 Time interval samples for collecting elapsed time statistics.
 */
class TimeIntervalSample : SampleStatistics {
    private var startTime: Date?
    private var timestamp: Date?
    var period: TimeInterval? { get {
        (startTime == nil ? nil : timestamp?.timeIntervalSince(startTime!))
        }}
    
    override var description: String { get {
        let sPeriod = (period == nil ? "-" : period!.description)
        return super.description + ",period=" + sPeriod
        }}
    
    /**
     Add elapsed time since last call to add() as sample.
     */
    func add() {
        guard timestamp != nil else {
            timestamp = Date()
            startTime = timestamp
            return
        }
        let now = Date()
        if let timestamp = timestamp {
            add(now.timeIntervalSince(timestamp))
        }
        timestamp = now
    }
}
