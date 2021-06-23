//
//  RangesTests.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//



import XCTest
@testable import Herald

class RangesTests: XCTestCase {

    private class Int32: DoubleValue {
    }

    func test_ranges_iterator_proxy() {
        let ages = SampleList(5)
        ages.push(secondsSinceUnixEpoch: 10, value: Int32(12))
        ages.push(secondsSinceUnixEpoch: 20, value: Int32(14))
        ages.push(secondsSinceUnixEpoch: 30, value: Int32(19))
        ages.push(secondsSinceUnixEpoch: 40, value: Int32(45))
        ages.push(secondsSinceUnixEpoch: 50, value: Int32(66))
        let proxy = ages.filter(NoOp())
        XCTAssertEqual(proxy.next()!.value.value, 12)
        XCTAssertEqual(proxy.next()!.value.value, 14)
        XCTAssertEqual(proxy.next()!.value.value, 19)
        XCTAssertEqual(proxy.next()!.value.value, 45)
        XCTAssertEqual(proxy.next()!.value.value, 66)
        XCTAssertNil(proxy.next())
    }

    func test_ranges_filter_typed() {
        let workingAge = InRange(18, 65)
        let ages = SampleList(5)
        ages.push(secondsSinceUnixEpoch: 10, value: Int32(12))
        ages.push(secondsSinceUnixEpoch: 20, value: Int32(14))
        ages.push(secondsSinceUnixEpoch: 30, value: Int32(19))
        ages.push(secondsSinceUnixEpoch: 40, value: Int32(45))
        ages.push(secondsSinceUnixEpoch: 50, value: Int32(66))
        let proxy = ages.filter(workingAge)
        XCTAssertEqual(proxy.next()!.value.value, 19)
        XCTAssertEqual(proxy.next()!.value.value, 45)
        XCTAssertNil(proxy.next())
    }

    func test_ranges_filter_generic() {
        let workingAge = InRange(18, 65)
        let ages = SampleList(5)
        ages.push(secondsSinceUnixEpoch: 10, value: Int32(12))
        ages.push(secondsSinceUnixEpoch: 20, value: Int32(14))
        ages.push(secondsSinceUnixEpoch: 30, value: Int32(19))
        ages.push(secondsSinceUnixEpoch: 40, value: Int32(45))
        ages.push(secondsSinceUnixEpoch: 50, value: Int32(66))
        let workingAges = ages.filter(workingAge).toView()
        let iter = workingAges.makeIterator()
        XCTAssertEqual(iter.next()!.value.value, 19)
        XCTAssertEqual(iter.next()!.value.value, 45)
        XCTAssertNil(iter.next())
        XCTAssertEqual(workingAges.size(), 2)
        XCTAssertEqual(workingAges.get(0)!.value.value, 19)
        XCTAssertEqual(workingAges.get(1)!.value.value, 45)
    }

    func test_ranges_filter_multi() {
        let workingAge = InRange(18, 65)
        let over21 = GreaterThan(21)
        let ages = SampleList(5)
        ages.push(secondsSinceUnixEpoch: 10, value: Int32(12))
        ages.push(secondsSinceUnixEpoch: 20, value: Int32(14))
        ages.push(secondsSinceUnixEpoch: 30, value: Int32(19))
        ages.push(secondsSinceUnixEpoch: 40, value: Int32(45))
        ages.push(secondsSinceUnixEpoch: 50, value: Int32(66))
        let workingAges = ages.filter(workingAge).filter(over21).toView()
        let iter = workingAges.makeIterator()
        XCTAssertEqual(iter.next()!.value.value, 45)
        XCTAssertNil(iter.next())
        XCTAssertEqual(workingAges.size(), 1)
        XCTAssertEqual(workingAges.get(0)!.value.value, 45)
    }

