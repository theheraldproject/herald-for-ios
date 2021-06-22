//
//  ViewController.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import UIKit
import Herald

class PhoneModeViewController: UIViewController, SensorDelegate, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, VenueDiaryDelegate, Resettable {
    
    private let logger = Log(subsystem: "Herald", category: "ViewController")
    private let appDelegate = UIApplication.shared.delegate as! AppDelegate
    private var sensor: SensorArray!
    private var foreground: Bool = true
    private let dateFormatter = DateFormatter()
    private let dateFormatterTime = DateFormatter()

    // UI header
    @IBOutlet weak var labelDevice: UILabel!
    @IBOutlet weak var labelPayload: UILabel!
    @IBOutlet weak var switchSensorOnOff: UISwitch!
    
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
    
    // MARK:- Venue Diary
    var venueDiary: VenueDiary?
    
    // MARK:- Social mixing
    private let socialMixingScore = SocialDistance(filename: "socialDistance.csv")
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
    // Immediate send elements
    @IBOutlet weak var textMessageToSend: UITextField!
    @IBOutlet weak var buttonMessageSend: UIButton!
    @IBOutlet weak var labelMessageReceived: UILabel!
    
    // MARK:- Distance estimation
    let analysisProviderManager = AnalysisProviderManager()
    let analysisDelegateManager = AnalysisDelegateManager()
    var analysisRunner: AnalysisRunner!
    let smoothedLinearModel = SelfCalibratedModel(
        min: Distance(0), mean: Distance(3.7),
        withinMin: .minute * 5, withinMean: .hour * 8,
        textFile: TextFile(filename: "rssi_histogram.csv"))
    let analysisDelegate = AnalysisDelegate(Distance.self, listSize: 5)
    
    // MARK:- Mobility
    private let mobility = Mobility(filename: "mobility.csv")
    
    // MARK:- Detected payloads
    private var targetIdentifiers: [TargetIdentifier:PayloadData] = [:]
    private var payloads: [PayloadData:Target] = [:]
    private var targets: [Target] = []
    @IBOutlet weak var tableViewTargets: UITableView!
    
    // MARK:- Crash app
    
    @IBOutlet weak var buttonCrash: UIButton!
    
    // MARK:- Resettable
    
    func reset() {
        didDetect = 0
        didRead = 0
        didMeasure = 0
        didShare = 0
        didReceive = 0
        
        targetIdentifiers.removeAll()
        payloads.removeAll()
        targets.removeAll()
        
        socialMixingScore.reset()
        smoothedLinearModel.reset()
        
        DispatchQueue.main.async {
            self.updateCounts()
            self.updateTargets()
            self.updateSocialDistance(self.socialMixingScoreUnit)
        }
    }
    
    // MARK:- UIViewController
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Now enable phone mode - initialises SensorArray
        appDelegate.startPhone()
        
        sensor = appDelegate.sensor
        sensor.add(delegate: self)
        sensor.add(delegate: socialMixingScore)
        sensor.add(delegate: mobility)
        
        // Added diary logger
        if nil == venueDiary {
            venueDiary = VenueDiary()
        }
        venueDiary!.add(self)
        sensor.add(delegate: venueDiary!)
        
        dateFormatter.dateFormat = "YYYY-MM-dd HH:mm:ss"
        dateFormatterTime.dateFormat = "HH:mm:ss"
        
        textMessageToSend.delegate = self
        textMessageToSend.text = "ping"

        labelDevice.text = SensorArray.deviceDescription
        if let payloadData = appDelegate.sensor?.payloadData {
            labelPayload.text = "PAYLOAD : \(payloadData.shortName)"
        }
        tableViewTargets.dataSource = self
        tableViewTargets.delegate = self
        enableCrashButton()
        
        // Detect app moving to foreground and background
        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        
        // Distance estimation
        analysisProviderManager.add(SmoothedLinearModelAnalyser(interval: 1, smoothingWindow: 60, model: smoothedLinearModel))
        analysisDelegateManager.add(analysisDelegate)
        analysisRunner = AnalysisRunner(analysisProviderManager, analysisDelegateManager, defaultListSize: 1200)
        
