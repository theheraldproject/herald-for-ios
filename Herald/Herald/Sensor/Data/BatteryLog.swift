//
//  BatteryLog.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import UIKit
import NotificationCenter
import os

/// Battery log for monitoring battery level over time
public class BatteryLog: SensorDelegateLogger {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "BatteryLog")
    private let updateInterval = TimeInterval(30)

    public override init(filename: String) {
        super.init(filename: filename)
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(self, selector: #selector(batteryLevelDidChange), name: UIDevice.batteryLevelDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(batteryStateDidChange), name: UIDevice.batteryStateDidChangeNotification, object: nil)
        let _ = Timer.scheduledTimer(timeInterval: updateInterval, target: self, selector: #selector(update), userInfo: nil, repeats: true)
    }
    
    private func writeHeader() {
        if empty() {
            write("time,source,level")
        }
    }
    
    @objc func update() {
        let powerSource = (UIDevice.current.batteryState == .unplugged ? "battery" : "external")
        let batteryLevel = Float(UIDevice.current.batteryLevel * 100).description
        write(timestamp() + "," + powerSource + "," + batteryLevel)
        logger.debug("update (powerSource=\(powerSource),batteryLevel=\(batteryLevel))");
    }
    
    @objc func batteryLevelDidChange(_ sender: NotificationCenter) {
        update()
    }
    
    @objc func batteryStateDidChange(_ sender: NotificationCenter) {
        update()
    }
}
