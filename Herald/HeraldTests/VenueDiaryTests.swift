//
//  VenueDiaryTests.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class VenueDiaryTests: XCTestCase {
    /// MARK:- Basic class functionality tests
    
    func testEmptyEventsList() throws {
        let diary = VenueDiary()
        XCTAssertEqual(0, diary.eventListCount())
        XCTAssertEqual(0, diary.uniqueVenueCount())
    }
    
    /// MARK:- Basic single venue tests
    
    func testSingleEventList() throws {
        let diary = VenueDiary()
        
        let evt1 = diary.findOrCreateEvent(country: 826,state: 4, venue: 12345, seen: K.date("2020-09-24T10:00:00+0000")!, with: nil)
        
        XCTAssertNotNil(evt1)
        XCTAssertEqual(1, diary.eventListCount())
        XCTAssertEqual(1, diary.uniqueVenueCount())
    }
    
    func testOneVenueTwoCheckins() throws {
        let diary = VenueDiary()
        
        let firstDate = K.date("2020-09-24T10:00:00+0000")!
        let evt1 = diary.findOrCreateEvent(country: 826,state: 4, venue: 12345, seen: firstDate, with: nil)
        let secondDateTime: Date = firstDate + BLESensorConfiguration.venueCheckInTimeLimit - TimeInterval(1)
        let evt2 = diary.findOrCreateEvent(country: 826,state: 4, venue: 12345, seen: secondDateTime, with: nil)
        
        XCTAssertNotNil(evt1)
        XCTAssertNotNil(evt2)
        XCTAssertEqual(1, diary.eventListCount())
        XCTAssertEqual(1, diary.uniqueVenueCount())
    }
    
    /// MARK:- Multiple venue tests
    func testTwoVenuesEventList() throws {
        let diary = VenueDiary()
        
        let firstDate = K.date("2020-09-24T10:00:00+0000")!
        let evt1 = diary.findOrCreateEvent(country: 826,state: 4, venue: 12345, seen: firstDate, with: nil)
        let secondDateTime: Date = firstDate + BLESensorConfiguration.venueCheckInTimeLimit - TimeInterval(1)
        // NOTE: Different venue code
        let evt2 = diary.findOrCreateEvent(country: 826,state: 4, venue: 54321, seen: secondDateTime, with: nil)
        
        XCTAssertNotNil(evt1)
        XCTAssertNotNil(evt2)
        XCTAssertEqual(2, diary.eventListCount())
        XCTAssertEqual(2, diary.uniqueVenueCount())
    }
    
    func testTwoVenuesSameCodeDifferentState() throws {
        let diary = VenueDiary()
        
        let firstDate = K.date("2020-09-24T10:00:00+0000")!
        let evt1 = diary.findOrCreateEvent(country: 826,state: 4, venue: 12345, seen: firstDate, with: nil)
        let secondDateTime: Date = firstDate + BLESensorConfiguration.venueCheckInTimeLimit - TimeInterval(1)
        let evt2 = diary.findOrCreateEvent(country: 826,state: 2, venue: 12345, seen: secondDateTime, with: nil)
        
        XCTAssertNotNil(evt1)
        XCTAssertNotNil(evt2)
        XCTAssertEqual(2, diary.eventListCount())
        XCTAssertEqual(2, diary.uniqueVenueCount())
    }
    
    func testTwoVenuesSameCodeDifferentCountry() throws {
        let diary = VenueDiary()
        
        let firstDate = K.date("2020-09-24T10:00:00+0000")!
        let evt1 = diary.findOrCreateEvent(country: 826,state: 4, venue: 12345, seen: firstDate, with: nil)
        let secondDateTime: Date = firstDate + BLESensorConfiguration.venueCheckInTimeLimit - TimeInterval(1)
        let evt2 = diary.findOrCreateEvent(country: 123,state: 4, venue: 12345, seen: secondDateTime, with: nil)
        
        XCTAssertNotNil(evt1)
        XCTAssertNotNil(evt2)
        XCTAssertEqual(2, diary.eventListCount())
        XCTAssertEqual(2, diary.uniqueVenueCount())
    }
    
    /// MARK:- Update diary event state tests over time
    
    func testTwoVenuesOneClosedImplicitly() throws {
        let diary = VenueDiary()
        
        let firstDate = K.date("2020-09-24T10:00:00+0000")!
        let evt1 = diary.findOrCreateEvent(country: 826,state: 4, venue: 123456, seen: firstDate, with: nil)
        let secondDateTime: Date = firstDate + BLESensorConfiguration.venueCheckOutTimeLimit + TimeInterval(1)
        // NOTE: Very different time (well, not very different... just outside of the 'same event' time
        let evt2 = diary.findOrCreateEvent(country: 826,state: 4, venue: 123456, seen: secondDateTime, with: nil)
        
        XCTAssertNotNil(evt1)
        XCTAssertNotNil(evt2)
        XCTAssertEqual(2, diary.eventListCount())
        XCTAssertEqual(1, diary.uniqueVenueCount())
        
    }
    
    /// MARK:- Sensor delegate tests
    func testValidEncounter() throws {
        BLESensorConfiguration.logLevel = .debug
        
        let diary = VenueDiary()
        
        let firstDate = K.date("2020-09-24T10:00:00+0000")!
        
        let supplier = ConcreteBeaconPayloadDataSupplierV1.init(countryCode: 826, stateCode: 4, code: 123456)
        
        let payload = supplier.payload(device: nil)
        XCTAssertNotNil(payload)
        XCTAssertEqual("303A03040040E20100", payload?.hexEncodedString)
        // 0x30 = 30, 826 = 3A03, 4 = 0400, 123456 = 40E20100 - LittleEndian
        
        let encounter = try VenueEncounter(Proximity(unit: .RSSI, value: -55), payload!)
        let secondDateTime: Date = firstDate + BLESensorConfiguration.venueCheckInTimeLimit - TimeInterval(1)
        XCTAssertNotNil(encounter)
        XCTAssertNotNil(encounter!.getVenue())
        XCTAssertEqual(826, encounter!.getVenue()!.getCountry())
        XCTAssertEqual(4, encounter!.getVenue()!.getState())
        XCTAssertEqual(123456, encounter!.getVenue()!.getCode())
        let evt = diary.addEncounter(encounter!, with: payload, at: secondDateTime)
        
        XCTAssertNotNil(evt)
        XCTAssertEqual(1, diary.eventListCount())
        XCTAssertEqual(1, diary.uniqueVenueCount())
    }
    
    func testInvalidEncounter() throws {
        let diary = VenueDiary()
        
        let supplier = ConcreteBeaconPayloadDataSupplierV1.init(countryCode: 826, stateCode: 4, code: 123456)
        
        let payload = supplier.payload(device: nil)
        XCTAssertNotNil(payload)
        
        // modify payload info bit to be invalid
        let brokenData = PayloadData()
        brokenData.append(UInt8(0x00))
        brokenData.append(payload!.subdata(in: 1..<payload!.count))
        
        var thrownError: Error?
        XCTAssertThrowsError(try VenueEncounter(Proximity(unit: .RSSI, value: -55), brokenData)) {
            thrownError = $0
        }
        
        XCTAssertNotNil(thrownError)
        XCTAssertEqual(0, diary.eventListCount())
        XCTAssertEqual(0, diary.uniqueVenueCount())
    }
    
    func testInvalidSensor() throws {
        BLESensorConfiguration.logLevel = .debug
        
        let diary = VenueDiary()
        
        let supplier = ConcreteBeaconPayloadDataSupplierV1.init(countryCode: 826, stateCode: 4, code: 123456)
        
        let payload = supplier.payload(device: nil)
        XCTAssertNotNil(payload)
        XCTAssertEqual("303A03040040E20100", payload?.hexEncodedString)
        // 0x30 = 30, 826 = 3A03, 4 = 0400, 123456 = 40E20100 - LittleEndian
        
        let brokenPayload = PayloadData(payload!.subdata(in: 0..<8))// too short - by 1 byte
        
        let target = TargetIdentifier("SomeID")
        
        diary.sensor(.BEACON, didMeasure: Proximity(unit: .RSSI, value: -55), fromTarget: target, withPayload: brokenPayload)
    
        XCTAssertEqual(0, diary.eventListCount())
        XCTAssertEqual(0, diary.uniqueVenueCount())
    }
    
    func testValidSensor() throws {
        BLESensorConfiguration.logLevel = .debug
        
        let diary = VenueDiary()
        
        let supplier = ConcreteBeaconPayloadDataSupplierV1.init(countryCode: 826, stateCode: 4, code: 123456)
        
        let payload = supplier.payload(device: nil)
        XCTAssertNotNil(payload)
        XCTAssertEqual("303A03040040E20100", payload?.hexEncodedString)
        // 0x30 = 30, 826 = 3A03, 4 = 0400, 123456 = 40E20100 - LittleEndian
        
        let target = TargetIdentifier("SomeID")
        
        diary.sensor(.BEACON, didMeasure: Proximity(unit: .RSSI, value: -55), fromTarget: target, withPayload: payload!)
        
        XCTAssertEqual(1, diary.eventListCount())
        XCTAssertEqual(1, diary.uniqueVenueCount())
    }
}
