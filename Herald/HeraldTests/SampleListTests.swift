//
//  SampleListTests.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//



import XCTest
@testable import Herald

class SampleListTests: XCTestCase {

    func test_sample_basic() {
        let s = Sample(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        XCTAssertEqual(s.taken.secondsSinceUnixEpoch, 1234)
        XCTAssertEqual(s.value.value, -55)
    }

    
    func test_sample_from_parts() {
        let s = Sample(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        let s2 = Sample(taken: s.taken, value: s.value)
        XCTAssertEqual(s2.taken.secondsSinceUnixEpoch, 1234)
        XCTAssertEqual(s2.value.value, -55)
    }

    
    func test_sample_from_parts_deep() {
        let s = Sample(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        let s2 = Sample(taken: Date(timeIntervalSince1970: s.taken.timeIntervalSince1970), value: s.value)
        XCTAssertEqual(s2.taken.secondsSinceUnixEpoch, 1234)
        XCTAssertEqual(s2.value.value, -55)
    }

    func test_sample_copy_ctor() {
        let s = Sample(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        let s2 = Sample(sample: s)
        XCTAssertEqual(s2.taken.secondsSinceUnixEpoch, 1234)
        XCTAssertEqual(s2.value.value, -55)
    }

    func test_sample_copy_assign() {
        let s = Sample(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        let s2 = s
        XCTAssertEqual(s2.taken.secondsSinceUnixEpoch, 1234)
        XCTAssertEqual(s2.value.value, -55)
    }

    func test_samplelist_empty() {
        let sl = SampleList(5)
        XCTAssertEqual(sl.size(), 0)
    }
    
    func test_samplelist_notfull() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        XCTAssertEqual(sl.size(), 3)
        XCTAssertEqual(sl.get(0)!.value.value, -55)
        XCTAssertEqual(sl.get(1)!.value.value, -60)
        XCTAssertEqual(sl.get(2)!.value.value, -58)
    }

    func test_samplelist_exactlyfull() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        XCTAssertEqual(sl.size(), 5)
        XCTAssertEqual(sl.get(0)!.value.value, -55)
        XCTAssertEqual(sl.get(1)!.value.value, -60)
        XCTAssertEqual(sl.get(2)!.value.value, -58)
        XCTAssertEqual(sl.get(3)!.value.value, -61)
        XCTAssertEqual(sl.get(4)!.value.value, -54)
    }

    func test_samplelist_oneover() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        sl.push(secondsSinceUnixEpoch: 1302, value: RSSI(-47))
        XCTAssertEqual(sl.size(), 5)
        XCTAssertEqual(sl.get(0)!.value.value, -60)
        XCTAssertEqual(sl.get(1)!.value.value, -58)
        XCTAssertEqual(sl.get(2)!.value.value, -61)
        XCTAssertEqual(sl.get(3)!.value.value, -54)
        XCTAssertEqual(sl.get(4)!.value.value, -47)
    }

    func test_samplelist_threeover() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        sl.push(secondsSinceUnixEpoch: 1302, value: RSSI(-47))
        sl.push(secondsSinceUnixEpoch: 1304, value: RSSI(-48))
        sl.push(secondsSinceUnixEpoch: 1305, value: RSSI(-49))
        XCTAssertEqual(sl.size(), 5)
        XCTAssertEqual(sl.get(0)!.value.value, -61)
        XCTAssertEqual(sl.get(1)!.value.value, -54)
        XCTAssertEqual(sl.get(2)!.value.value, -47)
        XCTAssertEqual(sl.get(3)!.value.value, -48)
        XCTAssertEqual(sl.get(4)!.value.value, -49)
    }

    func test_samplelist_justunderfullagain() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        sl.push(secondsSinceUnixEpoch: 1302, value: RSSI(-47))
        sl.push(secondsSinceUnixEpoch: 1304, value: RSSI(-48))
        sl.push(secondsSinceUnixEpoch: 1305, value: RSSI(-49))
        sl.push(secondsSinceUnixEpoch: 1306, value: RSSI(-45))
        XCTAssertEqual(sl.size(), 5)
        XCTAssertEqual(sl.get(0)!.value.value, -54)
        XCTAssertEqual(sl.get(1)!.value.value, -47)
        XCTAssertEqual(sl.get(2)!.value.value, -48)
        XCTAssertEqual(sl.get(3)!.value.value, -49)
        XCTAssertEqual(sl.get(4)!.value.value, -45)
    }

