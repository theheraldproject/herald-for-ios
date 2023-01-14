//
//  SensorDelegateLogger.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Default sensor delegate with convenient functions for writing data to log file.
public class SensorDelegateLogger: SensorDelegate, Resettable {
    private let textFile: TextFile?
    internal let dateFormatter = DateFormatter()
    
    public init() {
        textFile = nil
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    public init(filename: String) {
        textFile = TextFile(filename: filename)
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }
    
    public func reset() {
        guard let textFile = textFile else {
            return
        }
        textFile.reset()
    }
    
    /// Get current time as formatted timestamp "yyyy-MM-dd HH:mm:ss"
    func timestamp() -> String {
        let timestamp = dateFormatter.string(from: Date())
        return TextFile.csv(timestamp)
    }
    
    /// Wrap value as CSV format value.
    func csv(_ value: String) -> String {
        return TextFile.csv(value)
    }
    
    /// Write line. This function will add newline character to end of line.
    func write(_ line: String) {
        guard let textFile = textFile else {
            return
        }
        textFile.write(line)
    }
    
    /// Overwrite file content.
    func overwrite(_ content: String) {
        guard let textFile = textFile else {
            return
        }
        textFile.overwrite(content)
    }
    
    /// Test if the file is empty.
    func empty() -> Bool {
        guard let textFile = textFile else {
            return false
        }
        return textFile.empty()
    }
    
    /// Return contents of file.
    func contentsOf() -> String {
        guard let textFile = textFile else {
            return ""
        }
        return textFile.contentsOf()
    }
    
    // MARK: - SensorDelegate
    
    public func sensor(_ sensor: SensorType, didVisit: Location?) {
    }
    
    public func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
    }
    
    public func sensor(_ sensor: SensorType, available: Bool, didDeleteOrDetect: TargetIdentifier) {
    }
    
    public func sensor(_ sensor: SensorType, didUpdateState: SensorState) {
    }
    
    public func sensor(_ sensor: SensorType, didReceive: Data, fromTarget: TargetIdentifier) {
    }
    
    public func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
    }
    
    public func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
    }
    
    public func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
    }
    
    public func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData) {
    }
}
