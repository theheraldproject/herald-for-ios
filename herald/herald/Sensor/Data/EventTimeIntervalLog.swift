//
//  EventTimeIntervalLog.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// CSV log of events for analysis and visualisation
public class EventTimeIntervalLog: NSObject, SensorDelegate {
    private let textFile: TextFile
    private let payloadData: PayloadData
    private let eventType: EventTimeIntervalLogEventType
    private var targetIdentifierToPayload: [TargetIdentifier:String] = [:]
    private var payloadToTime: [String:Date] = [:]
    private var payloadToSample: [String:SampleStatistics] = [:]
    
    public init(filename: String, payloadData: PayloadData, eventType: EventTimeIntervalLogEventType) {
        textFile = TextFile(filename: filename)
        self.payloadData = payloadData
        self.eventType = eventType
    }
    
    private func csv(_ value: String) -> String {
        return TextFile.csv(value)
    }
    
    private func add(payload: String) {
        guard let time = payloadToTime[payload], let sample = payloadToSample[payload] else {
            payloadToTime[payload] = Date()
            payloadToSample[payload] = SampleStatistics()
            return
        }
        let now = Date()
        payloadToTime[payload] = now
        sample.add(Double(now.timeIntervalSince(time)))
        write()
    }
    
    private func write() {
        var content = "event,central,peripheral,count,mean,sd,min,max\n"
        var payloadList: [String] = []
        let event = csv(eventType.rawValue)
        let centralPayload = csv(payloadData.shortName)
        payloadToSample.keys.forEach() { payload in
            guard payload != payloadData.shortName else {
                return
            }
            payloadList.append(payload)
        }
        payloadList.sort()
        payloadList.forEach() { payload in
            guard let sample = payloadToSample[payload] else {
                return
            }
            guard let mean = sample.mean, let sd = sample.standardDeviation, let min = sample.min, let max = sample.max else {
                return
            }
            content.append("\(event),\(centralPayload),\(csv(payload)),\(sample.count),\(mean),\(sd),\(min),\(max)\n")
        }
        textFile.overwrite(content)
    }


    // MARK:- SensorDelegate
    
    public func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        let payload = didRead.shortName
        targetIdentifierToPayload[fromTarget] = payload
        guard eventType == .read else {
            return
        }
        add(payload: payload)
    }
    
    public func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
        guard eventType == .detect, let payload = targetIdentifierToPayload[didDetect] else {
            return
        }
        add(payload: payload)
    }
    
    public func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        guard eventType == .measure, let payload = targetIdentifierToPayload[fromTarget] else {
            return
        }
        add(payload: payload)
    }
    
    public func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
        if eventType == .share, let payload = targetIdentifierToPayload[fromTarget] {
            add(payload: payload)
        } else if eventType == .sharedPeer {
            didShare.forEach() { sharedPayload in
                let payload = sharedPayload.shortName
                add(payload: payload)
            }
        }
    }
    
    public func sensor(_ sensor: SensorType, didVisit: Location?) {
        guard eventType == .visit else {
            return
        }
        add(payload: payloadData.shortName)
    }
}

/// Event type to log in event time interval log
public enum EventTimeIntervalLogEventType : String {
    case detect
    case read
    case measure
    case share
    case sharedPeer
    case visit
}
