//
//  AnalysisRunnerTests.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class AnalysisRunnerTests: XCTestCase {
    
    private class Int8: DoubleValue {
    }

    func test_listmanager() {
        let listManager = ListManager(10)
        let _ = listManager.list(SampledID(1))
        let _ = listManager.list(SampledID(2))
        let _ = listManager.list(SampledID(2))
        XCTAssertEqual(listManager.sampledIDs().count, 2)
        listManager.remove(SampledID(1))
        XCTAssertEqual(listManager.sampledIDs().count, 1)
        var iterator = listManager.sampledIDs().makeIterator()
        XCTAssertEqual(iterator.next()!.value, 2)
        listManager.clear()
        XCTAssertEqual(listManager.sampledIDs().count, 0)
    }
    
    func test_swift_type_system() {
        let a: DoubleValue = Int8(1)
        let b: DoubleValue = RSSI(2)
        print(type(of: a))
        print(type(of: b))
        print(String(describing: Int8.self))
        print(String(describing: RSSI.self))
    }
    
    func test_variantset_listmanager() {
        let variantSet = VariantSet(15)
        let listManagerRSSI = variantSet.listManager(RSSI.self)
        let listManagerInt8 = variantSet.listManager(Int8.self)
        XCTAssertEqual(variantSet.size(), 2)
        XCTAssertEqual(listManagerRSSI.size(), 0)
        XCTAssertEqual(listManagerInt8.size(), 0)

        let sampleListRSSI = listManagerRSSI.list(SampledID(1234))
        let sampleListInt8 = listManagerInt8.list(SampledID(5678))
        XCTAssertEqual(sampleListRSSI.size(), 0)
        XCTAssertEqual(sampleListInt8.size(), 0)
        
        sampleListRSSI.push(sample: Sample(secondsSinceUnixEpoch: 0, value: RSSI(12)))
        sampleListInt8.push(sample: Sample(secondsSinceUnixEpoch: 10, value: Int8(14)))
        variantSet.push(SampledID(5678), Sample(secondsSinceUnixEpoch: 20, value: Int8(15)))
        XCTAssertEqual(variantSet.listManager(RSSI.self, SampledID(1234)).size(), 1)
        XCTAssertEqual(variantSet.listManager(Int8.self, SampledID(5678)).size(), 2)
        
        variantSet.remove(sampledID: SampledID(1234))
        XCTAssertEqual(listManagerRSSI.size(), 0)
        XCTAssertEqual(listManagerInt8.size(), 1)

        variantSet.remove(RSSI.self)
        XCTAssertEqual(variantSet.size(), 1)
    }


    /// [Who]   As a DCT app developer
    /// [What]  I want to link my live application data to an analysis runner easily
    /// [Value] So I don't have to write plumbing code for Herald itself
    ///
    /// [Who]   As a DCT app developer
    /// [What]  I want to periodically run analysis aggregates automatically
    /// [Value] So I don't miss any information, and have accurate, regular, samples
    public func test_analysisrunner_basic() {
        let srcData = SampleList(25)
        srcData.push(secondsSinceUnixEpoch: 10, value: RSSI(-55))
        srcData.push(secondsSinceUnixEpoch: 20, value: RSSI(-55))
        srcData.push(secondsSinceUnixEpoch: 30, value: RSSI(-55))
        srcData.push(secondsSinceUnixEpoch: 40, value: RSSI(-55))
        srcData.push(secondsSinceUnixEpoch: 50, value: RSSI(-55))
        srcData.push(secondsSinceUnixEpoch: 60, value: RSSI(-55))
        srcData.push(secondsSinceUnixEpoch: 70, value: RSSI(-55))
        srcData.push(secondsSinceUnixEpoch: 80, value: RSSI(-55))
        srcData.push(secondsSinceUnixEpoch: 90, value: RSSI(-55))
        srcData.push(secondsSinceUnixEpoch: 100, value: RSSI(-55))
        let src = DummyRSSISource(SampledID(1234), srcData)
        
        let distanceAnalyser = FowlerBasicAnalyser(interval: TimeInterval(30), intercept: -50, coefficient: -24)
        let myDelegate = DummyDistanceDelegate()
        
        let adm = AnalysisDelegateManager([myDelegate])
        let apm = AnalysisProviderManager([distanceAnalyser])
        
        let runner = AnalysisRunner(apm, adm, defaultListSize: 25)

        // run at different times
        src.run(20, runner)
        src.run(40, runner) // Runs here, because we have data for 10,20,>>30<<,40 <- next run time based on this 'latest' data time
        src.run(60, runner)
        src.run(80, runner) // Runs here because we have extra data for 50,60,>>70<<,80 <- next run time based on this 'latest' data time
        src.run(95, runner)
        
        XCTAssertEqual(myDelegate.lastSampledID, SampledID(1234))
        let samples = myDelegate.samples
        XCTAssertEqual(samples.size(), 2)
        XCTAssertEqual(samples.get(0)?.taken.secondsSinceUnixEpoch, 40)
        XCTAssertTrue(samples.get(0)?.value.value != 0)
        XCTAssertEqual(samples.get(1)?.taken.secondsSinceUnixEpoch, 80)
        XCTAssertTrue(samples.get(1)?.value.value != 0)
        print(samples.description)
    }
    
    public func test_analysisrunner_smoothedLinearModel() {
        let srcData = SampleList(25)
        srcData.push(secondsSinceUnixEpoch: 0, value: RSSI(-68))
        srcData.push(secondsSinceUnixEpoch: 10, value: RSSI(-68))
        srcData.push(secondsSinceUnixEpoch: 20, value: RSSI(-68))
        srcData.push(secondsSinceUnixEpoch: 30, value: RSSI(-68))
        srcData.push(secondsSinceUnixEpoch: 40, value: RSSI(-68))
        srcData.push(secondsSinceUnixEpoch: 50, value: RSSI(-68))
        srcData.push(secondsSinceUnixEpoch: 60, value: RSSI(-68))
        let src = DummyRSSISource(SampledID(1234), srcData)
        
        let distanceAnalyser = SmoothedLinearModelAnalyser(interval: 10, smoothingWindow: TimeInterval.minute, model: SmoothedLinearModel(intercept: -17.7275, coefficient: -0.2754))
        let myDelegate = DummyDistanceDelegate()
        
        let adm = AnalysisDelegateManager([myDelegate])
        let apm = AnalysisProviderManager([distanceAnalyser])
        
        let runner = AnalysisRunner(apm, adm, defaultListSize: 25)

        // run at different times and ensure that it only actually runs once
        src.run(60, 10, runner)
        src.run(60, 20, runner)
        src.run(60, 30, runner)
        src.run(60, 40, runner)
        src.run(60, 50, runner)
        src.run(60, 60, runner) // Runs here, because we have data for 0,10,20,>>30<<,40,50,60 <- next run time based on this 'latest' data time

        XCTAssertEqual(myDelegate.lastSampledID, SampledID(1234))
        let samples = myDelegate.samples
        XCTAssertEqual(samples.size(), 1)
        let sample = samples.get(0)!
        XCTAssertEqual(sample.taken.secondsSinceUnixEpoch, 30)
        XCTAssertEqual(sample.value.value, 1.0, accuracy: 0.001)
        print(samples.description)
    }
    
    private class DummyRSSISource {
        private let sampledID: SampledID
        private let data: SampleList
        
        public init(_ sampledID: SampledID, _ data: SampleList) {
            self.sampledID = sampledID
            self.data = data
        }
        
        public func run(_ timeTo: Int64, _ runner: AnalysisRunner) {
            runner.variantSet.removeAll()
            let i = data.makeIterator()
            while let v = i.next() {
                if (v.taken.secondsSinceUnixEpoch <= timeTo) {
                    runner.newSample(sampled: sampledID, item: v)
                }
            }
            runner.run(timeNow: Date(timeIntervalSince1970: Double(timeTo)))
        }

        public func run(_ sampleTimeTo: Int64, _ analysisTimeTo: Int64, _ runner: AnalysisRunner) {
            runner.variantSet.removeAll()
            let i = data.makeIterator()
            while let v = i.next() {
                if (v.taken.secondsSinceUnixEpoch <= sampleTimeTo) {
                    runner.newSample(sampled: sampledID, item: v)
                }
            }
            runner.run(timeNow: Date(timeIntervalSince1970: Double(analysisTimeTo)))
        }
    }
    
    private class DummyDistanceDelegate: AnalysisDelegate {
        public var lastSampledID: SampledID = SampledID(0)
        
        public init() {
            super.init(inputType: ValueType(describing: Distance.self), listSize: 25)
        }
        
        public override func newSample(sampled: SampledID, item: Sample) {
            super.newSample(sampled: sampled, item: item)
            lastSampledID = sampled
        }
    }
}
