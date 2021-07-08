//
//  SimplePayloadDataSupplierTests.swift
//
//  Copyright 2020-2021 Herald Project Contributors
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
        // Generate same secret keys (ks1, ks2) and a different secret key (ks3)
        let ks1 = SecretKey(repeating: 0, count: 2048)
        let ks2 = SecretKey(repeating: 0, count: 2048)
        let ks3 = SecretKey(repeating: 1, count: 2048)
        XCTAssertEqual(ks1, ks2)
        XCTAssertNotEqual(ks1, ks3)
        XCTAssertNotEqual(ks2, ks3)
        
        // Same secret key should generate the same matching key seed on the same day,
        // different secret keys should generate different seeds on the same day
        let kms1 = K.matchingKeySeed(ks1, onDay: 0)!
        let kms2 = K.matchingKeySeed(ks2, onDay: 0)!
        let kms3 = K.matchingKeySeed(ks3, onDay: 0)!
        XCTAssertEqual(kms1, kms2)
        XCTAssertNotEqual(kms1, kms3)
        XCTAssertNotEqual(kms2, kms3)

        // Same matching key seed should generate the same matching key,
        // different matching key seeds should generate different keys on the same day
        let km1 = K.matchingKey(kms1)
        let km2 = K.matchingKey(kms2)
        let km3 = K.matchingKey(kms3)
        XCTAssertEqual(km1, km2)
        XCTAssertNotEqual(km1, km3)
        XCTAssertNotEqual(km2, km3)

        // Matching key is 32 bytes
        XCTAssertEqual(km1.count, 32)
        XCTAssertEqual(km2.count, 32)
        XCTAssertEqual(km3.count, 32)
    }
    
    func testContactKeys() throws {
        // Generate same matching keys (km1, km2) and a different matching key (km3)
        let km1 = K.matchingKey(K.matchingKeySeed(SecretKey(repeating: 0, count: 2048), onDay: 0)!)
        let km2 = K.matchingKey(K.matchingKeySeed(SecretKey(repeating: 0, count: 2048), onDay: 0)!)
        let km3 = K.matchingKey(K.matchingKeySeed(SecretKey(repeating: 1, count: 2048), onDay: 0)!)

        // Same matching key should generate the same contact key seed from the same period,
        // different matching keys should generate different seeds for the same period
        let kcs1 = K.contactKeySeed(km1, forPeriod: 0)!
        let kcs2 = K.contactKeySeed(km2, forPeriod: 0)!
        let kcs3 = K.contactKeySeed(km3, forPeriod: 0)!
        XCTAssertEqual(kcs1, kcs2)
        XCTAssertNotEqual(kcs1, kcs3)
        XCTAssertNotEqual(kcs2, kcs3)
        
        // Same contact key seed should generate the same contact key,
        // different contact key seeds should generate different keys
        let kc1 = K.contactKey(kcs1)
        let kc2 = K.contactKey(kcs2)
        let kc3 = K.contactKey(kcs3)
        XCTAssertEqual(kc1, kc2)
        XCTAssertNotEqual(kc1, kc3)
        XCTAssertNotEqual(kc2, kc3)

        // Contact key is 32 bytes
        XCTAssertEqual(kc1.count, 32)
        XCTAssertEqual(kc2.count, 32)
        XCTAssertEqual(kc3.count, 32)
//
//        // Contact key changes throughout the day
//        for i in 0...239 {
//            let kc1i = K.contactKey(K.contactKeySeed(km1, forPeriod: i)!)
//            for j in (i + 1)...240 {
//                let kc1j = K.contactKey(K.contactKeySeed(km1, forPeriod: j)!)
//                XCTAssertNotEqual(kc1i, kc1j)
//            }
//        }
    }
    
    func testContactIdentifier() throws {
        // Generate same matching keys (km1, km2) and a different matching key (km3)
        let km1 = K.matchingKey(K.matchingKeySeed(SecretKey(repeating: 0, count: 2048), onDay: 0)!)
        let km2 = K.matchingKey(K.matchingKeySeed(SecretKey(repeating: 0, count: 2048), onDay: 0)!)
        let km3 = K.matchingKey(K.matchingKeySeed(SecretKey(repeating: 1, count: 2048), onDay: 0)!)

        // Generate same contact keys (kc1, kc2) and a different contact key (kc3)
        let kc1 = K.contactKey(K.contactKeySeed(km1, forPeriod: 0)!)
        let kc2 = K.contactKey(K.contactKeySeed(km2, forPeriod: 0)!)
        let kc3 = K.contactKey(K.contactKeySeed(km3, forPeriod: 0)!)

        // Same contact key should generate the same contact identifier,
        // different contact keys should generate different identifiers
        let Ic1 = K.contactIdentifier(kc1)
        let Ic2 = K.contactIdentifier(kc2)
        let Ic3 = K.contactIdentifier(kc3)
        XCTAssertEqual(Ic1, Ic2)
        XCTAssertNotEqual(Ic1, Ic3)
        XCTAssertNotEqual(Ic2, Ic3)

        // Contact identifier is 16 bytes
        XCTAssertEqual(Ic1.count, 16)
        XCTAssertEqual(Ic2.count, 16)
        XCTAssertEqual(Ic3.count, 16)

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
        var csv = "day,period,matchingKeySeed,matchingKey,contactKeySeed,contactKey,contactIdentifier\n"
        let secretKey = SecretKey(repeating: 0, count: 2048)
        // Print first 10 days of contact keys for comparison across iOS and Android implementations
        for day in 0...10 {
            let matchingKeySeed = K.matchingKeySeed(secretKey, onDay: day)!
            let matchingKey = K.matchingKey(matchingKeySeed)
            for period in 0...240 {
                let contactKeySeed = K.contactKeySeed(matchingKey, forPeriod: period)!
                let contactKey = K.contactKey(contactKeySeed)
                let contactIdentifier = K.contactIdentifier(contactKey)
                csv.append("\(day),\(period),\(matchingKeySeed.base64EncodedString()),\(matchingKey.base64EncodedString()),\(contactKeySeed.base64EncodedString()),\(contactKey.base64EncodedString()),\(contactIdentifier.base64EncodedString())\n")
            }
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "contactIdentifier.csv"
        add(attachment)
    }

    func testMatchingKeyCrossPlatform() throws {
        var csv = "day,matchingKeySeed,matchingKey\n"
        let secretKey = SecretKey(repeating: 0, count: 2048)
        // Print all matching key seeds and keys for comparison across iOS and Android implementations
        for day in (0...2000).reversed() {
            let matchingKeySeed = K.matchingKeySeed(secretKey, onDay: day)!
            let matchingKey = K.matchingKey(matchingKeySeed)
            csv.append("\(day),\(matchingKeySeed.base64EncodedString()),\(matchingKey.base64EncodedString())\n")
        }
        let attachment = XCTAttachment(string: csv)
        attachment.lifetime = .keepAlways
        attachment.name = "matchingKey.csv"
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
