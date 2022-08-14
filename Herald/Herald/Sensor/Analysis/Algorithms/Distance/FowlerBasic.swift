//
//  FowlerBasic.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class FowlerBasic: Aggregate {
    public override var runs: Int { get { 1 }}
    private var run: Int = 1
    private let mode: Mode = Mode()
    private let intercept: Double
    private let coefficient: Double

    public init(intercept: Double, coefficient: Double) {
        self.intercept = intercept
        self.coefficient = coefficient
    }
    
    public override func beginRun(thisRun: Int) {
        run = thisRun
        mode.beginRun(thisRun: thisRun)
    }

    public override func map(value: Sample) {
        mode.map(value: value)
    }

    public override func reduce() -> Double? {
        guard let modeValue = mode.reduce() else {
            return nil
        }
        
        let exponent = (modeValue - intercept) / coefficient
        return pow(10, exponent)
    }

    public override func reset() {
        mode.reset()
    }
}



public class FowlerBasicAnalyser: AnalysisProvider {
    private let interval: TimeInterval
    private let basic: FowlerBasic
    private var lastRan: Date = Date(timeIntervalSince1970: 0)
    private let valid: Filter = InRange(-99, -10)

    public init(interval: TimeInterval = TimeInterval(10), intercept: Double = -11, coefficient: Double = -0.4) {
        self.interval = interval
        self.basic = FowlerBasic(intercept: intercept, coefficient: coefficient)
        super.init(ValueType(describing: RSSI.self), ValueType(describing: Distance.self))
    }

    public override func analyse(timeNow: Date, sampled: SampledID, input: SampleList, output: SampleList, callable: CallableForNewSample) -> Bool {
        // Interval guard
        if lastRan.secondsSinceUnixEpoch + Int64(interval) >= timeNow.secondsSinceUnixEpoch {
            return false
        }
        basic.reset()
        let values = input.filter(valid).toView()
        let summary = values.aggregate([Mode(), Variance()])
        guard let mode = summary.get(Mode.self), let variance = summary.get(Variance.self) else {
            return false
        }
        let sd = sqrt(variance)
        guard let distance = input.filter(valid).filter(InRange(mode-2*sd, mode+2*sd)).aggregate([basic]).get(FowlerBasic.self) else {
            return false
        }
        guard let latestTime = values.latest() else {
            return false
        }
        lastRan = latestTime
        let newSample = Sample(taken: latestTime, value: Distance(distance))
        output.push(sample: newSample)
        callable.newSample(sampled: sampled, item: newSample)
        return true
    }
}
