//
//  TextFile.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class TextFile {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Data.TextFile")
    let url: URL?
    private let queue: DispatchQueue
    
    public init(filename: String) {
        url = try? FileManager.default
        .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        .appendingPathComponent(filename)
        queue = DispatchQueue(label: "Sensor.Data.TextFile(\(filename))")
    }
    
    /// Get contents of file
    func contentsOf() -> String {
        queue.sync {
            guard let file = url else {
                return ""
            }
            guard let contents = try? String(contentsOf: file, encoding: .utf8) else {
                return ""
            }
            return contents
        }
    }
    
    func empty() -> Bool {
        guard let file = url else {
            return true
        }
        guard FileManager.default.fileExists(atPath: file.path) else {
            return true
        }
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: file.path),
              let size = attributes[FileAttributeKey.size] as? UInt64 else {
            return true
        }
        return size == 0
    }
    
    /// Append line to new or existing file
    func write(_ line: String) {
        queue.sync {
            guard let file = url else {
                return
            }
            guard let data = (line+"\n").data(using: .utf8) else {
                return
            }
            if FileManager.default.fileExists(atPath: file.path) {
                if let fileHandle = try? FileHandle(forWritingTo: file) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: file, options: .atomicWrite)
            }
        }
    }
    
    /// Overwrite file content
    func overwrite(_ content: String) {
        queue.sync {
            guard let file = url else {
                return
            }
            guard let data = content.data(using: .utf8) else {
                return
            }
            try? data.write(to: file, options: .atomicWrite)
        }
    }
    
    /// Quote value for CSV output if required.
    static func csv(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("'") || value.contains("’") else {
            return value
        }
        return "\"" + value + "\""

    }
}
