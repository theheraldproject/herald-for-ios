//
//  SampleStatistics.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Sample statistics, assumes normal distribution.
public class SampleStatistics {
    private var n:Int64 = 0
    private var m1:Double = 0.0
    private var m2:Double = 0.0
    private var m3:Double = 0.0
    private var m4:Double = 0.0
    
    /**
     Minimum sample value.
     */
    public var min:Double? = nil
    /**
     Maximum sample value.
     */
    public var max:Double? = nil
    /**
     Sample size.
     */
    public var count:Int64 { get { n } }
    /**
     Mean sample value.
     */
    public var mean:Double? { get { n > 0 ? m1 : nil } }
    /**
     Sample variance.
     */
    public var variance:Double? { get { n > 1 ? m2 / Double(n - 1) : nil } }
    /**
     Sample standard deviation.
     */
    public var standardDeviation:Double? { get { n > 1 ? sqrt(m2 / Double(n - 1)) : nil } }
    
    /**
     String representation of mean, standard deviation, min and max
     */
    public var description: String { get {
        let sCount = n.description
        let sMean = (mean == nil ? "-" : mean!.description)
        let sStandardDeviation = (standardDeviation == nil ? "-" : standardDeviation!.description)
        let sMin = (min == nil ? "-" : min!.description)
        let sMax = (max == nil ? "-" : max!.description)
        return "count=" + sCount + ",mean=" + sMean + ",sd=" + sStandardDeviation + ",min=" + sMin + ",max=" + sMax
        } }
    
    public init() {
    }
    
    public init(_ x: Double, _ f: Int64) {
        n = f
        m1 = x
        min = x
        max = x
    }
    
    /// Add sample value x.
    public func add(_ x:Double) {
        // Sample value accumulation algorithm avoids reiterating sample to compute variance.
        let n1 = n
        n += 1
        let d = x - m1
        let d_n = d / Double(n)
        let d_n2 = d_n * d_n;
        let t = d * d_n * Double(n1);
        m1 += d_n;
        m4 += t * d_n2 * Double(n * n - 3 * n + 3) + 6 * d_n2 * m2 - 4 * d_n * m3;
        m3 += t * d_n * Double(n - 2) - 3 * d_n * m2;
        m2 += t;
        if min == nil || x < min! {
            min = x;
        }
        if max == nil || x > max! {
            max = x;
        }
    }
    
    /// Add sample value x, n times.
    public func add(_ x:Double, _ n:Int) {
        add(SampleStatistics(x, Int64(n)))
    }
    
    /// Add samples to this sample.
    public func add(_ sample: SampleStatistics) {
        guard sample.n > 0 else {
            return
        }
        guard n > 0 else {
            n = sample.n
            m1 = sample.m1
            m2 = sample.m2
            m3 = sample.m3
            m4 = sample.m4
            min = sample.min
            max = sample.max
            return
        }
        let combined = SampleStatistics()
        combined.n = n + sample.n

        let delta: Double = sample.m1 - m1
        let delta2: Double = delta * delta
        let delta3: Double = delta * delta2
        let delta4: Double = delta2 * delta2

        combined.m1 = (Double(n) * m1 + Double(sample.n) * sample.m1) / Double(combined.n)
        combined.m2 = m2 + sample.m2 + delta2 * Double(n * sample.n) / Double(combined.n)
        combined.m3 = m3 + sample.m3
                + delta3 * Double(n * sample.n * (n - sample.n)) / Double(combined.n * combined.n)
        combined.m3 = combined.m3 + 3.0 * delta * (Double(n) * sample.m2 - Double(sample.n) * m2) / Double(combined.n)
        combined.m4 = m4 + sample.m4 + delta4 * Double(n * sample.n
                * (n * n - n * sample.n + sample.n * sample.n)) / Double(combined.n * combined.n * combined.n)
        combined.m4 = combined.m4 + 6.0 * delta2 * (Double(n * n) * sample.m2 + Double(sample.n * sample.n) * m2)
                / Double(combined.n * combined.n) + 4.0 * delta * (Double(n) * sample.m3 - Double(sample.n) * m3) / Double(combined.n)
        combined.min = (min! < sample.min! ? min : sample.min)
        combined.max = (max! > sample.max! ? max : sample.max)

        n = combined.n
        m1 = combined.m1
        m2 = combined.m2
        m3 = combined.m3
        m4 = combined.m4
        min = combined.min
        max = combined.max
    }
    
    /// Estimate distance between this sample's distribution and another sample's distribution, 1 means identical and 0 means completely different.
    public func distance(_ sample: SampleStatistics) -> Double? {
        return bhattacharyyaDistance(self, sample)
    }
    
    /// Bhattacharyya distance between two distributions estimate  the likelihood that the two distributions are the same.
    /// bhattacharyyaDistance = 1 means the two distributions are identical; value = 0 means they are different.
    private func bhattacharyyaDistance(_ d1: SampleStatistics, _ d2: SampleStatistics) -> Double? {
        guard let v1 = d1.variance, let v2 = d2.variance, let m1 = d1.mean, let m2 = d2.mean else {
            return nil
        }
        if (v1 == 0 && v2 == 0) {
            if (m1 == m2) {
                return 1
            } else {
                return 0
            }
        }
        guard let sd1 = d1.standardDeviation, let sd2 = d2.standardDeviation else {
            return nil
        }
        return sqrt((Double(2) * sd1 * sd2) / (v1 + v2)) * exp(Double(-1) / Double(4) * (pow((m1 - m2), 2) / (v1 + v2)))
    }

}
