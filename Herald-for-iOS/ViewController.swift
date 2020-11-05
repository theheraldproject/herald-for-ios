//
//  ViewController.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import UIKit
import Herald

class ViewController: UIViewController, SensorDelegate {
    private let logger = Log(subsystem: "Herald", category: "ViewController")
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
    
    // UI header
    @IBOutlet weak var labelDevice: UILabel!
    @IBOutlet weak var labelPayload: UILabel!
    
    // UI didCount table
    @IBOutlet weak var labelDidDetectCount: UILabel!
    @IBOutlet weak var labelDidReadCount: UILabel!
    @IBOutlet weak var labelDidMeasureCount: UILabel!
    @IBOutlet weak var labelDidShareCount: UILabel!
    @IBOutlet weak var labelDidVisitCount: UILabel!
    
    // MARK:- Social mixing
    private let socialMixingScore = SocialDistance()
    private var socialMixingScoreUnit = TimeInterval(60)
    // Labels to show score over time, each label is a unit
    @IBOutlet weak var labelSocialMixingScore00: UILabel!
    @IBOutlet weak var labelSocialMixingScore01: UILabel!
    @IBOutlet weak var labelSocialMixingScore02: UILabel!
    @IBOutlet weak var labelSocialMixingScore03: UILabel!
    @IBOutlet weak var labelSocialMixingScore04: UILabel!
    @IBOutlet weak var labelSocialMixingScore05: UILabel!
    @IBOutlet weak var labelSocialMixingScore06: UILabel!
    @IBOutlet weak var labelSocialMixingScore07: UILabel!
    @IBOutlet weak var labelSocialMixingScore08: UILabel!
    @IBOutlet weak var labelSocialMixingScore09: UILabel!
    @IBOutlet weak var labelSocialMixingScore10: UILabel!
    @IBOutlet weak var labelSocialMixingScore11: UILabel!
    // Buttons to set label unit
    @IBOutlet weak var buttonSocialMixingScoreUnitH24: UIButton!
    @IBOutlet weak var buttonSocialMixingScoreUnitH12: UIButton!
    @IBOutlet weak var buttonSocialMixingScoreUnitH4: UIButton!
    @IBOutlet weak var buttonSocialMixingScoreUnitH1: UIButton!
    @IBOutlet weak var buttonSocialMixingScoreUnitM30: UIButton!
    @IBOutlet weak var buttonSocialMixingScoreUnitM15: UIButton!
    @IBOutlet weak var buttonSocialMixingScoreUnitM5: UIButton!
    @IBOutlet weak var buttonSocialMixingScoreUnitM1: UIButton!
    
    
    // UI detected payloads
    @IBOutlet weak var labelDetection: UILabel!
    @IBOutlet weak var buttonCrash: UIButton!
    @IBOutlet weak var textViewPayloads: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sensor = appDelegate.sensor
        sensor.add(delegate: self)
        sensor.add(delegate: socialMixingScore)

        dateFormatter.dateFormat = "MMdd HH:mm:ss"
        
        labelDevice.text = SensorArray.deviceDescription
        if let payloadData = (appDelegate.sensor as? SensorArray)?.payloadData {
            labelPayload.text = "PAYLOAD : \(payloadData.shortName)"
        }
        
