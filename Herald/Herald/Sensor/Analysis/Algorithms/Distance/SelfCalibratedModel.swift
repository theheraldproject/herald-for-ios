//
//  SelfCalibratedModel.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

/// Extension of SmoothedLinearModel to include self-calibration
/// - Assume minimum and average distance between people for entire population is
///   similar over time (e.g. weeks and months).
/// - Experiments have shown advertised TX power for all test phones are similar
///   while the measured RSSI by different phones differs at the same distance.
/// - Normalisation of measured RSSI value is required to bring all receivers to
///   a common range, and then use the minimum and median value to determine the
///   intercept and coefficient.
/// - Histogram normalisation is enabled by a long term histogram of all measured
///   RSSI values by a device.
/// - Use social norm to set minimum and mean distance between people, then set
///   time duration within minimum and mean distance to derive percentiles for
///   self-calibration based on observed values.
public class SelfCalibratedModel: SmoothedLinearModel {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Analysis.Algorithms.Distance.SelfCalibratedModel")
    private let min: Distance
    private let mean: Distance
    private let maxRssiPercentile: Double
    private let anchorRssiPercentile: Double
    public let histogram: RssiHistogram
    private let textFile: TextFile?
    private var maxRssi: Double = -10
    private var lastSampleTime: Date = Date(timeIntervalSince1970: 0)

    public init(min: Distance, mean: Distance, withinMin: TimeInterval, withinMean: TimeInterval, textFile: TextFile? = nil) {
        self.min = min
        self.mean = mean
        self.maxRssiPercentile = (TimeInterval.day - withinMin) / TimeInterval.day
        self.anchorRssiPercentile = (TimeInterval.day - withinMean) / TimeInterval.day
        self.histogram = RssiHistogram(min: -99, max: -10, updatePeriod: TimeInterval.minute * 10, textFile: textFile)
        self.textFile = textFile
        super.init()
    }
    
    public override func reset() {
        super.reset()
        textFile?.reset()
    }

    public func update() {
        histogram.update()
        // Use max RSSI percentile (e.g. 95th) value for minimum distance
        maxRssi = histogram.normalisedPercentile(maxRssiPercentile)
        // Use anchor RSSI percentile (e.g. 50th, median) value as marker for average distance.
        let anchorRssi = histogram.normalisedPercentile(anchorRssiPercentile)
        // Use value range between mean and max as estimate for coefficient
        let rssiRange = maxRssi - anchorRssi
        // Estimate intercept and coefficient (default derived from SmoothedLinearModel)
        intercept = maxRssi
        coefficient = (rssiRange > 0 ? (mean.value - min.value) / rssiRange : 0.266793)
        logger.debug("update (maxRSSI=\(maxRssi),anchorRSSI=\(anchorRssi),intercept=\(intercept),coefficient=\(coefficient))")
    }

    public override func map(value: Sample) {
        super.map(value: value)
        if (value.taken > lastSampleTime) {
            histogram.add(value.value.value)
            lastSampleTime = value.taken
        }
    }
    
    public override func reduce() -> Double? {
        // Update model
        update()
        guard let sampleMedian = medianOfRssi() else {
            logger.debug("reduce, sample median is nil")
            return nil
        }
        let normalisedMedian = histogram.normalise(sampleMedian)
        if normalisedMedian < -99 {
            logger.debug("reduce, out of range (reason=tooFar,median=\(normalisedMedian),minRssi=-99)")
            return nil
        }
        if normalisedMedian > maxRssi {
            logger.debug("reduce, out of range (reason=tooNear,median=\(normalisedMedian),maxRssi=\(maxRssi)")
            return nil
        }
        let distanceInMetres = min.value + (intercept - normalisedMedian) * coefficient
        guard distanceInMetres > 0 else {
            logger.debug("reduce, out of range (reason=tooNear,median=\(normalisedMedian),distance=\(distanceInMetres))")
            return nil
        }
        return distanceInMetres
    }
}


/// Accumulate histogram of all RSSI measurements to build
/// a profile of the receiver for normalisation
public class RssiHistogram: SensorDelegate {
    public let min: Int
    public let max: Int
    public var histogram: [Int64]
    private var cdf: [Int64]
    private var transform: [Double]
    private let textFile: TextFile?
    private let updatePeriod: TimeInterval
    private var lastUpdateTime: Date = Date(timeIntervalSince1970: 0)
    private var samples: Int64 = 0
    public var description: String { get {
        return "RssiHistogram{samples=\(samples),p05=\(samplePercentile(0.05)),p50=\(samplePercentile(0.5)),p95=\(samplePercentile(0.95))}"
    }}


