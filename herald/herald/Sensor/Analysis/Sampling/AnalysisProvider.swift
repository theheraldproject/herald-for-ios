//
//  AnalysisProvider.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class AnalysisProvider {
    public let inputType: ValueType
    public let outputType: ValueType

    public init(_ inputType: ValueType, _ outputType: ValueType) {
        self.inputType = inputType
        self.outputType = outputType
    }
        
    public func analyse(timeNow: Date, sampled: SampledID, input: SampleList, output: SampleList, callable: CallableForNewSample) -> Bool {
        return false
    }
}



public class AnalysisProviderManager {
    private var lists: [ValueType:[AnalysisProvider]] = [:]
    public var inputTypes: Set<ValueType> = Set<ValueType>()
    public var outputTypes: Set<ValueType> = Set<ValueType>()
    private var providers: [AnalysisProvider] = []
    private let queue = DispatchQueue(label: "Sensor.Analysis.Sampling.AnalysisProviderManager")

    public init(_ providers: [AnalysisProvider] = []) {
        providers.forEach({ add($0) })
    }
    
    public func add(_ provider: AnalysisProvider) {
        queue.sync {
            if var list = lists[provider.inputType] {
                list.append(provider)
            } else {
                lists[provider.inputType] = [provider]
            }
            inputTypes.insert(provider.inputType)
            outputTypes.insert(provider.outputType)
            providers.append(provider)
        }
    }
    
    public func analyse(timeNow: Date, sampled: SampledID, variantSet: VariantSet, delegates: AnalysisDelegateManager) -> Bool {
        var update = false
        for provider in providers {
            let input = variantSet.listManager(variant: provider.inputType, listFor: sampled)
            let output = variantSet.listManager(variant: provider.outputType, listFor: sampled)
            let hasUpdate = provider.analyse(timeNow: timeNow, sampled: sampled, input: input, output: output, callable: delegates)
            update = update || hasUpdate
        }
        return update
    }
}