        enableCrashButton()
    }
        
    // MARK:- Social mixing score unit buttons
    private func buttonSocialMixingScoreUnit(color: UIColor) {
        buttonSocialMixingScoreUnitH24.setTitleColor(color, for: .normal)
        buttonSocialMixingScoreUnitH12.setTitleColor(color, for: .normal)
        buttonSocialMixingScoreUnitH4.setTitleColor(color, for: .normal)
        buttonSocialMixingScoreUnitH1.setTitleColor(color, for: .normal)
        buttonSocialMixingScoreUnitM30.setTitleColor(color, for: .normal)
        buttonSocialMixingScoreUnitM15.setTitleColor(color, for: .normal)
        buttonSocialMixingScoreUnitM5.setTitleColor(color, for: .normal)
        buttonSocialMixingScoreUnitM1.setTitleColor(color, for: .normal)
    }
    @IBAction func buttonSocialMixingScoreUnitH24Action(_ sender: Any) {
        socialMixingScoreUnit = TimeInterval(60*60*24)
        buttonSocialMixingScoreUnit(color: .systemGray)
        buttonSocialMixingScoreUnitH24.setTitleColor(.systemBlue, for: .normal)
        updateSocialDistance(socialMixingScoreUnit)
    }
    @IBAction func buttonSocialMixingScoreUnitH12Action(_ sender: Any) {
        socialMixingScoreUnit = TimeInterval(60*60*12)
        buttonSocialMixingScoreUnit(color: .systemGray)
        buttonSocialMixingScoreUnitH12.setTitleColor(.systemBlue, for: .normal)
        updateSocialDistance(socialMixingScoreUnit)
    }
    @IBAction func buttonSocialMixingScoreUnitH4Action(_ sender: Any) {
        socialMixingScoreUnit = TimeInterval(60*60*4)
        buttonSocialMixingScoreUnit(color: .systemGray)
        buttonSocialMixingScoreUnitH4.setTitleColor(.systemBlue, for: .normal)
        updateSocialDistance(socialMixingScoreUnit)
    }
    @IBAction func buttonSocialMixingScoreUnitH1Action(_ sender: Any) {
        socialMixingScoreUnit = TimeInterval(60*60*1)
        buttonSocialMixingScoreUnit(color: .systemGray)
        buttonSocialMixingScoreUnitH1.setTitleColor(.systemBlue, for: .normal)
        updateSocialDistance(socialMixingScoreUnit)
    }
    @IBAction func buttonSocialMixingScoreUnitM30Action(_ sender: Any) {
        socialMixingScoreUnit = TimeInterval(60*30)
        buttonSocialMixingScoreUnit(color: .systemGray)
        buttonSocialMixingScoreUnitM30.setTitleColor(.systemBlue, for: .normal)
        updateSocialDistance(socialMixingScoreUnit)
    }
    @IBAction func buttonSocialMixingScoreUnitM15Action(_ sender: Any) {
        socialMixingScoreUnit = TimeInterval(60*15)
        buttonSocialMixingScoreUnit(color: .systemGray)
        buttonSocialMixingScoreUnitM30.setTitleColor(.systemBlue, for: .normal)
        updateSocialDistance(socialMixingScoreUnit)
    }
    @IBAction func buttonSocialMixingScoreUnitM5Action(_ sender: Any) {
        socialMixingScoreUnit = TimeInterval(60*5)
        buttonSocialMixingScoreUnit(color: .systemGray)
        buttonSocialMixingScoreUnitM30.setTitleColor(.systemBlue, for: .normal)
        updateSocialDistance(socialMixingScoreUnit)
    }
    @IBAction func buttonSocialMixingScoreUnitM1Action(_ sender: Any) {
        socialMixingScoreUnit = TimeInterval(60*1)
        buttonSocialMixingScoreUnit(color: .systemGray)
        buttonSocialMixingScoreUnitM30.setTitleColor(.systemBlue, for: .normal)
        updateSocialDistance(socialMixingScoreUnit)
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
    
    // Update detected payloads
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
    
    // Update social distance score
    private func updateSocialDistance(_ unit: TimeInterval) {
        let secondsPerUnit = Int(round(unit))
        let labels = [labelSocialMixingScore00, labelSocialMixingScore01, labelSocialMixingScore02, labelSocialMixingScore03, labelSocialMixingScore04, labelSocialMixingScore05, labelSocialMixingScore06, labelSocialMixingScore07, labelSocialMixingScore08, labelSocialMixingScore09, labelSocialMixingScore10, labelSocialMixingScore11]
        let epoch = Int(Date().timeIntervalSince1970).dividedReportingOverflow(by: secondsPerUnit).partialValue - 12
        for i in 0...11 {
            // Compute score for time slot
            let start = Date(timeIntervalSince1970: TimeInterval((epoch + i) * secondsPerUnit))
            let end = Date(timeIntervalSince1970: TimeInterval((epoch + i + 1) * secondsPerUnit))
            let score = socialMixingScore.scoreByProximity(start, end, measuredPower: -25, excludeRssiBelow: -70)
            // Present textual score
            let scoreForPresentation = Int(round(score * 100)).description
            labels[i]!.text = scoreForPresentation
            // Change color according to score
            if score < 0.1 {
                labels[i]!.backgroundColor = .systemGreen
            } else if score < 0.5 {
                labels[i]!.backgroundColor = .systemOrange
            } else {
                labels[i]!.backgroundColor = .systemRed
            }
        }
    }

    // MARK:- SensorDelegate

    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
        self.didDetect += 1
        DispatchQueue.main.async {
            self.labelDidDetectCount.text = "\(self.didDetect)"
        }
    }

    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        self.didRead += 1
        payloads[fromTarget] = didRead.shortName
        didReadPayloads[didRead.shortName] = Date()
        DispatchQueue.main.async {
            self.labelDidReadCount.text = "\(self.didRead)"
            self.updateDetection()
        }
    }

    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
        self.didShare += 1
        let time = Date()
        didShare.forEach { self.didSharePayloads[$0.shortName] = time }
        DispatchQueue.main.async {
            self.labelDidShareCount.text = "\(self.didShare)"
            self.updateDetection()
        }
    }

    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        self.didMeasure += 1;
        if let payloadShortName = payloads[fromTarget] {
            didReadPayloads[payloadShortName] = Date()
        }
        DispatchQueue.main.async {
            self.labelDidMeasureCount.text = "\(self.didMeasure)"
            self.updateDetection()
            self.updateSocialDistance(self.socialMixingScoreUnit)
        }
    }

    func sensor(_ sensor: SensorType, didVisit: Location) {
        self.didVisit += 1;
        DispatchQueue.main.async {
            self.labelDidVisitCount.text = "\(self.didVisit)"
        }
    }
}