    func test_samplelist_fullagain() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        sl.push(secondsSinceUnixEpoch: 1302, value: RSSI(-47))
        sl.push(secondsSinceUnixEpoch: 1304, value: RSSI(-48))
        sl.push(secondsSinceUnixEpoch: 1305, value: RSSI(-49))
        sl.push(secondsSinceUnixEpoch: 1306, value: RSSI(-45))
        sl.push(secondsSinceUnixEpoch: 1307, value: RSSI(-44))
        XCTAssertEqual(sl.size(), 5)
        XCTAssertEqual(sl.get(0)!.value.value, -47)
        XCTAssertEqual(sl.get(1)!.value.value, -48)
        XCTAssertEqual(sl.get(2)!.value.value, -49)
        XCTAssertEqual(sl.get(3)!.value.value, -45)
        XCTAssertEqual(sl.get(4)!.value.value, -44)
    }

    // MARK: - Now handle deletion by time
    
    func test_samplelist_clearoneold() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        sl.push(secondsSinceUnixEpoch: 1302, value: RSSI(-47))
        sl.push(secondsSinceUnixEpoch: 1304, value: RSSI(-48))
        sl.push(secondsSinceUnixEpoch: 1305, value: RSSI(-49))
        sl.push(secondsSinceUnixEpoch: 1306, value: RSSI(-45))
        sl.push(secondsSinceUnixEpoch: 1307, value: RSSI(-44))
        sl.clearBeforeDate(Date(timeIntervalSince1970: 1304))
        XCTAssertEqual(sl.size(), 4)
        XCTAssertEqual(sl.get(0)!.value.value, -48)
        XCTAssertEqual(sl.get(1)!.value.value, -49)
        XCTAssertEqual(sl.get(2)!.value.value, -45)
        XCTAssertEqual(sl.get(3)!.value.value, -44)
    }

    func test_samplelist_clearfourold() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        sl.push(secondsSinceUnixEpoch: 1302, value: RSSI(-47))
        sl.push(secondsSinceUnixEpoch: 1304, value: RSSI(-48))
        sl.push(secondsSinceUnixEpoch: 1305, value: RSSI(-49))
        sl.push(secondsSinceUnixEpoch: 1306, value: RSSI(-45))
        sl.push(secondsSinceUnixEpoch: 1307, value: RSSI(-44))
        sl.clearBeforeDate(Date(timeIntervalSince1970: 1307))
        XCTAssertEqual(sl.size(), 1)
        XCTAssertEqual(sl.get(0)!.value.value, -44)
    }

    func test_samplelist_clearallold() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        sl.push(secondsSinceUnixEpoch: 1302, value: RSSI(-47))
        sl.push(secondsSinceUnixEpoch: 1304, value: RSSI(-48))
        sl.push(secondsSinceUnixEpoch: 1305, value: RSSI(-49))
        sl.push(secondsSinceUnixEpoch: 1306, value: RSSI(-45))
        sl.push(secondsSinceUnixEpoch: 1307, value: RSSI(-44))
        sl.clearBeforeDate(Date(timeIntervalSince1970: 1308))
        XCTAssertEqual(sl.size(), 0)
    }
    
    // MARK: - Now handle clear()

    func test_samplelist_clear() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        sl.push(secondsSinceUnixEpoch: 1302, value: RSSI(-47))
        sl.push(secondsSinceUnixEpoch: 1304, value: RSSI(-48))
        sl.push(secondsSinceUnixEpoch: 1305, value: RSSI(-49))
        sl.push(secondsSinceUnixEpoch: 1306, value: RSSI(-45))
        sl.push(secondsSinceUnixEpoch: 1307, value: RSSI(-44))
        sl.clear()
        XCTAssertEqual(sl.size(), 0)
    }

    // MARK: - Now handle iterators
    
    func test_samplelist_iterator_empty() {
        let sl = SampleList(5)
       XCTAssertNil(sl.makeIterator().next())
    }

    func test_samplelist_iterator_single() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        let iter = sl.makeIterator()
        XCTAssertEqual(iter.next()!.value.value, -55)
        XCTAssertNil(iter.next())
    }

    func test_samplelist_iterator_three() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        let iter = sl.makeIterator()
        XCTAssertEqual(iter.next()!.value.value, -55)
        XCTAssertEqual(iter.next()!.value.value, -60)
        XCTAssertEqual(iter.next()!.value.value, -58)
        XCTAssertNil(iter.next())
    }

    func test_samplelist_iterator_exactlyfull() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        let iter = sl.makeIterator()
        XCTAssertEqual(iter.next()!.value.value, -55)
        XCTAssertEqual(iter.next()!.value.value, -60)
        XCTAssertEqual(iter.next()!.value.value, -58)
        XCTAssertEqual(iter.next()!.value.value, -61)
        XCTAssertEqual(iter.next()!.value.value, -54)
        XCTAssertNil(iter.next())
    }

    func test_samplelist_iterator_oneover() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        sl.push(secondsSinceUnixEpoch: 1302, value: RSSI(-47))
        let iter = sl.makeIterator()
        XCTAssertEqual(iter.next()!.value.value, -60)
        XCTAssertEqual(iter.next()!.value.value, -58)
        XCTAssertEqual(iter.next()!.value.value, -61)
        XCTAssertEqual(iter.next()!.value.value, -54)
        XCTAssertEqual(iter.next()!.value.value, -47)
        XCTAssertNil(iter.next())
    }

    func test_samplelist_iterator_twoover() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        sl.push(secondsSinceUnixEpoch: 1302, value: RSSI(-47))
        sl.push(secondsSinceUnixEpoch: 1304, value: RSSI(-48))
        let iter = sl.makeIterator()
        XCTAssertEqual(iter.next()!.value.value, -58)
        XCTAssertEqual(iter.next()!.value.value, -61)
        XCTAssertEqual(iter.next()!.value.value, -54)
        XCTAssertEqual(iter.next()!.value.value, -47)
        XCTAssertEqual(iter.next()!.value.value, -48)
        XCTAssertNil(iter.next())
    }

    
    func test_samplelist_iterator_threeover() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        sl.push(secondsSinceUnixEpoch: 1302, value: RSSI(-47))
        sl.push(secondsSinceUnixEpoch: 1304, value: RSSI(-48))
        sl.push(secondsSinceUnixEpoch: 1305, value: RSSI(-49))
        let iter = sl.makeIterator()
        XCTAssertEqual(iter.next()!.value.value, -61)
        XCTAssertEqual(iter.next()!.value.value, -54)
        XCTAssertEqual(iter.next()!.value.value, -47)
        XCTAssertEqual(iter.next()!.value.value, -48)
        XCTAssertEqual(iter.next()!.value.value, -49)
        XCTAssertNil(iter.next())
    }

    func test_samplelist_iterator_justunderfullagain() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        sl.push(secondsSinceUnixEpoch: 1302, value: RSSI(-47))
        sl.push(secondsSinceUnixEpoch: 1304, value: RSSI(-48))
        sl.push(secondsSinceUnixEpoch: 1305, value: RSSI(-49))
        sl.push(secondsSinceUnixEpoch: 1306, value: RSSI(-45))
        let iter = sl.makeIterator()
        XCTAssertEqual(iter.next()!.value.value, -54)
        XCTAssertEqual(iter.next()!.value.value, -47)
        XCTAssertEqual(iter.next()!.value.value, -48)
        XCTAssertEqual(iter.next()!.value.value, -49)
        XCTAssertEqual(iter.next()!.value.value, -45)
        XCTAssertNil(iter.next())
    }

    func test_samplelist_iterator_fullagain() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        sl.push(secondsSinceUnixEpoch: 1302, value: RSSI(-47))
        sl.push(secondsSinceUnixEpoch: 1304, value: RSSI(-48))
        sl.push(secondsSinceUnixEpoch: 1305, value: RSSI(-49))
        sl.push(secondsSinceUnixEpoch: 1306, value: RSSI(-45))
        sl.push(secondsSinceUnixEpoch: 1307, value: RSSI(-44))
        let iter = sl.makeIterator()
        XCTAssertEqual(iter.next()!.value.value, -47)
        XCTAssertEqual(iter.next()!.value.value, -48)
        XCTAssertEqual(iter.next()!.value.value, -49)
        XCTAssertEqual(iter.next()!.value.value, -45)
        XCTAssertEqual(iter.next()!.value.value, -44)
        XCTAssertNil(iter.next())
    }

    func test_samplelist_iterator_cleared() {
        let sl = SampleList(5)
        sl.push(secondsSinceUnixEpoch: 1234, value: RSSI(-55))
        sl.push(secondsSinceUnixEpoch: 1244, value: RSSI(-60))
        sl.push(secondsSinceUnixEpoch: 1265, value: RSSI(-58))
        sl.push(secondsSinceUnixEpoch: 1282, value: RSSI(-61))
        sl.push(secondsSinceUnixEpoch: 1294, value: RSSI(-54))
        sl.push(secondsSinceUnixEpoch: 1302, value: RSSI(-47))
        sl.push(secondsSinceUnixEpoch: 1304, value: RSSI(-48))
        sl.push(secondsSinceUnixEpoch: 1305, value: RSSI(-49))
        sl.push(secondsSinceUnixEpoch: 1306, value: RSSI(-45))
        sl.push(secondsSinceUnixEpoch: 1307, value: RSSI(-44))
        sl.clear()
        let iter = sl.makeIterator()
        XCTAssertNil(iter.next())
    }
    
    // MARK: - Now handle other container functionality required
    
    func test_sample_init() {
        let sample = Sample(secondsSinceUnixEpoch: 10, value: RSSI(-55))
        XCTAssertEqual(sample.taken.secondsSinceUnixEpoch, 10)
        XCTAssertEqual(sample.value.value, -55)
    }

    func test_samplelist_init_list() {
        let sample1 = Sample(secondsSinceUnixEpoch: 10, value: RSSI(-55))
        let sample2 = Sample(secondsSinceUnixEpoch: 20, value: RSSI(-65))
        let sample3 = Sample(secondsSinceUnixEpoch: 30, value: RSSI(-75))
        let sl = SampleList(3, samples: [sample1, sample2, sample3])
        XCTAssertEqual(sl.get(0)!.taken.secondsSinceUnixEpoch, 10)
        XCTAssertEqual(sl.get(0)!.value.value, -55)
        XCTAssertEqual(sl.get(1)!.taken.secondsSinceUnixEpoch, 20)
        XCTAssertEqual(sl.get(1)!.value.value, -65)
        XCTAssertEqual(sl.get(2)!.taken.secondsSinceUnixEpoch, 30)
        XCTAssertEqual(sl.get(2)!.value.value, -75)
    }

    func test_samplelist_init_deduced() {
        let sample1 = Sample(secondsSinceUnixEpoch: 10, value: RSSI(-55))
        let sample2 = Sample(secondsSinceUnixEpoch: 20, value: RSSI(-65))
        let sample3 = Sample(secondsSinceUnixEpoch: 30, value: RSSI(-75))
        let sl = SampleList(samples: [sample1, sample2, sample3])
        XCTAssertEqual(sl.get(0)!.taken.secondsSinceUnixEpoch, 10)
        XCTAssertEqual(sl.get(0)!.value.value, -55)
        XCTAssertEqual(sl.get(1)!.taken.secondsSinceUnixEpoch, 20)
        XCTAssertEqual(sl.get(1)!.value.value, -65)
        XCTAssertEqual(sl.get(2)!.taken.secondsSinceUnixEpoch, 30)
        XCTAssertEqual(sl.get(2)!.value.value, -75)
    }

    func test_samplelist_init_alldeduced() {
        let sl = SampleList(samples: [
                                    Sample(secondsSinceUnixEpoch: 10, value: RSSI(-55)),
                                    Sample(secondsSinceUnixEpoch: 20, value: RSSI(-65)),
                                    Sample(secondsSinceUnixEpoch: 30, value: RSSI(-75))])
        XCTAssertEqual(sl.get(0)!.taken.secondsSinceUnixEpoch, 10)
        XCTAssertEqual(sl.get(0)!.value.value, -55)
        XCTAssertEqual(sl.get(1)!.taken.secondsSinceUnixEpoch, 20)
        XCTAssertEqual(sl.get(1)!.value.value, -65)
        XCTAssertEqual(sl.get(2)!.taken.secondsSinceUnixEpoch, 30)
        XCTAssertEqual(sl.get(2)!.value.value, -75)
    }
}
