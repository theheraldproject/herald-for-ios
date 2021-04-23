//
//  Filter.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class Filter<T: DoubleValue> {
    public func test(item: Sample<T>) -> Bool {
        return true
    }
}

// MARK: - Filters

public class NoOp<T: DoubleValue>: Filter<T> {

    public override func test(item: Sample<T>) -> Bool {
        return true
    }
}

// MARK: - Value filters

public class GreaterThan<T: DoubleValue>: Filter<T> {
    private let min: Double

    public init(_ min: Double) {
        self.min = min
    }

    public override func test(item: Sample<T>) -> Bool {
        return item.value.doubleValue() > min
    }
}

public class LessThan<T: DoubleValue>: Filter<T> {
    private let max: Double

    public init(_ max: Double) {
        self.max = max
    }

    public override func test(item: Sample<T>) -> Bool {
        return item.value.doubleValue() < max
    }
}

public class InRange<T: DoubleValue>: Filter<T> {
    private let min: Double
    private let max: Double

    public init(_ min: Double, _ max: Double) {
        self.min = min
        self.max = max
    }

    public override func test(item: Sample<T>) -> Bool {
        return item.value.doubleValue() >= min && item.value.doubleValue() <= max
    }
}

// MARK: - Time filters

public class Since<T: DoubleValue>: Filter<T> {
    private let after: Date

    public init(_ after: Date) {
        self.after = after
    }

    public convenience init(_ secondsSinceUnixEpoch: Int) {
        self.init(Date(timeIntervalSince1970: TimeInterval(secondsSinceUnixEpoch)))
    }
    
    public convenience init(_ timeIntervalSince1970: TimeInterval) {
        self.init(Date(timeIntervalSince1970: timeIntervalSince1970))
    }
    
    public convenience init(recent: TimeInterval) {
        self.init(Date(timeIntervalSinceNow: -recent))
    }
    
    public override func test(item: Sample<T>) -> Bool {
        return item.taken >= after
    }
}

public class Until<T: DoubleValue>: Filter<T> {
    private let before: Date

    public init(_ before: Date) {
        self.before = before
    }

    public convenience init(_ secondsSinceUnixEpoch: Int) {
        self.init(Date(timeIntervalSince1970: TimeInterval(secondsSinceUnixEpoch)))
    }
    
    public convenience init(_ timeIntervalSince1970: TimeInterval) {
        self.init(Date(timeIntervalSince1970: timeIntervalSince1970))
    }
    
    public convenience init(recent: TimeInterval) {
        self.init(Date(timeIntervalSinceNow: -recent))
    }
    
    public override func test(item: Sample<T>) -> Bool {
        return item.taken <= before
    }
}

public class InPeriod<T: DoubleValue>: Filter<T> {
    private let after: Date
    private let before: Date

    public init(_ after: Date, _ before: Date) {
        self.after = after
        self.before = before
    }

    public convenience init(_ afterSecondsSinceUnixEpoch: Int, _ beforeSecondsSinceUnixEpoch: Int) {
        self.init(
            Date(timeIntervalSince1970: TimeInterval(afterSecondsSinceUnixEpoch)),
            Date(timeIntervalSince1970: TimeInterval(beforeSecondsSinceUnixEpoch)))
    }
    
    public convenience init(_ afterTimeIntervalSince1970: TimeInterval, _ beforeTimeIntervalSince1970: TimeInterval) {
        self.init(
            Date(timeIntervalSince1970: afterTimeIntervalSince1970),
            Date(timeIntervalSince1970: beforeTimeIntervalSince1970))
    }
    
    public override func test(item: Sample<T>) -> Bool {
        return after <= item.taken && item.taken <= before
    }
}

