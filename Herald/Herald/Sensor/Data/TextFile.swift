//
//  TextFile.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class TextFile: Resettable {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Data.TextFile")
    public let url: URL?
    private let queue: DispatchQueue
    
    public init(filename: String) {
        url = try? FileManager.default
        .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        .appendingPathComponent(filename)
        queue = DispatchQueue(label: "Sensor.Data.TextFile(\(filename))")
    }
    
    public func reset() {
        overwrite("")
    }
    
    public static func removeAll() -> Bool {
        let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Data.TextFile")
        guard let url = try? FileManager.default
                .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true) else {
            return true
        }
        guard let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            return true
        }
        var success = true
        for file in files {
            do {
                try FileManager.default.removeItem(at: file)
                logger.debug("Remove file successful (folder=\(url),file=\(file.lastPathComponent))");
            } catch {
                logger.fault("Remove file failed (folder=\(url),file=\(file.lastPathComponent))");
                success = false
            }
        }
        return success
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
                    
                    if #available(iOS 13.4, *) {
                        try? fileHandle.seekToEnd()
                        try? fileHandle.write(contentsOf: data)
                        try? fileHandle.close()
                    } else {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
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
