//
//  ViewController.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: MIT
//

import UIKit
import Herald

class ViewController: UIViewController, SensorDelegate, UITableViewDataSource, UITableViewDelegate {
    private let logger = Log(subsystem: "Herald", category: "ViewController")
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var sensor: Sensor!
    private let dateFormatter = DateFormatter()
    private let dateFormatterTime = DateFormatter()

    // UI header
    @IBOutlet weak var labelDevice: UILabel!
    @IBOutlet weak var labelPayload: UILabel!
    
    // MARK:- Events

    private var didDetect = 0
    private var didRead = 0
    private var didMeasure = 0
    private var didShare = 0
    private var didReceive = 0
    // Labels to show counts
    @IBOutlet weak var labelDidDetectCount: UILabel!
    @IBOutlet weak var labelDidReadCount: UILabel!
    @IBOutlet weak var labelDidMeasureCount: UILabel!
    @IBOutlet weak var labelDidShareCount: UILabel!
    @IBOutlet weak var labelDidReceiveCount: UILabel!
    
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
    
    // MARK:- Detected payloads
    
    private var targetIdentifiers: [TargetIdentifier:PayloadData] = [:]
    private var payloads: [PayloadData:Target] = [:]
    private var targets: [Target] = []
    @IBOutlet weak var tableViewTargets: UITableView!
    
    // MARK:- Crash app
    
    @IBOutlet weak var buttonCrash: UIButton!
    
    // MARK:- UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        sensor = appDelegate.sensor
        sensor.add(delegate: self)
        sensor.add(delegate: socialMixingScore)
        
        dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
        dateFormatterTime.dateFormat = "HH:mm:ss"

