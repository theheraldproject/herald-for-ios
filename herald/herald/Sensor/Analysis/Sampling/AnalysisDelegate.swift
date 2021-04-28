//
//  AnalysisDelegate.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class AnalysisDelegate: CallableForNewSample {
    public let inputType: ValueType
    private let listManager: ListManager
    public let samples: SampleList
    
    public init(inputType: ValueType, listSize: Int) {
        self.inputType = inputType
        self.listManager = ListManager(listSize)
        self.samples = SampleList(listSize)
    }
    
    public convenience init<T:DoubleValue>(_ inputType: T.Type, listSize: Int) {
        self.init(inputType: ValueType(describing: inputType), listSize: listSize)
    }

    public func reset() {
        listManager.clear()
    }

    public func samples(sampledID: SampledID) -> SampleList {
        return listManager.list(sampledID)
    }

    public override func newSample(sampled: SampledID, item: Sample) {
        listManager.push(sampled, item)
        samples.push(sample: item)
    }
}



public class CallableForNewSample {

    public func newSample(sampled: SampledID, item: Sample) {}
}



public class AnalysisDelegateManager: CallableForNewSample {
    private var lists: [ValueType:[AnalysisDelegate]] = [:]
    private let queue = DispatchQueue(label: "Sensor.Analysis.Sampling.AnalysisDelegateManager")

    public init(_ delegates: [AnalysisDelegate] = []) {
        super.init()
        delegates.forEach({ add($0) })
    }
    
    public func inputTypes() -> Set<ValueType> {
        return Set<ValueType>(lists.keys)
    }
    
    public func add(_ delegate: AnalysisDelegate) {
        queue.sync {
            if var list = lists[delegate.inputType] {
                list.append(delegate)
            } else {
                lists[delegate.inputType] = [delegate]
            }
        }
    }

    public override func newSample(sampled: SampledID, item: Sample) {
        guard let delegates = lists[item.valueType] else {
            return
        }
        delegates.forEach({ $0.newSample(sampled: sampled, item: item)})
    }
}
