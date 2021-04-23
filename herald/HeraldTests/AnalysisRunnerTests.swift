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
        var value: Int { get { Int(doubleValue()) }}
        init(_ value: Int) {
            super.init(doubleValue: Double(value))
        }
    }

    private class RSSI: DoubleValue {
        var value: Int { get { Int(doubleValue()) }}
        init(_ value: Int) {
            super.init(doubleValue: Double(value))
        }
    }

    func test_listmanager() {
        let listManager = ListManager<RSSI>(10)
        let _ = listManager.list(SampledID(1))
        let _ = listManager.list(SampledID(2))
        let _ = listManager.list(SampledID(2))
        XCTAssertEqual(listManager.sampledIDs().count, 2)
        listManager.remove(SampledID(1))
        XCTAssertEqual(listManager.sampledIDs().count, 1)
        var iterator = listManager.sampledIDs().makeIterator()
        XCTAssertEqual(iterator.next()!, 2)
        listManager.clear()
        XCTAssertEqual(listManager.sampledIDs().count, 0)
    }
    
    func test_swift_type_system() {
        let a: DoubleValue = Int8(1)
        let b: DoubleValue = RSSI(2)
        print(type(of: a))
        print(type(of: b))
    }

    //
    //    @Test
    //    public void variantset_listmanager() {
    //        final VariantSet variantSet = new VariantSet(15);
    //        final ListManager<RSSI> listManagerRSSI = variantSet.listManager(RSSI.class);
    //        final ListManager<Int8> listManagerInt8 = variantSet.listManager(Int8.class);
    //        assertEquals(variantSet.size(), 2);
    //        assertEquals(listManagerRSSI.size(), 0);
    //        assertEquals(listManagerInt8.size(), 0);
    //
    //        final SampleList<RSSI> sampleListRSSI = listManagerRSSI.list(new SampledID(1234));
    //        final SampleList<Int8> sampleListInt8 = listManagerInt8.list(new SampledID(5678));
    //        assertEquals(sampleListRSSI.size(), 0);
    //        assertEquals(sampleListInt8.size(), 0);
    //
    //        sampleListRSSI.push(new Sample<RSSI>(0, new RSSI(12)));
    //        sampleListInt8.push(new Sample<Int8>(10, new Int8(14)));
    //        variantSet.push(new SampledID(5678), new Sample<Int8>(20, new Int8(15)));
    //        assertEquals(variantSet.listManager(RSSI.class, new SampledID(1234)).size(), 1);
    //        assertEquals(variantSet.listManager(Int8.class, new SampledID(5678)).size(), 2);
    //
    //        variantSet.remove(new SampledID(1234));
    //        assertEquals(listManagerRSSI.size(), 0);
    //        assertEquals(listManagerInt8.size(), 1);
    //
    //        variantSet.remove(RSSI.class);
    //        assertEquals(variantSet.size(), 1);
    //    }
    //
    //    /// [Who]   As a DCT app developer
    //    /// [What]  I want to link my live application data to an analysis runner easily
    //    /// [Value] So I don't have to write plumbing code for Herald itself
    //    ///
    //    /// [Who]   As a DCT app developer
    //    /// [What]  I want to periodically run analysis aggregates automatically
    //    /// [Value] So I don't miss any information, and have accurate, regular, samples
    //    @Test
    //    public void analysisrunner_basic() {
    //        final SampleList<RSSI> srcData = new SampleList<>(25);
    //        srcData.push(10, new RSSI(-55));
    //        srcData.push(20, new RSSI(-55));
    //        srcData.push(30, new RSSI(-55));
    //        srcData.push(40, new RSSI(-55));
    //        srcData.push(50, new RSSI(-55));
    //        srcData.push(60, new RSSI(-55));
    //        srcData.push(70, new RSSI(-55));
    //        srcData.push(80, new RSSI(-55));
    //        srcData.push(90, new RSSI(-55));
    //        srcData.push(100, new RSSI(-55));
    //        final DummyRSSISource src = new DummyRSSISource(new SampledID(1234), srcData);
    //
    //        final AnalysisProvider<RSSI, Distance> distanceAnalyser = new FowlerBasicAnalyser(30, -50, -24);
    //        final AnalysisDelegate<Distance> myDelegate = new DummyDistanceDelegate();
    //
    //        final AnalysisDelegateManager adm = new AnalysisDelegateManager(myDelegate);
    //        final AnalysisProviderManager apm = new AnalysisProviderManager(distanceAnalyser);
    //
    //        final AnalysisRunner runner = new AnalysisRunner(apm, adm, 25);
    //
    //        // run at different times and ensure that it only actually runs three times (sample size == 3)
    //        src.run(20, runner);
    //        src.run(40, runner); // Runs here, because we have data for 10,20,>>30<<,40 <- next run time based on this 'latest' data time
    //        src.run(60, runner);
    //        src.run(80, runner); // Runs here because we have extra data for 50,60,>>70<<,80 <- next run time based on this 'latest' data time
    //        src.run(95, runner);
    //
    //
    //        assertEquals(((DummyDistanceDelegate) myDelegate).lastSampledID.value, 1234);
    //        final SampleList<Distance> samples = myDelegate.samples();
    //        // didn't reach 4x30 seconds, so no tenth sample, and didn't run at 60 because previous run was at time 40
    //        assertEquals(samples.size(), 2);
    //        assertEquals(samples.get(0).taken().secondsSinceUnixEpoch(), 40);
    //        assertTrue(samples.get(0).value().value != 0.0);
    //        assertEquals(samples.get(1).taken().secondsSinceUnixEpoch(), 80);
    //        assertTrue(samples.get(1).value().value != 0.0);
    //        System.err.println(samples);
    //    }
    //
    //    @Test
    //    public void analysisrunner_smoothedLinearModel() {
    //        final SampleList<RSSI> srcData = new SampleList<>(25);
    //        srcData.push(0, new RSSI(-68));
    //        srcData.push(10, new RSSI(-68));
    //        srcData.push(20, new RSSI(-68));
    //        srcData.push(30, new RSSI(-68));
    //        srcData.push(40, new RSSI(-68));
    //        srcData.push(50, new RSSI(-68));
    //        srcData.push(60, new RSSI(-68));
    //        final DummyRSSISource src = new DummyRSSISource(new SampledID(1234), srcData);
    //
    //        final AnalysisProvider<RSSI, Distance> distanceAnalyser = new SmoothedLinearModelAnalyser(10, TimeInterval.minute, -17.7275, -0.2754);
    //        final AnalysisDelegate<Distance> myDelegate = new DummyDistanceDelegate();
    //
    //        final AnalysisDelegateManager adm = new AnalysisDelegateManager(myDelegate);
    //        final AnalysisProviderManager apm = new AnalysisProviderManager(distanceAnalyser);
    //        final AnalysisRunner runner = new AnalysisRunner(apm, adm, 25);
    //
    //        // run at different times and ensure that it only actually runs three times (sample size == 3)
    //        src.run(60, 10, runner);
    //        src.run(60, 20, runner);
    //        src.run(60, 30, runner); // Runs here, because we have data for 0,10,20,>>30<<,40,50,60 <- next run time based on this 'latest' data time
    //        src.run(60, 40, runner);
    //
    //
    //        assertEquals(((DummyDistanceDelegate) myDelegate).lastSampledID.value, 1234);
    //        final SampleList<Distance> samples = myDelegate.samples();
    //        // didn't reach 4x30 seconds, so no tenth sample, and didn't run at 60 because previous run was at time 40
    //        assertEquals(samples.size(), 1);
    //        assertEquals(samples.get(0).taken().secondsSinceUnixEpoch(), 30);
    //        assertEquals(samples.get(0).value().value, 1.0, 0.001);
    //    }
    //
    //    private final static class DummyRSSISource {
    //        private final SampledID sampledID;
    //        private final SampleList<RSSI> data;
    //
    //        public DummyRSSISource(final SampledID sampledID, final SampleList<RSSI> data) {
    //            this.sampledID = sampledID;
    //            this.data = data;
    //        }
    //
    //        public void run(final long timeTo, final AnalysisRunner runner) {
    //            for (final Sample<RSSI> v : data) {
    //                if (v.taken().secondsSinceUnixEpoch() <= timeTo) {
    //                    runner.newSample(sampledID, v);
    //                }
    //            }
    //            runner.run(new Date(timeTo));
    //        }
    //
    //        public void run(final long sampleTimeTo, final long analysisTimeTo, final AnalysisRunner runner) {
    //            for (final Sample<RSSI> v : data) {
    //                if (v.taken().secondsSinceUnixEpoch() <= sampleTimeTo) {
    //                    runner.newSample(sampledID, v);
    //                }
    //            }
    //            runner.run(new Date(analysisTimeTo));
    //        }
    //    }
    //
    //    private final static class DummyDistanceDelegate implements AnalysisDelegate<Distance> {
    //        private SampledID lastSampledID = new SampledID(0);
    //        private SampleList<Distance> distances = new SampleList<>(25);
    //
    //        @Override
    //        public void newSample(SampledID sampled, Sample<Distance> item) {
    //            this.lastSampledID = sampled;
    //            distances.push(item);
    //        }
    //
    //        @Override
    //        public Class<Distance> inputType() {
    //            return Distance.class;
    //        }
    //
    //        @Override
    //        public void reset() {
    //            distances.clear();
    //            lastSampledID = new SampledID(0);
    //        }
    //
    //        @Override
    //        public SampleList<Distance> samples() {
    //            return distances;
    //        }
    //
    //        public SampledID lastSampledID() {
    //            return lastSampledID;
    //        }
    //    }

}
