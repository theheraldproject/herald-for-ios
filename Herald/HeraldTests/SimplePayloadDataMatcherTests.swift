//
//  SimplePayloadDataMatcherTests.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class SimplePayloadDataMatcherTests: XCTestCase {

    @available(iOS 13.0, *)
    func testMatches() throws {
        let ks1 = SecretKey(repeating: 0, count: 2048)
        let ks2 = SecretKey(repeating: 1, count: 2048)
        let pds1 = ConcreteSimplePayloadDataSupplier(protocolAndVersion: 0, countryCode: 0, stateCode: 0, secretKey: ks1)
        let pds2 = ConcreteSimplePayloadDataSupplier(protocolAndVersion: 0, countryCode: 0, stateCode: 0, secretKey: ks2)

        let day0 = K.date("2020-09-24T00:00:00+0000")!
        let day1 = K.date("2020-09-25T00:00:00+0000")!

        let pdm1 = ConcreteSimplePayloadDataMatcher([day0:[pds1.matchingKey(day0)!]])
        
        for second in 0...(24*60*60)-1 {
            let time = day0.advanced(by: TimeInterval(second))
            let payloadData1 = pds1.payload(time, device: nil)
            let payloadData2 = pds2.payload(time, device: nil)
            
            XCTAssertNotNil(payloadData1)
            XCTAssertNotNil(payloadData2)
            
            // Match should pass as secret key is the same
            XCTAssertTrue(pdm1.matches(time, payloadData1!))
            // Match should fail as secret key is different
            XCTAssertFalse(pdm1.matches(time, payloadData2!))
        }

        for second in 0...(24*60*60)-1 {
            let time = day1.advanced(by: TimeInterval(second))
            let payloadData1 = pds1.payload(time, device: nil)
            let payloadData2 = pds2.payload(time, device: nil)
            
            XCTAssertNotNil(payloadData1)
            XCTAssertNotNil(payloadData2)
            
            // Match should fail as secret key is the same but day is different
            XCTAssertFalse(pdm1.matches(time, payloadData1!))
            // Match should fail as secret key is different and day is different
            XCTAssertFalse(pdm1.matches(time, payloadData2!))
        }

    }
}
