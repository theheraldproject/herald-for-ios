//
//  SimplePayloadDataSupplierTests.swift
//
//  Copyright 2020 VMware, Inc.
//  SPDX-License-Identifier: Apache-2.0
//

import XCTest
@testable import Herald

class SimplePayloadDataSupplierTests: XCTestCase {

    func testTimeIntervalSince1970() throws {
        // Same string date, same date
        XCTAssertEqual(K.date("2020-09-24T00:00:00+0000")!.timeIntervalSince(K.date("2020-09-24T00:00:00+0000")!), 0)
        // Parsing second in string date
        XCTAssertEqual(K.date("2020-09-24T00:00:01+0000")!.timeIntervalSince(K.date("2020-09-24T00:00:00+0000")!), 1)
        // Parsing minute in string date
        XCTAssertEqual(K.date("2020-09-24T00:01:00+0000")!.timeIntervalSince(K.date("2020-09-24T00:00:00+0000")!), 60)
        // Parsing hour in string date
        XCTAssertEqual(K.date("2020-09-24T01:00:00+0000")!.timeIntervalSince(K.date("2020-09-24T00:00:00+0000")!), 60  * 60)
        // Parsing day in string date
        XCTAssertEqual(K.date("2020-09-25T00:00:00+0000")!.timeIntervalSince(K.date("2020-09-24T00:00:00+0000")!), 24 * 60  * 60)
    }
    
    func testDay() throws {
        // Day before epoch
        XCTAssertEqual(K.day(K.date("2020-09-23T00:00:00+0000")!), -1)
        // Epoch day
        XCTAssertEqual(K.day(K.date("2020-09-24T00:00:00+0000")!), 0)
        XCTAssertEqual(K.day(K.date("2020-09-24T00:00:01+0000")!), 0)
        XCTAssertEqual(K.day(K.date("2020-09-24T23:59:59+0000")!), 0)
        // Day after epoch
        XCTAssertEqual(K.day(K.date("2020-09-25T00:00:00+0000")!), 1)
        XCTAssertEqual(K.day(K.date("2020-09-25T00:00:01+0000")!), 1)
        XCTAssertEqual(K.day(K.date("2020-09-25T23:59:59+0000")!), 1)
        // 2 days after epoch
        XCTAssertEqual(K.day(K.date("2020-09-26T00:00:00+0000")!), 2)
    }
    
    func testPeriod() throws {
        // Period starts at midnight
        XCTAssertEqual(K.period(K.date("2020-09-24T00:00:00+0000")!), 0)
        XCTAssertEqual(K.period(K.date("2020-09-24T00:00:01+0000")!), 0)
        XCTAssertEqual(K.period(K.date("2020-09-24T00:05:59+0000")!), 0)
        // A peroid is 6 minutes long
        XCTAssertEqual(K.period(K.date("2020-09-24T00:06:00+0000")!), 1)
        XCTAssertEqual(K.period(K.date("2020-09-24T00:06:01+0000")!), 1)
        XCTAssertEqual(K.period(K.date("2020-09-24T00:11:59+0000")!), 1)
        // Last period of the day
        XCTAssertEqual(K.period(K.date("2020-09-24T23:54:00+0000")!), 239)
        XCTAssertEqual(K.period(K.date("2020-09-24T23:54:01+0000")!), 239)
        XCTAssertEqual(K.period(K.date("2020-09-24T23:59:59+0000")!), 239)
        // Should never happen but still valid and correct
        XCTAssertEqual(K.period(K.date("2020-09-24T24:00:00+0000")!), 0)
        XCTAssertEqual(K.period(K.date("2020-09-24T24:06:00+0000")!), 1)
    }
    
    func testSecretKey() throws {
        // Secret keys are different every time
        for _ in 0...1000 {
            let k1 = K.secretKey()
            let k2 = K.secretKey()
            XCTAssertNotNil(k1)
            XCTAssertNotNil(k2)
            XCTAssertEqual(k1!.count, 2048)
            XCTAssertEqual(k2!.count, 2048)
            XCTAssertFalse(k1!.elementsEqual(k2!))
        }
    }
    
