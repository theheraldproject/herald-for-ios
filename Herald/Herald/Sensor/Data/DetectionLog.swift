//
//  DetectionLog.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import UIKit

/// CSV contact log for post event analysis and visualisation
public class DetectionLog: SensorDelegateLogger {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Data.DetectionLog")
    private let payloadData: PayloadData
    private let deviceName = UIDevice.current.name
    private let deviceOS = UIDevice.current.systemVersion
    private var payloads: Set<String> = []
    private let queue = DispatchQueue(label: "Sensor.Data.DetectionLog.Queue")
    private let payloadDataFormatter: PayloadDataFormatter

    public init(filename: String, payloadData: PayloadData, payloadDataFormatter: PayloadDataFormatter = ConcretePayloadDataFormatter()) {
        self.payloadData = payloadData
        self.payloadDataFormatter = payloadDataFormatter
        super.init(filename: filename)
        write()
    }
    
    private func write() {
        var content = "\(csv(deviceName)),iOS,\(csv(deviceOS)),\(csv(payloadDataFormatter.shortFormat(payloadData)))"
        var payloadList: [String] = []
        payloads.forEach() { payload in
            guard payload != payloadDataFormatter.shortFormat(payloadData) else {
                return
            }
            payloadList.append(payload)
        }
        payloadList.sort()
        payloadList.forEach() { payload in
            content.append(",")
            content.append(csv(payload))
        }
        logger.debug("write (content=\(content))")
        content.append("\n")
        overwrite(content)
    }
    
    // MARK:- SensorDelegate
    
    public override func sensor(_ sensor: SensorType, didUpdateState: SensorState) {
        queue.async {
            self.logger.debug("didUpdateState (state=\(didUpdateState)")
            self.write()
        }
    }
    
    public override func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        queue.async {
            if self.payloads.insert(self.payloadDataFormatter.shortFormat(didRead)).inserted {
                self.logger.debug("didRead (payload=\(self.payloadDataFormatter.shortFormat(didRead)))")
                self.write()
            }
        }
    }
    
    public override func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
        didShare.forEach() { payloadData in
            queue.async {
                if self.payloads.insert(self.payloadDataFormatter.shortFormat(payloadData)).inserted {
                    self.logger.debug("didShare (payload=\(self.payloadDataFormatter.shortFormat(payloadData)))")
                    self.write()
                }
            }
        }
    }
}