    /// Accumulate histogram of RSSI for value range [min, max] and auto-write profile to storage at regular intervals
    public init(min: Int, max: Int, updatePeriod: TimeInterval = TimeInterval.minute, textFile: TextFile? = nil) {
        self.min = min;
        self.max = max;
        self.histogram = Array<Int64>(repeating: 0, count: Int(max - min + 1))
        self.cdf = Array<Int64>(repeating: 0, count: histogram.count)
        self.transform = Array<Double>(repeating: 0, count: histogram.count)
        self.textFile = textFile
        self.updatePeriod = updatePeriod
        clear()
        guard let textFile = textFile else {
            return
        }
        read(textFile)
        update()
    }
    
    public func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier) {
        // Guard for data collection until histogram reaches maximum count
        // Deliberately using Int64.max to mirror Android implementation
        guard samples < Int64.max else {
            return
        }
        // Guard for RSSI measurements only
        guard didMeasure.unit == .RSSI else {
            return
        }
        add(didMeasure.value)
    }

    /// Add RSSI sample
    public func add(_ rssi: Int) {
        guard rssi >= min, rssi <= max else {
            return
        }
        // Increment count
        let index = rssi - min
        histogram[index] += 1
        samples += 1
        // Update at regular intervals
        let time = Date()
        if lastUpdateTime.secondsSinceUnixEpoch + Int64(updatePeriod) < time.secondsSinceUnixEpoch {
            if let textFile = textFile {
                write(textFile)
            }
            update()
            lastUpdateTime = time
        }
    }
    
    public func add(_ rssiValue: Double) {
        // Guard for RSSI range
        let rssi = Int(round(rssiValue))
        add(rssi)
    }

    public func clear() {
        for i in 0...histogram.count-1 {
            histogram[i] = 0
            cdf[i] = 0
        }
        for i in 0...transform.count-1 {
            transform[i] = Double(i)
        }
        samples = 0
    }

    public func samplePercentile(_ percentile: Double) -> Int {
        if samples == 0 {
            return min + Int(round(Double(max - min) * percentile))
        }
        let percentileCount = Double(samples) * percentile
        for i in 0...cdf.count-1 {
            if Double(cdf[i]) >= percentileCount {
                return Int(min + i)
            }
        }
        return Int(max)
    }

    public func normalisedPercentile(_ percentile: Double) -> Double {
        return normalise(Double(samplePercentile(percentile)))
    }

    /// Read profile data from storage, this replaces existing in-memory profile
    public func read(_ textFile: TextFile) {
        clear()
        let content = textFile.contentsOf()
        for row in content.split(separator: "\n") {
            let cols = row.split(separator: ",", maxSplits: 2)
            guard cols.count == 2 else {
                continue
            }
            guard let rssi = Int(cols[0]), let count = Int64(cols[1]) else {
                continue
            }
            guard rssi >= min, rssi <= max else {
                continue
            }
            let index = rssi - min
            histogram[index] = count
            samples += count
        }
    }

    /// Render profile data as CSV (RSSI,count)
    private func toCsv() -> String {
        var s = ""
        for i in 0...histogram.count-1 {
            let rssi = min + i
            let row = "\(rssi),\(histogram[i])\n"
            s += row
        }
        return s
    }

    /// Write profile data to storage
    public func write(_ textFile: TextFile) {
        let content = toCsv()
        textFile.overwrite(content)
    }

    // MARK: - Histogram equalisation

    /// Compute cumulative distribution function (CDF) of histogram
    private static func cumulativeDistributionFunction(_ histogram: [Int64], _ cdf: inout [Int64]) {
        var sum = Int64(0)
        for i in 0...histogram.count-1 {
            sum += histogram[i]
            cdf[i] = sum
        }
    }

    /// Compute transformation table for normalising histogram to maximise its dynamic range
    private static func normalisation(_ cdf: [Int64], _ transform: inout [Double]) {
        let sum = Double(cdf[cdf.count - 1])
        let max = Double(cdf.count - 1)
        if sum > 0 {
            for i in 0...cdf.count-1 {
                transform[i] = max * Double(cdf[i]) / sum
            }
        }
    }

    public func update() {
        RssiHistogram.cumulativeDistributionFunction(histogram, &cdf)
        RssiHistogram.normalisation(cdf, &transform)
    }

    // MARK: - Normalisation
    
    public func normalise(_ rssi: Int) -> Double {
        normalise(Double(rssi))
    }

    public func normalise(_ rssi: Double) -> Double {
        let index = Int(round(rssi - Double(min)))
        guard index >= 0 else {
            return Double(min) + transform[0]
        }
        guard index < transform.count else {
            return Double(min) + transform.last!
        }
        return Double(min) + transform[index]
    }
}
