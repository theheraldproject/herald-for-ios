//
//  AnalysisRunner.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public class AnalysisRunner: CallableForNewSample {
    private let analysisProviderManager: AnalysisProviderManager
    private let analysisDelegateManager: AnalysisDelegateManager
    public let variantSet: VariantSet

    public init(_ analysisProviderManager: AnalysisProviderManager, _ analysisDelegateManager: AnalysisDelegateManager, defaultListSize: Int) {
        self.analysisProviderManager = analysisProviderManager
        self.analysisDelegateManager = analysisDelegateManager
        self.variantSet = VariantSet(defaultListSize)
    }

    public override func newSample(sampled: SampledID, item: Sample) {
        variantSet.push(sampled, item)
    }

    public func run(timeNow: Date = Date()) {
        for sampled in variantSet.sampledIDs() {
            let _ = analysisProviderManager.analyse(timeNow: timeNow, sampled: sampled, variantSet: variantSet, delegates: analysisDelegateManager)
        }
    }
}
