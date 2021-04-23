//
//  SampleList.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class SampleList {
    private var data: [Sample?]
    private var oldestPosition, newestPosition: Int
    public var description: String { get {
        guard size() > 0 else {
            return "[]"
        }
        var s: String = "["
        for i in 0...size()-1 {
            guard let item = get(i) else {
                continue
            }
            if s.count > 1 {
                s += " ,"
            }
            s += item.description
        }
        s += "]"
        return s
    }}
    
    public init(_ size: Int) {
        self.data = [Sample?](repeating: nil, count: size)
        self.oldestPosition = size
        self.newestPosition = size
    }
    
    public convenience init(_ size: Int, samples: [Sample]) {
        self.init(size)
        samples.forEach({ sample in push(sample: sample) })
    }
    
    public convenience init(samples: [Sample]) {
        self.init(samples.count, samples: samples)
    }
    
    public convenience init(iterator: SampleIterator) {
        self.init(samples: SampleList.toArray(iterator))
    }
    
    private static func toArray(_ iterator: SampleIterator) -> [Sample] {
        var array: [Sample] = []
        while let item = iterator.next() {
            array.append(item)
        }
        return array
    }
    
    public func push(sample: Sample) {
        incrementNewest()
        data[newestPosition] = sample
    }
    
    public func push(taken: Date, value: DoubleValue) {
        push(sample: Sample(taken: taken, value: value))
    }
    
    public func push(timeIntervalSince1970: TimeInterval, value: DoubleValue) {
        push(sample: Sample(timeIntervalSince1970: timeIntervalSince1970, value: value))
    }
    
    public func push(secondsSinceUnixEpoch: Int64, value: DoubleValue) {
        push(sample: Sample(secondsSinceUnixEpoch: secondsSinceUnixEpoch, value: value))
    }
    
    public func size() -> Int {
        if newestPosition == data.count {
            return 0
        }
        if newestPosition >= oldestPosition {
            // not overlapping the end
            return newestPosition - oldestPosition + 1
        }
        // we've overlapped
        return (1 + newestPosition) + (data.count - oldestPosition)
    }
    
    public func get(_ index: Int) -> Sample? {
        if newestPosition >= oldestPosition {
            guard let item = data[index + oldestPosition] else {
                return nil
            }
            return item
        }
        if index + oldestPosition >= data.count {
            // TODO handle the situation where this pos > newestPosition (i.e. gap in the middle)
            guard let item = data[index + oldestPosition - data.count] else {
                return nil
            }
            return item
        }
        guard let item = data[index + oldestPosition] else {
            return nil
        }
        return item
    }
    
    public func clearBeforeDate(_ before: Date) {
        guard oldestPosition != data.count else {
            return
        }
        while oldestPosition != newestPosition {
            if let item = data[oldestPosition], item.taken < before {
                    oldestPosition += 1
                    if data.count == oldestPosition {
                        // overflowed
                        oldestPosition = 0
                    }
            } else {
                return
            }
        }
        // now we're on the last element
        if let item = data[oldestPosition], item.taken < before {
            oldestPosition = data.count
            newestPosition = data.count
        }
    }

    public func clear() {
        oldestPosition = data.count
        newestPosition = data.count
    }

    public func latest() -> Date? {
        guard newestPosition != data.count, let item = data[newestPosition] else {
            return nil
        }
        return item.taken
    }
    
    public func latestValue() -> DoubleValue? {
        guard newestPosition != data.count, let item = data[newestPosition] else {
            return nil
        }
        return item.value
    }

    private func incrementNewest() {
        if newestPosition == data.count {
            newestPosition = 0
            oldestPosition = 0
        } else {
            if newestPosition == (oldestPosition - 1) {
                oldestPosition += 1
                if oldestPosition == data.count {
                    oldestPosition = 0
                }
            }
            newestPosition += 1
        }
        if newestPosition == data.count {
            // just gone past the end of the container
            newestPosition = 0;
            if oldestPosition == 0 {
                // erases oldest if not already removed
                oldestPosition += 1
            }
        }
    }

    public func makeIterator() -> SampleIterator {
        return SampleListIterator(self)
    }
    
    public func filter(_ filter: Filter) -> SampleIterator {
        return SampleIteratorProxy(makeIterator(), filter)
    }

    public func aggregate(_ aggregates: [Aggregate]) -> Summary {
        var maxRuns = 0
        for aggregate in aggregates {
            if aggregate.runs > maxRuns {
                maxRuns = aggregate.runs
            }
        }
        for run in 1...maxRuns {
            aggregates.forEach({ $0.beginRun(thisRun: run) })
            let iterator = makeIterator()
            while let sample = iterator.next() {
                aggregates.forEach({ $0.map(value: sample) })
            }
        }
        return Summary(aggregates)
    }
}




public class SampleIterator {
    public func next() -> Sample? {
        return nil
    }
    
    public func toView() -> SampleList {
        return SampleList(iterator: self)
    }

    public func filter(_ filter: Filter) -> SampleIterator {
        return SampleIteratorProxy(self, filter)
    }

    public func aggregate(_ aggregates: [Aggregate]) -> Summary {
        return toView().aggregate(aggregates);
    }
}

public class SampleListIterator: SampleIterator {
    private let sampleList: SampleList
    private var index = 0

    init(_ sampleList: SampleList) {
        self.sampleList = sampleList
    }

    public override func next() -> Sample? {
        guard index < sampleList.size(), let item = sampleList.get(index) else {
            return nil
        }
        index += 1
        return item
    }
}

public class SampleIteratorProxy: SampleIterator {
    private var source: SampleIterator
    private let filter: Filter
    private var nextItem: Sample?
    private var nextItemSet: Bool = false

    init(_ source: SampleIterator, _ filter: Filter) {
        self.source = source
        self.filter = filter
    }

    public override func next() -> Sample? {
        guard nextItemSet || moveToNextItem() else {
            return nil
        }
        nextItemSet = false
        return nextItem
    }
    
    private func moveToNextItem() -> Bool {
        while let item = source.next() {
            if filter.test(item: item) {
                nextItem = item
                nextItemSet = true
                return true
            }
        }
        return false
    }
}

public class Summary {
    private let aggregates: [Aggregate]

    public init(_ aggregates: [Aggregate]) {
        self.aggregates = aggregates
    }

    public func get<U: Aggregate>(_ byClass: U.Type) -> Double? {
        for aggregate in aggregates {
            if type(of: aggregate) == byClass {
                return aggregate.reduce()
            }
        }
        return nil
    }

    public func get(_ index: Int) -> Double? {
        guard index >= 0 && index < aggregates.count else {
            return nil
        }
        return aggregates[index].reduce()
    }
}