        labelDevice.text = SensorArray.deviceDescription
        if let payloadData = appDelegate.sensor?.payloadData {
            labelPayload.text = "PAYLOAD : \(payloadData.shortName)"
        }
        tableViewTargets.dataSource = self
        tableViewTargets.delegate = self
        enableCrashButton()
    }
        
    // MARK:- Social mixing score
    
    private func socialMixingScoreUnit(_ setTo: UIButton, active: UIColor = .systemBlue, inactive: UIColor = .systemGray) {
        var mapping: [UIButton:TimeInterval] = [:]
        mapping[buttonSocialMixingScoreUnitH24] = TimeInterval(24 * 60 * 60)
        mapping[buttonSocialMixingScoreUnitH12] = TimeInterval(12 * 60 * 60)
        mapping[buttonSocialMixingScoreUnitH4] = TimeInterval(4 * 60 * 60)
        mapping[buttonSocialMixingScoreUnitH1] = TimeInterval(1 * 60 * 60)
        mapping[buttonSocialMixingScoreUnitM30] = TimeInterval(30 * 60)
        mapping[buttonSocialMixingScoreUnitM15] = TimeInterval(15 * 60)
        mapping[buttonSocialMixingScoreUnitM5] = TimeInterval(5 * 60)
        mapping[buttonSocialMixingScoreUnitM1] = TimeInterval(1 * 60)
        mapping.forEach() { key, value in
            if key == setTo {
                key.setTitleColor(active, for: .normal)
                socialMixingScoreUnit = value
            } else {
                key.setTitleColor(inactive, for: .normal)
            }
        }
        updateSocialDistance(socialMixingScoreUnit)
    }
    @IBAction func buttonSocialMixingScoreUnitH24Action(_ sender: Any) {
        socialMixingScoreUnit(buttonSocialMixingScoreUnitH24)
    }
    @IBAction func buttonSocialMixingScoreUnitH12Action(_ sender: Any) {
        socialMixingScoreUnit(buttonSocialMixingScoreUnitH12)
    }
    @IBAction func buttonSocialMixingScoreUnitH4Action(_ sender: Any) {
        socialMixingScoreUnit(buttonSocialMixingScoreUnitH4)
    }
    @IBAction func buttonSocialMixingScoreUnitH1Action(_ sender: Any) {
        socialMixingScoreUnit(buttonSocialMixingScoreUnitH1)
    }
    @IBAction func buttonSocialMixingScoreUnitM30Action(_ sender: Any) {
        socialMixingScoreUnit(buttonSocialMixingScoreUnitM30)
    }
    @IBAction func buttonSocialMixingScoreUnitM15Action(_ sender: Any) {
        socialMixingScoreUnit(buttonSocialMixingScoreUnitM15)
    }
    @IBAction func buttonSocialMixingScoreUnitM5Action(_ sender: Any) {
        socialMixingScoreUnit(buttonSocialMixingScoreUnitM5)
    }
    @IBAction func buttonSocialMixingScoreUnitM1Action(_ sender: Any) {
        socialMixingScoreUnit(buttonSocialMixingScoreUnitM1)
    }
    
    // Update social distance score
    private func updateSocialDistance(_ unit: TimeInterval) {
        let secondsPerUnit = Int(round(unit))
        let labels = [labelSocialMixingScore00, labelSocialMixingScore01, labelSocialMixingScore02, labelSocialMixingScore03, labelSocialMixingScore04, labelSocialMixingScore05, labelSocialMixingScore06, labelSocialMixingScore07, labelSocialMixingScore08, labelSocialMixingScore09, labelSocialMixingScore10, labelSocialMixingScore11]
        let epoch = Int(Date().timeIntervalSince1970).dividedReportingOverflow(by: secondsPerUnit).partialValue - 11
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
    
    // Update targets table
    private func updateTargets() {
        // De-duplicate targets based on short name and last updated at time stamp
        var shortNames: [String:Target] = [:]
        payloads.forEach() { payload, target in
            let shortName = payload.shortName
            guard let duplicate = shortNames[shortName] else {
                shortNames[shortName] = target
                return
            }
            if duplicate.lastUpdatedAt < target.lastUpdatedAt {
                shortNames[shortName] = target
            }
        }
        // Get target list in alphabetical order
        targets = shortNames.values.sorted(by: { $0.payloadData.shortName < $1.payloadData.shortName })
        tableViewTargets.reloadData()
    }

    // MARK:- Crash app
    
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

    // MARK:- SensorDelegate

    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
        self.didDetect += 1
        DispatchQueue.main.async {
            self.labelDidDetectCount.text = "\(self.didDetect)"
        }
    }

    func sensor(_ sensor: SensorType, didRead: PayloadData, fromTarget: TargetIdentifier) {
        self.didRead += 1
        targetIdentifiers[fromTarget] = didRead
        if let target = payloads[didRead] {
            target.didRead = Date()
        } else {
            payloads[didRead] = Target(targetIdentifier: fromTarget, payloadData: didRead)
        }
        DispatchQueue.main.async {
            self.labelDidReadCount.text = "\(self.didRead)"
            self.updateTargets()
        }
    }

    func sensor(_ sensor: SensorType, didShare: [PayloadData], fromTarget: TargetIdentifier) {
        self.didShare += 1
        didShare.forEach { didRead in
            targetIdentifiers[fromTarget] = didRead
            if let target = payloads[didRead] {
                target.didRead = Date()
            } else {
                payloads[didRead] = Target(targetIdentifier: fromTarget, payloadData: didRead)
            }
        }
        DispatchQueue.main.async {
            self.labelDidShareCount.text = "\(self.didShare)"
            self.updateTargets()
        }
    }

    func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        self.didMeasure += 1
        if let didRead = targetIdentifiers[fromTarget], let target = payloads[didRead] {
            target.targetIdentifier = fromTarget
            target.proximity = didMeasure
        }
        DispatchQueue.main.async {
            self.labelDidMeasureCount.text = "\(self.didMeasure)"
            self.updateTargets()
            self.updateSocialDistance(self.socialMixingScoreUnit)
        }
    }

    func sensor(_ sensor: SensorType, didReceive: Data, fromTarget: TargetIdentifier) {
        self.didReceive += 1
        let didRead = PayloadData(didReceive)
        if let target = payloads[didRead] {
            targetIdentifiers[fromTarget] = didRead
            target.targetIdentifier = fromTarget
            target.received = didReceive
        }
        DispatchQueue.main.async {
            self.labelDidReceiveCount.text = "\(self.didReceive)"
            self.updateTargets()
        }
    }
    
    // MARK:- UITableViewDataSource
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "DETECTION (\(targets.count))"
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return targets.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "targetIdentifier", for: indexPath)
        let target = targets[indexPath.row]
        let method = "read" + (target.didShare == nil ? "" : ",share")
        var didReadTimeInterval: String? = nil
        if let mean = target.didReadTimeInterval.mean {
            didReadTimeInterval = String(format: "%.1f", mean)
        }
        var didMeasureTimeInterval: String? = nil
        if let mean = target.didMeasureTimeInterval.mean {
            didMeasureTimeInterval = String(format: "%.1f", mean)
        }
        var timeIntervals: String? = nil
        if let r = didReadTimeInterval, let m = didMeasureTimeInterval {
            timeIntervals = " (R:\(r)s,M:\(m)s)"
        }
        let didReceive = (target.didReceive == nil ? "" : " (receive \(dateFormatterTime.string(from: target.didReceive!)))")
        cell.textLabel?.text = "\(target.payloadData.shortName) [\(method)]\(timeIntervals ?? "")"
        cell.detailTextLabel?.text = "\(dateFormatter.string(from: target.lastUpdatedAt))\(didReceive)"
        return cell
    }

    // MARK:- UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let target = targets[indexPath.row]
        guard let sensor = appDelegate.sensor, let payloadData = appDelegate.sensor?.payloadData else {
            return
        }
        let result = sensor.immediateSend(data: payloadData, target.targetIdentifier)
        logger.debug("immediateSend (from=\(payloadData.shortName),to=\(target.payloadData.shortName),success=\(result))")
    }
}

/// Detected target
private class Target {
    var targetIdentifier: TargetIdentifier
    var payloadData: PayloadData
    var lastUpdatedAt: Date
    var proximity: Proximity? {
        didSet {
            let date = Date()
            if let lastUpdate = didMeasure {
                didMeasureTimeInterval.add(date.timeIntervalSince(lastUpdate))
            }
            lastUpdatedAt = date
            didMeasure = lastUpdatedAt
        }}
    var received: Data? {
        didSet {
            lastUpdatedAt = Date()
            didReceive = lastUpdatedAt
        }}
    var didRead: Date {
        willSet(date) {
            didReadTimeInterval.add(date.timeIntervalSince(didRead))
        }
        didSet {
            lastUpdatedAt = didRead
        }}
    let didReadTimeInterval = Sample()
    var didMeasure: Date?
    let didMeasureTimeInterval = Sample()
    var didShare: Date? {
        didSet {
            lastUpdatedAt = didRead
        }}
    var didReceive: Date?
    init(targetIdentifier: TargetIdentifier, payloadData: PayloadData) {
        self.targetIdentifier = targetIdentifier
        self.payloadData = payloadData
        didRead = Date()
        lastUpdatedAt = didRead
    }
}
