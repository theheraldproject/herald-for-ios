//
//  VenueDiaryEventTests.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class VenueDiaryEventTests: XCTestCase {

    func testSingleEvent() throws {
        // Set up
        let evt = VenueDiaryEvent(country: 826,state: 4, venue: 12345, firstSeen: K.date("2020-09-24T10:00:00+0000")!)
        
        // Basic checks (this test only)
        XCTAssertEqual(826,evt.getCountry())
        XCTAssertEqual(4,evt.getState())
        XCTAssertEqual(12345,evt.getCode())
        
        // Test specific checks
        XCTAssertFalse(evt.isRecordable())
        XCTAssertFalse(evt.isClosed())
    }
    func testTooShortForRecordingEvent() throws {
        // Set up
        let firstDate = K.date("2020-09-24T10:00:00+0000")!
        let evt = VenueDiaryEvent(country: 826,state: 4, venue: 12345, firstSeen: firstDate)
        
        // Add a second check in underneath the default limit, minus a second (boundary check)
        let secondDateTime: Date = firstDate + BLESensorConfiguration.venueCheckInTimeLimit - TimeInterval(1)
        let validToExtendEvent = evt.addPresenceIfSameEvent(secondDateTime)
        
        // Test specific checks
        XCTAssertTrue(validToExtendEvent)
        XCTAssertFalse(evt.isRecordable())
        XCTAssertFalse(evt.isClosed())
    }
    func testRecordableButNotClosedEvent() throws {
        // Set up
        let firstDate = K.date("2020-09-24T10:00:00+0000")!
        let evt = VenueDiaryEvent(country: 826,state: 4, venue: 12345, firstSeen: firstDate)
        
        // Add a second check in above the default limit, plus a second (boundary check)
        let secondDateTime: Date = firstDate + BLESensorConfiguration.venueCheckInTimeLimit + TimeInterval(1)
        let validToExtendEvent = evt.addPresenceIfSameEvent(secondDateTime)
        
        // WARNING: Test assumes CheckOutTimeLimit is GREATER THAN CheckInTimeLimit
        
        // Test specific checks
        XCTAssertTrue(validToExtendEvent)
        XCTAssertTrue(evt.isRecordable())
        XCTAssertFalse(evt.isClosed())
    }
    func testRecordableAndClosedEvent() throws {
        // Set up
        let firstDate = K.date("2020-09-24T10:00:00+0000")!
        let evt = VenueDiaryEvent(country: 826,state: 4, venue: 12345, firstSeen: firstDate)
        
        // Add a second check in above the default limit, plus a second (boundary check)
        let secondDateTime: Date = firstDate + BLESensorConfiguration.venueCheckInTimeLimit + TimeInterval(1)
        let validToExtendEvent = evt.addPresenceIfSameEvent(secondDateTime)
        
        // Add a third event after the closed time limit
        let thirdDateTime: Date = secondDateTime + BLESensorConfiguration.venueCheckOutTimeLimit + TimeInterval(1)
        let validToExtendEventSecond = evt.addPresenceIfSameEvent(thirdDateTime)
        
        // WARNING: Test assumes CheckOutTimeLimit is GREATER THAN CheckInTimeLimit
        
        // Test specific checks
        XCTAssertTrue(validToExtendEvent)
        XCTAssertFalse(validToExtendEventSecond)
        XCTAssertTrue(evt.isRecordable())
        XCTAssertTrue(evt.isClosed())
    }
    func testRecordableAndClosedEventViaUpdate() throws {
        // Set up
        let firstDate = K.date("2020-09-24T10:00:00+0000")!
        let evt = VenueDiaryEvent(country: 826,state: 4, venue: 12345, firstSeen: firstDate)
        
        // Add a second check in above the default limit, plus a second (boundary check)
        let secondDateTime: Date = firstDate + BLESensorConfiguration.venueCheckInTimeLimit + TimeInterval(1)
        let validToExtendEvent = evt.addPresenceIfSameEvent(secondDateTime)
        
        // Check state after event
        let thirdDateTime: Date = secondDateTime + BLESensorConfiguration.venueCheckOutTimeLimit + TimeInterval(1)
        evt.updateStateIfNecessary(at: thirdDateTime)
        
        // WARNING: Test assumes CheckOutTimeLimit is GREATER THAN CheckInTimeLimit
        
        // Test specific checks
        XCTAssertTrue(validToExtendEvent)
        XCTAssertTrue(evt.isRecordable())
        XCTAssertTrue(evt.isClosed())
    }
    func testNotRecordableAndClosedEvent() throws {
        // Set up
        let firstDate = K.date("2020-09-24T10:00:00+0000")!
        let evt = VenueDiaryEvent(country: 826,state: 4, venue: 12345, firstSeen: firstDate)
        
        // Add a second check in above the CLOSED limit, plus a second (boundary check)
        let secondDateTime: Date = firstDate + BLESensorConfiguration.venueCheckOutTimeLimit + TimeInterval(1)
        let validToExtendEvent = evt.addPresenceIfSameEvent(secondDateTime)
        
        // WARNING: Test assumes CheckOutTimeLimit is GREATER THAN CheckInTimeLimit
        
        // Test specific checks
        XCTAssertFalse(validToExtendEvent)
        XCTAssertFalse(evt.isRecordable())
        XCTAssertTrue(evt.isClosed())
    }
}
