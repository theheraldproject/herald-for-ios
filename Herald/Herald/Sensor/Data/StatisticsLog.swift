//
//  StatisticsLog.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// CSV contact log for post event analysis and visualisation
public class StatisticsLog: SensorDelegateLogger {
    private let payloadData: PayloadData
    private var identifierToPayload: [TargetIdentifier:String] = [:]
    private var payloadToTime: [String:Date] = [:]
    private var payloadToSample: [String:SampleStatistics] = [:]
    
    public init(filename: String, payloadData: PayloadData) {
        self.payloadData = payloadData
        super.init(filename: filename)
    }
    
    private func add(identifier: TargetIdentifier) {
        guard let payload = identifierToPayload[identifier] else {
            return
        }
        add(payload: payload)
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
        var content = "payload,count,mean,sd,min,max\n"
        var payloadList: [String] = []
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
            content.append("\(csv(payload)),\(sample.count),\(mean),\(sd),\(min),\(max)\n")
        }
        overwrite(content)
    }


    // MARK:- SensorDelegate
    
    public override func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        identifierToPayload[fromTarget] = didRead.shortName
        add(identifier: fromTarget)
    }
    
    public override func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        add(identifier: fromTarget)
    }
    
    public override func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
        didShare.forEach() { payloadData in
            add(payload: payloadData.shortName)
        }
    }
}