        // Enable remote reset of user interface component in automated tests
        appDelegate.automatedTestClient?.add(self)
    }

    @objc func willEnterForeground() {
        foreground = true
        logger.debug("app (state=foreground)")
        updateCounts()
        updateTargets()
        updateSocialDistance(socialMixingScoreUnit)
    }
    
    @objc func didEnterBackground() {
        foreground = false
        logger.debug("app (state=background)")
    }
    
    @IBAction func sensorOnOffSwitchAction(_ sender: Any) {
        guard let sensorOnOffSwitch = sender as? UISwitch else {
            return
        }
        logger.debug("sensorOnOffSwitchAction (isOn=\(sensorOnOffSwitch.isOn))")
        if sensorOnOffSwitch.isOn {
            sensor.start()
        } else {
            sensor.stop()
        }
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
    
    /// Update counts
    private func updateCounts() {
        DispatchQueue.main.async {
            self.labelDidDetectCount.text = "\(self.didDetect)"
            self.labelDidReadCount.text = "\(self.didRead)"
            self.labelDidMeasureCount.text = "\(self.didMeasure)"
            self.labelDidShareCount.text = "\(self.didShare)"
            self.labelDidReceiveCount.text = "\(self.didReceive)"
        }
    }
    
    /// Update targets table
    private func updateTargets() {
        DispatchQueue.main.async {
            // De-duplicate targets based on short name and last updated at time stamp
            var shortNames: [String:Target] = [:]
            self.payloads.forEach() { payload, target in
                let shortName = payload.shortName
                guard let duplicate = shortNames[shortName] else {
                    shortNames[shortName] = target
                    return
                }
                if duplicate.lastUpdatedAt < target.lastUpdatedAt {
                    shortNames[shortName] = target
                }
            }
            // Get target distance from analysis delegate
            shortNames.values.forEach({ target in
                let sampledID = SampledID(target.payloadData.data)
                let sampleList = self.analysisDelegate.samples(sampledID: sampledID)
                guard let value = sampleList.filter(Since(recent: 90)).toView().latestValue(),
                      let distance = value as? Distance else {
                    return
                }
                target.distance = distance
            })
            // Get target list in alphabetical order
            self.targets = shortNames.values.sorted(by: { $0.payloadData.shortName < $1.payloadData.shortName })
            self.tableViewTargets.reloadData()
        }
    }
    
    // MARK:- Immediate Send
    @IBAction func didClickSend(_ sender: UIButton) {
        guard let text = textMessageToSend.text else {
            return
        }
        if text.count == 0 {
            return
        }
        guard let sensor = sensor else {
            return
        }
        let ok = sensor.immediateSendAll(data: text.data(using: .utf8)!)
        if !ok {
            labelMessageReceived.text = "Failed to send"
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
        return false
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
    
    // MARK:- VenueDiaryDelegate
    func venue(_ didUpdate: VenueDiaryEvent) {
        // highlight item as Venue in the UI
        logger.debug("venue didUpdate")
    }

    // MARK:- SensorDelegate

    func sensor(_ sensor: SensorType, didDetect: TargetIdentifier) {
        self.didDetect += 1
        guard foreground else {
            return
        }
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
        guard foreground else {
            return
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
        guard foreground else {
            return
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
            // Supply raw RSSI measurements to distance estimation algorithm
            if didMeasure.unit == ProximityMeasurementUnit.RSSI {
                let sampledID = SampledID(didRead.data)
                analysisRunner.newSample(sampled: sampledID, item: Sample(value: RSSI(didMeasure.value)))
                // Analysis runner doesn't need to be executed as often as updates
                // but the overhead is minimal as the demonstration distance analyser
                // will only perform calculations and offer updates at fixed intervals
                analysisRunner.run()
            }
        }
        guard foreground else {
            return
        }
        DispatchQueue.main.async {
            self.labelDidMeasureCount.text = "\(self.didMeasure)"
            self.updateTargets()
            self.updateSocialDistance(self.socialMixingScoreUnit)
        }
    }

    // Immediate send data (text in demo app), NOT payload data
    func sensor(_ sensor: SensorType, didReceive: Data, fromTarget: TargetIdentifier) {
        self.didReceive += 1
        let didRead = String(bytes: didReceive, encoding: .utf8)
        DispatchQueue.main.async {
            guard let read = didRead else {
                self.labelMessageReceived.text = "<garbled>"
                return
            }
            self.labelMessageReceived.text = read
            // The following is for an easy demo flow
            if read == "ping" {
                self.textMessageToSend.text = "pong"
            } else if read == "pong" {
                self.textMessageToSend.text = "ping"
            }
        }
        guard foreground else {
            return
        }
        DispatchQueue.main.async {
            self.labelDidReceiveCount.text = "\(self.didReceive)"
            self.updateTargets()
        }
    }
    
    func sensor(_ sensor: SensorType, didUpdateState: SensorState) {
        guard sensor == .ARRAY else {
            return
        }
        DispatchQueue.main.async {
            self.switchSensorOnOff.isOn = didUpdateState == .on
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
        // Event time interval statistics
        var statistics = "R"
        if let mean = target.didReadTimeInterval.mean {
            statistics = "\(statistics)=\(String(format: "%.1f", mean))s"
        }
        if let mean = target.didMeasureTimeInterval.mean {
            statistics = "\(statistics),M=\(String(format: "%.1f", mean))s"
        }
        if let mean = target.didShareTimeInterval.mean {
            statistics = "\(statistics),S=\(String(format: "%.1f", mean))s"
        }
        // Distance
        var distance = ""
        if let distanceValue = target.distance {
            distance = String(format: "%.1f", distanceValue.value) + "m"
        }
//        // Immediate send : Superceded in full UI
//        let didReceive = (target.didReceive == nil ? "" : " (receive \(dateFormatterTime.string(from: target.didReceive!)))")
        // Venue
        let shortName = target.payloadData.shortName
        var labelText = "\(shortName)"
        if let legacyPayloadData = target.payloadData as? LegacyPayloadData {
            labelText += ":"
            labelText += String(legacyPayloadData.protocolName.rawValue.prefix(1))
        }
        if !distance.isEmpty {
            labelText += " ~ "
            labelText += distance
        }
        venueDiary?.listRecordableEvents().forEach({ (evt) in
            self.logger.debug("listRecordableEvents item")
            guard let eventPayload = evt.payload else {
                return
            }
            if eventPayload.shortName == shortName {
                labelText += " (Venue)"
                // TODO set text to venue name, if provided
                // TODO include area of venue on test UI too
            } else {
                self.logger.debug("listRecordableEvents  - shortNames don't match: \(shortName) vs. \(eventPayload.shortName)")
            }
        })
        cell.textLabel?.text = labelText
        cell.detailTextLabel?.text = "\(dateFormatter.string(from: target.lastUpdatedAt)) [\(statistics)]"
        return cell
    }

    // MARK:- UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let target = targets[indexPath.row]
        let mainStoryboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        if let viewController = mainStoryboard.instantiateViewController(withIdentifier: "targetvc") as? UIViewController {
            self.present(viewController, animated: true, completion: {
                self.logger.debug("completion callback - phone")
                //viewController.presentationController?.delegate = self
                if let tdvc = viewController as? TargetDetailsViewController {
                    tdvc.display(target.targetIdentifier, payload: target.payloadData)
                }
            })
        }
//        guard let sensor = appDelegate.sensor, let payloadData = appDelegate.sensor?.payloadData else {
//            return
//        }
//        let result = sensor.immediateSend(data: payloadData, target.targetIdentifier)
//        logger.debug("immediateSend (from=\(payloadData.shortName),to=\(target.payloadData.shortName),success=\(result))")
    }
    
    @IBAction func showVenueDiary(_ sender: UIButton) {
        let mainStoryboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        if let viewController = mainStoryboard.instantiateViewController(withIdentifier: "venuediaryvc") as? UIViewController {
            self.present(viewController, animated: true, completion: {
                self.logger.debug("completion callback - venue diary")
                if let vdvc = viewController as? VenueDiaryViewController {
                    self.logger.debug(" - Got VenueDiaryViewController")
                    vdvc.setDiary(self.venueDiary!)
                }
            })
        }
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
    var distance: Distance?
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
    let didReadTimeInterval = SampleStatistics()
    var didMeasure: Date?
    let didMeasureTimeInterval = SampleStatistics()
    var didShare: Date? {
        willSet(date) {
            if let date = date, let didShare = didShare {
                didShareTimeInterval.add(date.timeIntervalSince(didShare))
            }
        }
        didSet {
            if let didShare = didShare {
                lastUpdatedAt = didShare
            }
        }}
    let didShareTimeInterval = SampleStatistics()
    var didReceive: Date?
    init(targetIdentifier: TargetIdentifier, payloadData: PayloadData) {
        self.targetIdentifier = targetIdentifier
        self.payloadData = payloadData
        didRead = Date()
        lastUpdatedAt = didRead
    }
}