    func test_ranges_filter_rssisamples() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-9))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-100))
        let proxy = sl.filter(NoOp())
        XCTAssertEqual(proxy.next()!.value.value, -9)
        XCTAssertEqual(proxy.next()!.value.value, -60)
        XCTAssertEqual(proxy.next()!.value.value, -58)
        XCTAssertEqual(proxy.next()!.value.value, -61)
        XCTAssertEqual(proxy.next()!.value.value, -100)
        XCTAssertNil(proxy.next())
    }

    func test_ranges_filter_multi_rssisamples() {
        let valid = InRange(-99, -10)
        let strong = LessThan(-59)
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-9))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-100))
        let values = sl.filter(valid).filter(strong).toView()
        let iter = values.makeIterator()
        XCTAssertEqual(iter.next()!.value.value, -60)
        XCTAssertEqual(iter.next()!.value.value, -61)
        XCTAssertNil(iter.next())
        XCTAssertEqual(values.size(), 2)
        XCTAssertEqual(values.get(0)!.value.value, -60)
        XCTAssertEqual(values.get(1)!.value.value, -61)
    }
    
    func test_ranges_filter_multi_summarise() {
        let valid = InRange(-99, -10)
        let strong = LessThan(-59)
        let sl = SampleList(20)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-9))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-62))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-68))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-68))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-100))
        let values = sl.filter(valid).filter(strong).toView()
        let mean = Mean()
        let mode = Mode()
        let variance = Variance()
        let median = Median()
        let gaussian = Gaussian()
        
        // values = -60, -62, -68, -68
        let summary = values.aggregate([mean, mode, variance, median, gaussian])
        XCTAssertEqual(summary.get(Mean.self), -64.5)
        XCTAssertEqual(summary.get(Mode.self), -68)
        XCTAssertEqual(summary.get(Variance.self), 17)
        XCTAssertEqual(summary.get(Median.self), -65)
        XCTAssertEqual(summary.get(Gaussian.self), -64.5)
        XCTAssertEqual(gaussian.model.variance!, 17, accuracy: 0.00000001)
    }

    func test_ranges_filter_multi_since_summarise() {
        let valid = InRange(-99, -10)
        let strong = LessThan(-59)
        let afterPoint = Since(1245);
        let sl = SampleList(20)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-9))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-62))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-68))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-68))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-100))
        let values = sl.filter(afterPoint).filter(valid).filter(strong).toView()
        let mean = Mean()
        let mode = Mode()
        let variance = Variance()
        let median = Median()
        let gaussian = Gaussian()
        
        // values = -60, -68, -68
        let summary = values.aggregate([mean, mode, variance, median, gaussian])
        XCTAssertEqual(summary.get(Mean.self), -66)
        XCTAssertEqual(summary.get(Mode.self), -68)
        XCTAssertEqual(summary.get(Variance.self), 12)
        XCTAssertEqual(summary.get(Median.self), -68)
        XCTAssertEqual(summary.get(Gaussian.self), -66)
        XCTAssertEqual(gaussian.model.variance!, 12, accuracy: 0.00000001)
    }

    func test_ranges_distance_aggregate() {
        let valid = InRange(-99, -10)
        let strong = LessThan(-59)
        let afterPoint = Since(1245);
        let sl = SampleList(20)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-9))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-62))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-68))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-68))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-100))
        let values = sl.filter(afterPoint).filter(valid).filter(strong).toView()
        let mean = Mean()
        let mode = Mode()
        let variance = Variance()
        let median = Median()
        let gaussian = Gaussian()
        
        // values = -60, -68, -68
        let summary = values.aggregate([mean, mode, variance, median, gaussian])
        XCTAssertEqual(summary.get(Mean.self), -66)
        XCTAssertEqual(summary.get(Mode.self), -68)
        XCTAssertEqual(summary.get(Variance.self), 12)
        XCTAssertEqual(summary.get(Median.self), -68)
        XCTAssertEqual(summary.get(Gaussian.self), -66)
        XCTAssertEqual(gaussian.model.variance!, 12, accuracy: 0.00000001)
        
        let modeValue = summary.get(Mode.self)!
        let sd = sqrt(variance.reduce()!)
        

        // See second diagram at https://heraldprox.io/bluetooth/distance
        // i.e. https://heraldprox.io/images/distance-rssi-regression.png
        let toDistance = FowlerBasic(intercept: -50, coefficient: -24)
        let distance = sl.filter(afterPoint).filter(valid).filter(strong).filter(InRange(modeValue - 2 * sd, modeValue + 2 * sd)).aggregate([toDistance])
        XCTAssertEqual(distance.get(FowlerBasic.self)!, 5.6235, accuracy: 0.0005)
    }
    
    func test_ranges_risk_aggregate() {
        // First we simulate a list of actual distance samples over time, using a vector of pairs
        var sourceDistances: [Sample] = []
        sourceDistances.append(Sample(secondsSinceUnixEpoch: 1235, value: Distance(5.5)))
        sourceDistances.append(Sample(secondsSinceUnixEpoch: 1240, value: Distance(4.7)))
        sourceDistances.append(Sample(secondsSinceUnixEpoch: 1245, value: Distance(3.9)))
        sourceDistances.append(Sample(secondsSinceUnixEpoch: 1250, value: Distance(3.2)))
        sourceDistances.append(Sample(secondsSinceUnixEpoch: 1255, value: Distance(2.2)))
        sourceDistances.append(Sample(secondsSinceUnixEpoch: 1260, value: Distance(1.9)))
        sourceDistances.append(Sample(secondsSinceUnixEpoch: 1265, value: Distance(1.0)))
        sourceDistances.append(Sample(secondsSinceUnixEpoch: 1270, value: Distance(1.3)))
        sourceDistances.append(Sample(secondsSinceUnixEpoch: 1275, value: Distance(2.0)))
        sourceDistances.append(Sample(secondsSinceUnixEpoch: 1280, value: Distance(2.2)))

        // The below would be in your aggregate handling code...
        let distanceList = SampleList(2)
        
        // For n distances we maintain n-1 distance-risks in a list, and continuously add to it
        // (i.e. we don't recalculate risk over all previous time - too much data)
        // Instead we keep a distance-time number for this known 'contact' which lasts up to 15 minutes.
        // (i.e. when the mac address changes in Bluetooth)
        // We would then store that single risk-time number against that single contact ID - much less data!
        let timeScale = 1.0 // default is 1 second
        let distanceScale = 1.0 // default is 1 metre, not scaled
        let minimumDistanceClamp = 1.0 // As per Oxford Risk Model, anything < 1m ...
        let minimumRiskScoreAtClamp = 1.0 // ...equals a risk of 1.0, ...
        //let logScale = 1.0 // ... and falls logarithmically after that
        // NOTE: The above values are pick for testing and may not be epidemiologically accurate!
        let riskScorer = RiskAggregationBasic(
            timeScale: timeScale,
            distanceScale: distanceScale,
            minimumDistanceClamp: minimumDistanceClamp,
            minimumRiskScoreAtClamp: minimumRiskScoreAtClamp)

        // Now generate a sequence of Risk Scores over time
        var interScore = 0.0
        var firstNonZeroInterScore = 0.0
        for sourceDistance in sourceDistances {
            // A new distance has been calculated!
            distanceList.push(taken: sourceDistance.taken, value: sourceDistance.value)
            // Let's see if we have a new risk score!
            let riskSlice: Summary = distanceList.aggregate([riskScorer])
            // Add to our exposure risk for THIS contact
            // Note: We're NOT resetting over time, as the riskScorer will hold our total risk exposure from us.
            //       We could instead extract this slice, store it in a counter, and reset the risk Scorer if
            //       we needed to alter the value somehow or add the risk slices themselves to a new list.
            //       Instead, we only do this for each contact in total (i.e. up to 15 minutes per riskScorer).
            interScore = riskSlice.get(RiskAggregationBasic.self)!
            if (firstNonZeroInterScore == 0.0 && interScore > 0) {
                firstNonZeroInterScore = interScore;
            }
            print("RiskAggregationBasic inter score: \(interScore)")
        }

        // Now we have the total for our 'whole contact duration', not scaled for how far in the past it is
        let riskScore = riskScorer.reduce()!
        print("RiskAggregationBasic final score: \(interScore)")
        XCTAssertTrue(interScore > 0.0) // final inter score should be non zero
        XCTAssertTrue(riskScore > 0.0) // final score should be non zero
        XCTAssertTrue(riskScore > firstNonZeroInterScore) // should be additive over time too
    }
    //// TODO Given a list of risk-distance numbers, and the approximate final time of that contact, calculate
    ////      a risk score when the risk of infection drops off linearly over 14 days. (like COVID-19)
    ////      (Ideally we'd have a more robust epidemiological model, but this will suffice for example purposes)

}
