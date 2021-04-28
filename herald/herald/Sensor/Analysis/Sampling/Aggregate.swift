//
//  Aggregate.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class Aggregate {
    var runs: Int { get { 0 }}
    
    func beginRun(thisRun: Int) {
    }

    func map(value : Sample) {
    }

    func reduce() -> Double? {
        return nil
    }

    func reset() {
    }
}

// MARK: - Aggregates

public class Mean: Aggregate {
    override var runs: Int { get { 1 }}
    private var run: Int = 1
    private var count: Int64 = 0
    private var sum: Double = 0

    public override func beginRun(thisRun: Int) {
        run = thisRun
    }

    public override func map(value: Sample) {
        guard run == 1 else {
            return
        }
        sum += value.value.value
        count += 1
    }

    public override func reduce() -> Double? {
        guard count > 0 else {
            return nil
        }
        return sum / Double(count)
    }

    public override func reset() {
        run = 1
        count = 0
        sum = 0
    }
}

public class Variance: Aggregate {
    override var runs: Int { get { 2 }}
    private var run: Int = 1
    private var count: Int64 = 0
    private var sum: Double = 0
    private var mean: Double = 0

    public override func beginRun(thisRun: Int) {
        run = thisRun
        if run == 2 {
            // initialise mean
            if count > 0 {
                mean = sum / Double(count)
            } else {
                mean = 0
            }
            // reinitialise counters
            sum = 0
            count = 0
        }

    }

    public override func map(value: Sample) {
        if run == 1 {
            sum += value.value.value
        } else {
            // run == 2
            let dv = value.value.value
            sum += (dv - mean) * (dv - mean)
        }
        count += 1
    }

    public override func reduce() -> Double? {
        guard count > 1 else {
            return 0
        }
        return sum / Double(count - 1)
    }

    public override func reset() {
        count = 0
        run = 1
        sum = 0
        mean = 0
    }
}

public class Mode: Aggregate {
    override var runs: Int { get { 1 }}
    private var run: Int = 1
    private var counts: [Double:Int64] = [:]

    public override func beginRun(thisRun: Int) {
        run = thisRun
    }

    public override func map(value: Sample) {
        guard run == 1 else {
            return
        }
        if let count = counts[value.value.value] {
            counts[value.value.value] = count + 1
        } else {
            counts[value.value.value] = 1
        }
    }

    public override func reduce() -> Double? {
        guard !counts.isEmpty else {
            return nil
        }
        var largest: Double = 0
        var largestCount: Int64 = 0
        counts.forEach({ value, count in
            if (count > largestCount || (count == largestCount && value > largest)) {
                largest = value
                largestCount = count
            }
        })
        return largest
    }

    public override func reset() {
        counts.removeAll()
    }
}

public class Median: Aggregate {
    override var runs: Int { get { 1 }}
    private var run: Int = 1
    private var values: [Double] = []
    private var median: Double? = nil

    public override func beginRun(thisRun: Int) {
        run = thisRun
    }

    public override func map(value: Sample) {
        guard run == 1 else {
            return
        }
        values.append(value.value.value)
    }

    public override func reduce() -> Double? {
        if let m = median {
            return m
        }
        guard values.count > 0 else {
            return nil
        }
        values.sort()
        if values.count % 2 == 1 {
            median = values[values.count / 2]
        } else {
            median = (values[values.count / 2 - 1] + values[values.count / 2]) / Double(2)
        }
        if let m = median {
            return m
        } else {
            return nil
        }
    }

    public override func reset() {
        values.removeAll()
        median = nil
    }
}


public class Gaussian: Aggregate {
    override var runs: Int { get { 1 }}
    private var run: Int = 1
    public var model: SampleStatistics = SampleStatistics()

    public override func beginRun(thisRun: Int) {
        run = thisRun
    }

    public override func map(value: Sample) {
        guard run == 1 else {
            return
        }
        model.add(value.value.value)
    }

    public override func reduce() -> Double? {
        return model.mean
    }

    public override func reset() {
        model = SampleStatistics()
    }
}

