//
//  Logger.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import UIKit
import os

public protocol SensorLogger {
    init(subsystem: String, category: String)
    
    func log(_ level: SensorLoggerLevel, _ message: String)
    
    func debug(_ message: String)
    
    func info(_ message: String)
    
    func fault(_ message: String)
}

public enum SensorLoggerLevel: String {
    case off, debug, info, fault
}

public class ConcreteSensorLogger: NSObject, SensorLogger, Resettable {
    private let subsystem: String
    private let category: String
    private let dateFormatter = DateFormatter()
    private let log: OSLog?
    private static let logFile = TextFile(filename: "log.txt")
    
    public required init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if #available(iOS 10.0, *) {
            log = OSLog(subsystem: subsystem, category: category)
        } else {
            log = nil
        }
    }
    
    private func suppress(_ level: SensorLoggerLevel) -> Bool {
        if (BLESensorConfiguration.logLevel == .off) {
            return true
        }
        switch level {
        case .debug:
            return (BLESensorConfiguration.logLevel == .info || BLESensorConfiguration.logLevel == .fault)
        case .info:
            return (BLESensorConfiguration.logLevel == .fault)
        default:
            return false
        }
    }
    
    public func log(_ level: SensorLoggerLevel, _ message: String) {
        guard !suppress(level) else {
            return
        }
        // Write to unified os log if available, else print to console
        let timestamp = dateFormatter.string(from: Date())
        let csvMessage = message.replacingOccurrences(of: "\"", with: "'")
        let quotedMessage = (message.contains(",") ? "\"" + csvMessage + "\"" : csvMessage)
        let entry = timestamp + "," + level.rawValue + "," + subsystem + "," + category + "," + quotedMessage
        ConcreteSensorLogger.logFile.write(entry)
        guard let log = log else {
            print(entry)
            return
        }
        if #available(iOS 10.0, *) {
            switch (level) {
            case .debug:
                os_log("%s", log: log, type: .debug, message)
            case .info:
                os_log("%s", log: log, type: .info, message)
            case .fault:
                os_log("%s", log: log, type: .fault, message)
            default:
                return
            }
            return
        }
    }
    
    public func debug(_ message: String) {
        log(.debug, message)
    }
    
    public func info(_ message: String) {
        log(.info, message)
    }
    
    public func fault(_ message: String) {
        log(.fault, message)
    }
    
    // MARK: - Resettable
    
    public func reset() {
        ConcreteSensorLogger.logFile.reset()
    }
}
