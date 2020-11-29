//
//  StatisticsDidReadLog.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// CSV log of didRead calls for post event analysis and visualisation
class StatisticsDidReadLog: NSObject, SensorDelegate {
    private let textFile: TextFile
    private let payloadData: PayloadData
    private var payloadToTime: [String:Date] = [:]
    private var payloadToSample: [String:Sample] = [:]
    
    init(filename: String, payloadData: PayloadData) {
        textFile = TextFile(filename: filename)
        self.payloadData = payloadData
    }
    
    private func csv(_ value: String) -> String {
        return TextFile.csv(value)
    }
    
    private func add(payload: String) {
        guard let time = payloadToTime[payload], let sample = payloadToSample[payload] else {
            payloadToTime[payload] = Date()
            payloadToSample[payload] = Sample()
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
        textFile.overwrite(content)
    }


    // MARK:- SensorDelegate
    
    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        add(payload: didRead.shortName)
    }
    
    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
        didShare.forEach() { payloadData in
            add(payload: payloadData.shortName)
        }
    }
}
