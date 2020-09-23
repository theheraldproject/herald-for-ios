//
//  ViewController.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import UIKit
import Herald

class ViewController: UIViewController, SensorDelegate {
    private let logger = Log(subsystem: "Squire", category: "ViewController")
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var sensor: Sensor!
    private let dateFormatter = DateFormatter()
    private let payloadPrefixLength = 6;
    private var didDetect = 0
    private var didRead = 0
    private var didMeasure = 0
    private var didShare = 0
    private var didVisit = 0
    private var payloads: [TargetIdentifier:String] = [:]
    private var didReadPayloads: [String:Date] = [:]
    private var didSharePayloads: [String:Date] = [:]

    @IBOutlet weak var labelDevice: UILabel!
    @IBOutlet weak var labelPayload: UILabel!
    @IBOutlet weak var labelDidDetect: UILabel!
    @IBOutlet weak var labelDidRead: UILabel!
    @IBOutlet weak var labelDidMeasure: UILabel!
    @IBOutlet weak var labelDidShare: UILabel!
    @IBOutlet weak var labelDidVisit: UILabel!
    @IBOutlet weak var labelDetection: UILabel!
    @IBOutlet weak var buttonCrash: UIButton!
    @IBOutlet weak var textViewPayloads: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sensor = appDelegate.sensor
        sensor.add(delegate: self)
        
        dateFormatter.dateFormat = "MMdd HH:mm:ss"
        
        labelDevice.text = SensorArray.deviceDescription
        if let payloadData = (appDelegate.sensor as? SensorArray)?.payloadData {
            labelPayload.text = "PAYLOAD : \(payloadData.shortName)"
        }
        
        enableCrashButton()
    }
    
    private func enableCrashButton() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(simulateCrashInTen))
        tapGesture.numberOfTapsRequired = 3
        buttonCrash.addGestureRecognizer(tapGesture)
    }
    
    @objc func simulateCrashInTen() {
        simulateCrash(after: 10)
        buttonCrash.isUserInteractionEnabled = false
        buttonCrash.setTitle("Crashing in 10 seconds", for: .normal)
    }
    
    func simulateCrash(after: Double) {
        logger.info("simulateCrash (after=\(after))")
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + after) {
            self.logger.fault("simulateCrash now")
            // CRASH
            if ([0][1] == 1) {
                exit(0)
            }
            exit(1)
        }
    }

    
    private func timestamp() -> String {
        let timestamp = dateFormatter.string(from: Date())
        return timestamp
    }
    
    private func updateDetection() {
        var payloadShortNames: [String:String] = [:]
        var payloadLastSeenDates: [String:Date] = [:]
        didReadPayloads.forEach() { payloadShortName, date in
            payloadShortNames[payloadShortName] = "read"
            payloadLastSeenDates[payloadShortName] = didReadPayloads[payloadShortName]
        }
        didSharePayloads.forEach() { payloadShortName, date in
            if payloadShortNames[payloadShortName] == nil {
                payloadShortNames[payloadShortName] = "shared"
            } else {
                payloadShortNames[payloadShortName] = "read,shared"
            }
            if let didSharePayloadDate = didSharePayloads[payloadShortName], let didReadPayloadDate = didReadPayloads[payloadShortName], didSharePayloadDate > didReadPayloadDate {
                payloadLastSeenDates[payloadShortName] = didSharePayloadDate
            }
        }
        var payloadShortNameList: [String] = []
        payloadShortNames.keys.forEach() { payloadShortName in
            if let method = payloadShortNames[payloadShortName], let lastSeenDate = payloadLastSeenDates[payloadShortName] {
                payloadShortNameList.append("\(payloadShortName) [\(method)] (\(dateFormatter.string(from: lastSeenDate)))")
            }
        }
        payloadShortNameList.sort()
        textViewPayloads.text = payloadShortNameList.joined(separator: "\n")
        labelDetection.text = "DETECTION (\(payloadShortNameList.count))"
    }

    // MARK:- SensorDelegate

    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
        self.didDetect += 1
        DispatchQueue.main.async {
            self.labelDidDetect.text = "didDetect: \(self.didDetect) (\(self.timestamp()))"
        }
    }

    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        self.didRead += 1
        payloads[fromTarget] = didRead.shortName
        didReadPayloads[didRead.shortName] = Date()
        DispatchQueue.main.async {
            self.labelDidRead.text = "didRead: \(self.didRead) (\(self.timestamp()))"
            self.updateDetection()
        }
    }

    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
        self.didShare += 1
        let time = Date()
        didShare.forEach { self.didSharePayloads[$0.shortName] = time }
        DispatchQueue.main.async {
            self.labelDidShare.text = "didShare: \(self.didShare) (\(self.timestamp()))"
            self.updateDetection()
        }
    }

    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        self.didMeasure += 1;
        if let payloadShortName = payloads[fromTarget] {
            didReadPayloads[payloadShortName] = Date()
        }
        DispatchQueue.main.async {
            self.labelDidMeasure.text = "didMeasure: \(self.didMeasure) (\(self.timestamp()))"
            self.updateDetection()
        }
    }

    func sensor(_ sensor: SensorType, didVisit: Location) {
        self.didVisit += 1;
        DispatchQueue.main.async {
            self.labelDidVisit.text = "didVisit: \(self.didVisit) (\(self.timestamp()))"
        }
    }
}

