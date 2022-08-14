//
//  SmoothedLinearModel.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Distance model based on cable car experiment data collected on test rig 2
/// - Experiment data shows constructive and destructive wave interference have significant
///   impact on RSSI measurements at short range (0 - 3 metres).
/// - Interference stems from a combination of reflections in the environment (random) and
///   mixture of the three BLE advertising channels (more predictable). For reference,
///   channel 37 = 2.402 GHz, channel 38 = 2.426 GHz, and channel 39 = 2.480 GHz.
/// - Simulations have shown mixture of BLE channels play a significant part in RSSI variance
///   over minute distances, e.g. a change of 1cm can result in large RSSI change due to
///   subtle change in phases between the three channels. The impact of this is particularly
///   dominant at short range (0 - 2 metres).
/// - A range of modelling and smoothing algorithms were investigated to counter the impact
///   of reflections and channel mixing. Test results have shown the most widely applicable
///   method that is effective irrespective of environment is running a sliding window of
///   fixed duration (last 60 seconds) over the raw RSSI samples to calculate the median
///   RSSI value. Assuming the phones are not perfectly static (i.e. resting on a desk), the
///   small movements between two phones when carried on a person should be sufficient to
///   produce a wide range of interference patterns that on average offer a reasonably stable
///   estimate of the actual measurement.
/// - Experiments were conducted using different pairs of iOS and Android phones using
///   test rig 2, to capture raw RSSI measurements from 0 - 3.4 metres at 1cm resolution. On
///   average at least 60 RSSI measurements were taken at every 1cm. The data from all the
///   test runs were combined using dynamic time warping to align the RSSI data at each
///   distance. The result was then smoothed using median of a sliding window, then linear
///   regression was applied to estimate the intercept and coefficient for translating RSSI
///   to distance. Linear regression offered the following equation:
///      DistanceInMetres = Intercept + Coefficient x MedianOfRssi
/// - Physical models for electromagnetic wave signal propagation are typically based on
///   log or squared distance, i.e. signal strength degrades logarithmically over distance.
///   The test rig 2 results confirm this, but also shows logarithmic degradation is only
///   obvious within the initial 0 - 20cm, then becomes linear. Given the intended purpose
///   of the distance metric (contact tracing) where risk score remains constant below 1m
///   and also the significant impact of interference within a short range, a linear model
///   avoids being skewed by the 0 - 20cm range, and offer simplicity for fitting the data
///   range of interest (1 - 8m).
public class SmoothedLinearModel: Aggregate {
    public override var runs: Int { get { 1 }}
    private var run: Int = 1
    private let median: Median = Median()
    public var intercept: Double
    public var coefficient: Double
    public static let defaultIntercept: Double = -17.102080
    public static let defaultCoefficient: Double = -0.266793
    
    public init(intercept: Double = SmoothedLinearModel.defaultIntercept, coefficient: Double = SmoothedLinearModel.defaultCoefficient) {
        // Model parameters derived by DataAnalysis.R using data from experiments:
        //  "20210311-0901",
        //  "20210312-1049",
        //  "20210313-1005",
        //  "20210314-1021",
        //  "20210315-1040"
        // Adjusted R-squared:  0.9743
        self.intercept = intercept
        self.coefficient = coefficient
    }

    public override func beginRun(thisRun: Int) {
        run = thisRun
        median.beginRun(thisRun: thisRun)
    }
    
    public override func map(value: Sample) {
        median.map(value: value)
    }

    public override func reduce() -> Double? {
        guard let medianOfRssiValue = medianOfRssi() else {
            return nil
        }
        let distanceInMetres = intercept + coefficient * medianOfRssiValue
        guard distanceInMetres >= 0 else {
            return nil
        }
        return distanceInMetres
    }
    
    public override func reset() {
        median.reset()
    }
    
    public func medianOfRssi() -> Double? {
        return median.reduce()
    }
}



public class SmoothedLinearModelAnalyser: AnalysisProvider {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Analysis.Algorithms.Distance.SmoothedLinearModelAnalyser")
    private let interval: Int64
    private let smoothingWindow: Int64
    private let model: SmoothedLinearModel
    private var lastRan: Date = Date(timeIntervalSince1970: 0)
    private let valid: Filter = InRange(-99, -10)

    public init(interval: TimeInterval = 4, smoothingWindow: TimeInterval = TimeInterval.minute, model: SmoothedLinearModel = SmoothedLinearModel()) {
        self.interval = Int64(interval)
        self.smoothingWindow = Int64(smoothingWindow)
        self.model = model
        super.init(ValueType(describing: RSSI.self), ValueType(describing: Distance.self))
    }

    public override func analyse(timeNow: Date, sampled: SampledID, input: SampleList, output: SampleList, callable: CallableForNewSample) -> Bool {
        // Interval guard
        let secondsSinceLastRan = timeNow.secondsSinceUnixEpoch - lastRan.secondsSinceUnixEpoch
        if secondsSinceLastRan < interval {
            logger.debug("analyse, skipped (reason=elapsedSinceLastRanBelowInterval,interval=\(interval)s,timeSinceLastRan=\(secondsSinceLastRan)s,lastRan=\(lastRan))")
            return false
        }
        // Input guard : Must have valid data to analyse
        let validInput = input.filter(valid).toView()
        guard validInput.size() > 0, let firstValidInput = validInput.get(0) else {
            logger.debug("analyse, skipped (reason=noValidData,inputSamples=\(input.size()),validInputSamples=\(validInput.size()))")
            return false
        }
        // Input guard : Must cover entire smoothing window
        let observed = timeNow.secondsSinceUnixEpoch - firstValidInput.taken.secondsSinceUnixEpoch
        guard observed >= smoothingWindow else {
            logger.debug("analyse, skipped (reason=insufficientHistoricDataForSmoothing,required=\(smoothingWindow)s,observed=\(observed)s)")
            return false
        }
        // Input guard : Must have sufficient data in smoothing window
        let window = validInput.filter(Since(Date(timeIntervalSince1970: TimeInterval(timeNow.secondsSinceUnixEpoch - smoothingWindow)))).toView()
        guard window.size() >= 5 else {
            logger.debug("analyse, skipped (reason=insufficientDataInSmoothingWindow,minimum=5,samplesInWindow=\(window.size()))")
            return false
        }
        // Estimate distance based on smoothed linear model
        model.reset()
        guard let distance = window.aggregate([model]).get(0) else {
            logger.debug("analyse, skipped (reason=outOfModelRange,mediaOfRssi=\(String(describing: model.medianOfRssi()))")
            return false
        }
        // Publish distance data
        guard let timeStart = window.get(0)?.taken, let timeEnd = window.latest() else {
            logger.debug("analyse, skipped (reason=missingStartEndTime)")
            return false
        }
        let timeMiddle = Date(timeIntervalSince1970: timeEnd.timeIntervalSince1970 - (timeEnd.timeIntervalSince1970 - timeStart.timeIntervalSince1970) / 2)
        logger.debug("analyse (timeStart=\(timeStart),timeEnd=\(timeEnd),timeMiddle=\(timeMiddle),samples=\(window.size()),medianOfRssi=\(String(describing: model.medianOfRssi())),distance=\(distance))")
        let newSample = Sample(taken: timeMiddle, value: Distance(distance))
        output.push(sample: newSample)
        callable.newSample(sampled: sampled, item: newSample)
        return true
    }
}