    func testMatchingKeys() throws {
        // Generate same secret keys
        let ks1 = SecretKey(repeating: 0, count: 2048)
        let ks2 = SecretKey(repeating: 0, count: 2048)
        // Generate a different secret key
        let ks3 = SecretKey(repeating: 1, count: 2048)
        
        // Generate matching keys based on the same secret key
        let km1 = K.matchingKeys(ks1)
        let km2 = K.matchingKeys(ks2)
        // Generate matching keys based on a different secret key
        let km3 = K.matchingKeys(ks3)
        
        // 2001 matching keys in total (key 2000 is not used)
        XCTAssertEqual(km1.count, 2001)
        XCTAssertEqual(km2.count, 2001)
        XCTAssertEqual(km3.count, 2001)
        
        // Matching key is 32 bytes
        XCTAssertEqual(km1[0].count, 32)
        
        // Same secret key for same matching keys
        XCTAssertTrue(km1.elementsEqual(km2))
        // Different secret keys for different matching keys
        XCTAssertFalse(km1.elementsEqual(km3))
        XCTAssertFalse(km2.elementsEqual(km3))
    }
    
    func testContactKeys() throws {
        // Generate secret and matching keys
        let ks1 = SecretKey(repeating: 0, count: 2048)
        let km1 = K.matchingKeys(ks1)
        
        // Generate contact keys based on the same matching key
        let kc1 = K.contactKeys(km1[0])
        let kc2 = K.contactKeys(km1[0])
        // Generate contact keys based on a different matching key
        let kc3 = K.contactKeys(km1[1])

        // 241 contact keys per day (key 241 is not used)
        XCTAssertEqual(kc1.count, 241)
        XCTAssertEqual(kc2.count, 241)
        XCTAssertEqual(kc3.count, 241)
        
        // Contact key is 32 bytes
        XCTAssertEqual(kc1[0].count, 32)
        
        // Same contact keys for same matching key
        XCTAssertTrue(kc1.elementsEqual(kc2))
        // Different contact keys for different matching keys
        XCTAssertFalse(kc1.elementsEqual(kc3))
        XCTAssertFalse(kc2.elementsEqual(kc3))
        
        // Contact key changes throughout the day
        for i in 0...239 {
            for j in (i + 1)...240 {
                XCTAssertNotEqual(kc1[i], kc1[j])
                XCTAssertNotEqual(kc2[i], kc2[j])
                XCTAssertNotEqual(kc3[i], kc3[j])
            }
        }
    }
    
    func testContactIdentifier() throws {
        // Generate secret and matching keys
        let ks1 = SecretKey(repeating: 0, count: 2048)
        let km1 = K.matchingKeys(ks1)
        
        // Generate contact keys based on the same matching key
        let kc1 = K.contactKeys(km1[0])

        // Generate contact identifier based on contact key
        let Ic1 = K.contactIdentifier(kc1[0])
        let Ic2 = K.contactIdentifier(kc1[0])
        let Ic3 = K.contactIdentifier(kc1[1])

        // Contact identifier is 16 bytes
        XCTAssertEqual(Ic1.count, 16)

        // Same contact identifier for same contact key
        XCTAssertEqual(Ic1, Ic2)
        XCTAssertNotEqual(Ic2, Ic3)
    }

