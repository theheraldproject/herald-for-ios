//
//  Logger.swift
//  
//
//  Created  on 24/07/2020.
//  Copyright © 2020 . All rights reserved.
//

import Foundation
import UIKit
import os

protocol Logger {
    init(subsystem: String, category: String)
    
    func log(_ level: LogLevel, _ message: String)
    
    func debug(_ message: String)
    
    func info(_ message: String)
    
    func fault(_ message: String)
}

enum LogLevel: String {
    case debug, info, fault
}

class ConcreteLogger: NSObject, Logger {
    private let subsystem: String
    private let category: String
    private let log: OSLog?
    private static let logFile = TextFile(filename: "log.txt")

    required init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
        if #available(iOS 10.0, *) {
            log = OSLog(subsystem: subsystem, category: category)
        } else {
            log = nil
        }
    }

    func log(_ level: LogLevel, _ message: String) {
        // Write to unified os log if available, else print to console
        let entry = Date().description + "::" + level.rawValue + "::" + subsystem + "::" + category + " :: " + message
        ConcreteLogger.logFile.write(entry)
        guard let log = log else {
            debugPrint(entry)
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
            }
            return
        }
    }
    
    func debug(_ message: String) {
        log(.debug, message)
    }
    
    func info(_ message: String) {
           log(.debug, message)
       }
    
    func fault(_ message: String) {
           log(.debug, message)
       }

}
