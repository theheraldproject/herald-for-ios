//
//  ViewController.swift
//  
//
//  Created  on 24/07/2020.
//  Copyright © 2020 . All rights reserved.
//

import UIKit
//import os

class ViewController: UIViewController, SensorDelegate {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "ViewController")
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var sensor: Sensor!
    private let dateFormatter = DateFormatter()
    private let payloadPrefixLength = 6;
    private var didDetect = 0
    private var didRead = 0
    private var didMeasure = 0
    private var didShare = 0
    private var didVisit = 0
    private var didReadPayloads: Set<String> = []
    private var didSharePayloads: Set<String> = []

    @IBOutlet weak var labelDevice: UILabel!
    @IBOutlet weak var labelPayload: UILabel!
    @IBOutlet weak var labelDidDetect: UILabel!
    @IBOutlet weak var labelDidRead: UILabel!
    @IBOutlet weak var labelDidMeasure: UILabel!
    @IBOutlet weak var labelDidShare: UILabel!
    @IBOutlet weak var labelDidVisit: UILabel!
    @IBOutlet weak var labelDetection: UILabel!
    @IBOutlet weak var labelPayloads: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sensor = appDelegate.sensor
        sensor.add(delegate: self)
        
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        labelDevice.text = SensorArray.deviceDescription
        if let payloadPrefix = (appDelegate.sensor as? SensorArray)?.payloadPrefix {
            labelPayload.text = "PAYLOAD : \(payloadPrefix)"
        }
    }
    
    private func timestamp() -> String {
        let timestamp = dateFormatter.string(from: Date())
        return timestamp
    }
    
    private func updateDetection() {
        var payloadPrefixes: [String:String] = [:]
        didSharePayloads.forEach() { payload in
            let payloadPrefix = String(payload.prefix(payloadPrefixLength))
            payloadPrefixes[payloadPrefix] = "(shared)"
        }
        didReadPayloads.forEach() { payload in
            let payloadPrefix = String(payload.prefix(payloadPrefixLength))
            payloadPrefixes[payloadPrefix] = "(read)"
        }
        var payloadPrefixesList: [String] = []
        payloadPrefixes.keys.forEach() { payloadPrefix in
            if let method = payloadPrefixes[payloadPrefix] {
                payloadPrefixesList.append("\(payloadPrefix) \(method)")
            }
        }
        payloadPrefixesList.sort()
        labelPayloads.text = payloadPrefixesList.joined(separator: "\n")
    }

    // MARK:- SensorDelegate

    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
        self.didDetect += 1
        DispatchQueue.main.async {
            self.labelDidDetect.text = "didDetect : \(self.didDetect) (\(self.timestamp()))"
        }
    }

    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        self.didRead += 1
        self.didReadPayloads.insert(didRead.base64EncodedString())
        DispatchQueue.main.async {
            self.labelDidRead.text = "didRead : \(self.didRead) (\(self.timestamp()))"
            self.updateDetection()
        }
    }

    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
        self.didShare += 1
        didShare.forEach { self.didSharePayloads.insert($0.base64EncodedString()) }
        DispatchQueue.main.async {
            self.labelDidShare.text = "didShare : \(self.didShare) (\(self.timestamp()))"
            self.updateDetection()
        }
    }

    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        self.didMeasure += 1;
        DispatchQueue.main.async {
            self.labelDidMeasure.text = "didMeasure : \(self.didMeasure) (\(self.timestamp()))"
        }
    }

    func sensor(_ sensor: SensorType, didVisit: Location) {
        self.didVisit += 1;
        DispatchQueue.main.async {
            self.labelDidVisit.text = "didVisit : \(self.didVisit) (\(self.timestamp()))"
        }
    }
}