    func testPayload() throws {
        let ks1 = SecretKey(repeating: 0, count: 2048)
        let pds1 = ConcreteSimplePayloadDataSupplier(protocolAndVersion: 0, countryCode: 0, stateCode: 0, secretKey: ks1)

        // Payload is 23 bytes long
        XCTAssertNotNil(pds1.payload(K.date("2020-09-24T00:00:00+0000")!, device: nil))
        XCTAssertEqual(pds1.payload(K.date("2020-09-24T00:00:00+0000")!, device: nil)?.count, ConcreteSimplePayloadDataSupplier.payloadLength)

        // Same payload in same period
        XCTAssertEqual(pds1.payload(K.date("2020-09-24T00:00:00+0000")!, device: nil), pds1.payload(K.date("2020-09-24T00:00:00+0000")!, device: nil))
        XCTAssertEqual(pds1.payload(K.date("2020-09-24T00:00:00+0000")!, device: nil), pds1.payload(K.date("2020-09-24T00:05:59+0000")!, device: nil))
        // Different payloads in different periods
        XCTAssertNotEqual(pds1.payload(K.date("2020-09-24T00:00:00+0000")!, device: nil), pds1.payload(K.date("2020-09-24T00:06:00+0000")!, device: nil))

        // Same payload in different periods before epoch
        XCTAssertEqual(pds1.payload(K.date("2020-09-23T00:00:00+0000")!, device: nil), pds1.payload(K.date("2020-09-23T00:06:00+0000")!, device: nil))
        XCTAssertEqual(pds1.payload(K.date("2020-09-23T00:00:00+0000")!, device: nil), pds1.payload(K.date("2020-09-23T23:54:00+0000")!, device: nil))
        // Valid payload on first epoch period
        XCTAssertNotEqual(pds1.payload(K.date("2020-09-23T00:00:00+0000")!, device: nil), pds1.payload(K.date("2020-09-23T23:54:01+0000")!, device: nil))

        // Same payload in same periods on epoch + 2000 days
        XCTAssertEqual(pds1.payload(K.date("2026-03-17T00:00:00+0000")!, device: nil), pds1.payload(K.date("2026-03-17T00:00:00+0000")!, device: nil))
        XCTAssertEqual(pds1.payload(K.date("2026-03-17T00:00:00+0000")!, device: nil), pds1.payload(K.date("2026-03-17T00:05:59+0000")!, device: nil))
        // Different payloads in different periods on epoch + 2000 days
        XCTAssertNotEqual(pds1.payload(K.date("2026-03-17T00:00:00+0000")!, device: nil), pds1.payload(K.date("2026-03-17T00:06:00+0000")!, device: nil))

        // Same payload in different periods after epoch + 2001 days
        XCTAssertEqual(pds1.payload(K.date("2026-03-18T00:00:00+0000")!, device: nil), pds1.payload(K.date("2026-03-18T00:06:00+0000")!, device: nil))
        XCTAssertEqual(pds1.payload(K.date("2026-03-18T00:00:00+0000")!, device: nil), pds1.payload(K.date("2026-03-18T00:05:59+0000")!, device: nil))
        XCTAssertEqual(pds1.payload(K.date("2026-03-18T00:00:00+0000")!, device: nil), pds1.payload(K.date("2026-03-18T00:06:00+0000")!, device: nil))
    }
    
//    func testCrossPlatformBinary16() throws {
//        print("value,float16")
//        print("-65504,\(F.binary16(-65504).base64EncodedString())")
//        print("-0.0000000596046,\(F.binary16(-0.0000000596046).base64EncodedString())")
//        print("0,\(F.binary16(0).base64EncodedString())")
//        print("0.0000000596046,\(F.binary16(0.0000000596046).base64EncodedString())")
//        print("65504,\(F.binary16(65504).base64EncodedString())")
//    }

    func testContactIdentifierCrossPlatform() throws {
        var csv = "day,period,matchingKey,contactKey,contactIdentifier\n"
        // Generate secret and matching keys
        let ks1 = SecretKey(repeating: 0, count: 2048)
        let km1 = K.matchingKeys(ks1)
        // Print first 10 days of contact keys for comparison across iOS and Android implementations
        for day in 0...10 {
            let kc1 = K.contactKeys(km1[day])
            for period in 0...240 {
                let Ic1 = K.contactIdentifier(kc1[period])
                csv.append("\(day),\(period),\(km1[day].base64EncodedString()),\(kc1[period].base64EncodedString()),\(Ic1.base64EncodedString())\n")
            }
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "contactIdentifier.csv"
        add(attachment)
    }
    
    func testPayloadData() throws {
        var csv = "value,data\n"
        for i in 0...600 {
            let payloadData = PayloadData(repeating: 0, count: i)
            csv.append("\(i),\(payloadData.shortName)\n")
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "payloadDataShortName.csv"
        add(attachment)
    }
}
