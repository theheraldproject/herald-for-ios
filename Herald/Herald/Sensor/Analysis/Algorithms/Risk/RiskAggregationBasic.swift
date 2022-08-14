//
//  RiskAggregationBasic.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// A Basic sample but non scientific risk aggregation model.
/// Similar in function to the Oxford Risk Model, but without its calibration values and scaling.
/// NOT FOR PRODUCTION EPIDEMIOLOGICAL USE - SAMPLE ONLY!!!
public class RiskAggregationBasic: Aggregate {
    public override var runs: Int { get { 1 }}
    private var run: Int = 1
    private var timeScale: Double
    private var distanceScale: Double
    private var minimumDistanceClamp: Double
    private var minimumRiskScoreAtClamp: Double
    private var logScale: Double
    private var nMinusOne: Double // distance of n-1
    private var n: Double // distance of n
    private var timeMinusOne: Int64 // time of n-1
    private var time: Int64 // time of n
    private var riskScore: Double

    public init(timeScale: Double, distanceScale: Double, minimumDistanceClamp: Double, minimumRiskScoreAtClamp: Double, logScale: Double = 3.3598856662) {
        self.timeScale = timeScale
        self.distanceScale = distanceScale
        self.minimumDistanceClamp = minimumDistanceClamp
        self.minimumRiskScoreAtClamp = minimumRiskScoreAtClamp
        self.logScale = logScale
        self.nMinusOne = -1
        self.n = -1
        self.timeMinusOne = 0
        self.time = 0
        self.riskScore = 0
    }

    public override func beginRun(thisRun: Int) {
        run = thisRun
        if (1 == run) {
            // clear run temporaries
            nMinusOne = -1.0
            n = -1.0
            timeMinusOne = 0
            time = 0
        }
    }

    public override func map(value: Sample) {
        nMinusOne = n
        timeMinusOne = time
        n = value.value.value
        time = value.taken.secondsSinceUnixEpoch
    }

    public override func reduce() -> Double? {
        if -1.0 != nMinusOne {
            // we have two values with which to calculate
            // using nMinusOne and n, and calculate interim risk score addition
            let dist = distanceScale * n
            let t = timeScale * Double(time - timeMinusOne) // seconds

            var riskSlice = minimumRiskScoreAtClamp // assume < clamp distance
            if dist > minimumDistanceClamp {
                // otherwise, do the inverse log of distance to get the risk score

                // don't forget to clamp at risk score
                riskSlice = minimumRiskScoreAtClamp - (logScale * log10(dist))
                if riskSlice > minimumRiskScoreAtClamp {
                    // possible as the passed in logScale could be a negative
                    riskSlice = minimumRiskScoreAtClamp
                }
                if riskSlice < 0.0 {
                    riskSlice = 0.0 // cannot have a negative slice
                }
            }
            riskSlice *= t

            // add it to the risk score
            riskScore += riskSlice
        }

        // return current full risk score
        return riskScore
    }

    public override func reset() {
        run = 1
        riskScore = 0.0
        nMinusOne = -1.0
        n = -1.0
    }
}
