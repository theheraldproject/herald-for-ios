//
//  SimplePayloadDataSupplier.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import CommonCrypto
import Accelerate

/// Simple payload data supplier. Payload data is 21 bytes.
public protocol SimplePayloadDataSupplier : PayloadDataSupplier {
}

/// Simple payload data supplier.
public class ConcreteSimplePayloadDataSupplier : SimplePayloadDataSupplier {
    public static let payloadLength: Int = 21

    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Payload.ConcreteSimplePayloadDataSupplier")
    private let commonHeader: Data
    private let secretKey: SecretKey
    // Cache contact identifiers for the day
    private var day: Int?
    private var contactIdentifiers: [ContactIdentifier]?
    
    public init(protocolAndVersion: UInt8, countryCode: UInt16, stateCode: UInt16, secretKey: SecretKey) {
        // Generate common header
        // Common header = protocolAndVersion + countryCode + stateCode
        var commonHeader = Data()
        commonHeader.append(protocolAndVersion)
        commonHeader.append(countryCode)
        commonHeader.append(stateCode)
        self.commonHeader = commonHeader
        
        // Generate matching keys from secret key
        self.secretKey = secretKey
    }
    
    /// Generate a new secret key
    public static func generateSecretKey() -> SecretKey? {
        guard let secretKey = K.secretKey() else {
            return nil
        }
        return SecretKey(secretKey)
    }
    
    /// Get matching key for a day
    public func matchingKey(_ time: Date) -> MatchingKey? {
        let day = K.day(time)
        guard let matchingKeySeed = K.matchingKeySeed(secretKey, onDay: day) else {
            logger.fault("Matching key seed out of day range (time=\(time),day=\(day)))")
            return nil
        }
        return K.matchingKey(matchingKeySeed)
    }
        
    /// Generate contact identifier for time
    private func contactIdentifier(_ time: Date) -> ContactIdentifier? {
        let day = K.day(time)
        let period = K.period(time)
        
        guard let matchingKeyOnDay = matchingKey(time) else {
            logger.fault("Contact identifier out of day range (time=\(time),day=\(day)))")
            return nil
        }
        
        // Generate and cache contact keys for specific day on-demand
        if self.day != day {
            contactIdentifiers = K.contactKeys(matchingKeyOnDay).map({ K.contactIdentifier($0) })
            self.day = day
        }
        
        guard let contactIdentifiers = contactIdentifiers else {
            logger.fault("Contact identifiers unavailable (time=\(time),day=\(day)))")
            return nil
        }
        
        guard period >= 0, period < contactIdentifiers.count else {
            logger.fault("Contact identifier out of period range (time=\(time),period=\(period)))")
            return nil
        }
        
        // Defensive check
        guard contactIdentifiers[period].count == 16 else {
            logger.fault("Contact identifier not 16 bytes (time=\(time),count=\(contactIdentifiers[period].count))")
            return nil
        }
        
        return contactIdentifiers[period]
    }
    
    // MARK:- SimplePayloadDataSupplier
    
    public func legacyPayload(_ timestamp: PayloadTimestamp = PayloadTimestamp(), device: Device?) -> PayloadData? {
        return nil
    }
    
    public func payload(_ timestamp: PayloadTimestamp = PayloadTimestamp(), device: Device?) -> PayloadData? {
        let payloadData = PayloadData()
        payloadData.append(commonHeader)
        if let contactIdentifier = contactIdentifier(timestamp) {
            payloadData.append(contactIdentifier)
        } else {
            payloadData.append(ContactIdentifier(repeating: 0, count: 16))
        }
        return payloadData
    }
    
    /// Default implementation assumes fixed length payload data.
    public func payload(_ data: Data) -> [PayloadData] {
        // Split data into payloads based on fixed length
        var payloads: [PayloadData] = []
        var indexStart = 0, indexEnd = ConcreteSimplePayloadDataSupplier.payloadLength
        while indexEnd <= data.count {
            let payload = PayloadData(data.subdata(in: indexStart..<indexEnd))
            payloads.append(payload)
            indexStart += ConcreteSimplePayloadDataSupplier.payloadLength
            indexEnd += ConcreteSimplePayloadDataSupplier.payloadLength
        }
        return payloads
    }
}

/// Key derivation functions
class K {
    /// Secret key length
    private static let secretKeyLength = 2048
    /// Days supported by key derivation function
    private static let days = 2000
    /// Periods per day
    private static let periods = 240
    /// Epoch as time interval since 1970
    private static let epoch = K.getEpoch()
    
    /// Date from string date "yyyy-MM-dd'T'HH:mm:ssXXXX"
    static func date(_ fromString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXX"
        return formatter.date(from: fromString)
    }
    
    /// Epoch for calculating days and periods
    static func getEpoch() -> TimeInterval {
        return date("2020-09-24T00:00:00+0000")!.timeIntervalSince1970
    }
    
    /// Epoch day for selecting matching key
    static func day(_ onDate: Date = Date()) -> Int {
        let (day,_) = Int(onDate.timeIntervalSince1970 - epoch).dividedReportingOverflow(by: 86400)
        return day
    }
    
    /// Epoch day period for selecting contact key
    static func period(_ atTime: Date = Date()) -> Int {
        let (second,_) = Int(atTime.timeIntervalSince1970 - epoch).remainderReportingOverflow(dividingBy: 86400)
        let (period,_) = second.dividedReportingOverflow(by: 86400 / periods)
        return period
    }
    
    /// Generate 2048-bit secret key, K_s
    static func secretKey() -> SecretKey? {
        var bytes = [UInt8](repeating: 0, count: secretKeyLength)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            return nil
        }
        return SecretKey(bytes)
    }
    
    /// Forward secured matching key seeds are generated by a reversed hash chain with truncation, to ensure future keys cannot be derived from historic keys.
    /// The cryptographic hash function offers a one-way function for forward security. The truncation function offers additional assurance by deleting intermediate
    /// key material, thus a compromised hash function will still maintain forward security.
    static func matchingKeySeed(_ secretKey: SecretKey, onDay: Int) -> MatchingKeySeed? {
        // The last matching key seed on day 2000 (over 5 years from epoch) is the
        // hash of the secret key. A new secret key will need to be established
        // before all matching key seeds are exhausted on day 2000.
        guard onDay <= K.days, onDay >= 0 else {
            return nil
        }
        var matchingKeySeed = MatchingKeySeed(F.h(secretKey))
        var matchingKeySeedDay = K.days
        // Work backwards from day 2000 to derive seeds for day 1999, 1998, until
        // reaching the required day
        while matchingKeySeedDay > onDay {
            matchingKeySeed = MatchingKeySeed(F.h(F.t(matchingKeySeed)))
            matchingKeySeedDay -= 1
        }
        return matchingKeySeed
    }
    
    /// Matching key for day i is the hash of the matching key seed for day i xor i - 1. A separation of matching key from its seed is necessary because the
    /// matching key is distributed by the server to all phones for on-device matching in a decentralised contact tracing solution. Given a seed is used to
    /// derive the seeds for other days, publishing the hash prevents an attacker from establishing the other seeds.
    static func matchingKey(_ deriveFrom: MatchingKeySeed) -> MatchingKey {
        // Matching key on day N is derived from matching key seed on day N and day N-1
        let matchingKeySeedMinusOne = MatchingKeySeed(F.h(F.t(deriveFrom)))
        let matchingKey = MatchingKey(F.h(F.xor(deriveFrom, matchingKeySeedMinusOne)))
        return matchingKey
    }
    
    /// Forward secured contact key seeds are generated by a reversed hash chain with truncation, to ensure future keys cannot be derived from historic
    /// keys. This is identical to the procedure for generating the matching key seeds. The seeds are never transmitted from the phone. They are
    /// cryptographically challenging to reveal from the broadcasted contact keys, while easy to generate given the matching key, or secret key.
    static func contactKeySeed(_ deriveFrom: MatchingKey, forPeriod: Int) -> ContactKeySeed? {
        // The last contact key seed on any day at period 240 (last 6 minutes of the day)
        // is the hash of the matching key for the day.
        guard forPeriod <= K.periods, forPeriod >= 0 else {
            return nil
        }
        var contactKeySeed = F.h(deriveFrom)
        var contactKeySeedPeriod = K.periods
        // Work backwards from period 240 to derive seeds for period 239, 238, until
        // reaching the required period
        while contactKeySeedPeriod > forPeriod {
            contactKeySeed = ContactKeySeed(F.h(F.t(contactKeySeed)))
            contactKeySeedPeriod -= 1
        }
        return contactKeySeed
    }
    
    static func contactKey(_ deriveFrom: ContactKeySeed) -> ContactKey {
        // Contact key at period N is derived from contact key seed at period N and period N-1
        let contactKeySeedMinusOne = ContactKeySeed(F.h(F.t(deriveFrom)))
        let contactKey = ContactKey(F.h(F.xor(deriveFrom, contactKeySeedMinusOne)))
        return contactKey

    }

    /// Generate contact keys K_{c}^{0...periods}
    static func contactKeys(_ matchingKey: MatchingKey) -> [ContactKey] {
        let n = K.periods

        /**
         Forward secured contact key seeds are generated by a reversed hash chain with truncation, to ensure future keys cannot be derived from historic keys. This is identical to the procedure for generating the matching key seeds. The seeds are never transmitted from the phone. They are cryptographically challenging to reveal from the broadcasted contact keys, while easy to generate given the matching key, or secret key.
         */
        var contactKeySeed: [ContactKeySeed] = Array(repeating: ContactKeySeed(), count: n + 1)
        /**
         The last contact key seed on day i at period 240 (last 6 minutes of the day) is the hash of the matching key for day i.
         */
        contactKeySeed[n] = F.h(matchingKey)
        for j in (0...n - 1).reversed() {
            contactKeySeed[j] = ContactKeySeed(F.h(F.t(contactKeySeed[j + 1])))
        }
        /**
         Contact key for day i at period j is the hash of the contact key seed for day i at period j xor j - 1. A separation of contact key from its seed is necessary because the contact key is distributed to other phones as evidence for encounters on day i within period j. Given a seed is used to derive the seeds for other periods on the same day, transmitting the hash prevents an attacker from establishing the other seeds on day i.
         */
        var contactKey: [ContactKey] = Array(repeating: ContactKey(), count: n + 1)
        for j in 1...n {
            contactKey[j] = ContactKey(F.h(F.xor(contactKeySeed[j], contactKeySeed[j - 1])))
        }
        /**
         Contact key on day 0 is derived from contact key seed at period 0 and period -1. Implemented as special case for clarity in above code.
         */
        let contactKeySeedMinusOne = ContactKeySeed(F.h(F.t(contactKeySeed[0])))
        contactKey[0] = ContactKey(F.h(F.xor(contactKeySeed[0], contactKeySeedMinusOne)))
        return contactKey
    }

    /// Generate contact identifer I_{c}
    static func contactIdentifier(_ contactKey: ContactKey) -> ContactIdentifier {
        return ContactIdentifier(F.t(contactKey, 16))
    }
}

/// Elementary functions
internal class F {
    
    /// Cryptographic hash function : SHA256
    internal static func h(_ data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes({ _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) })
        return Data(hash)
    }
    
    /// Truncation function : Delete second half of data
    fileprivate static func t(_ data: Data) -> Data {
        return F.t(data, data.count / 2)
    }
    
    /// Truncation function : Retain first n bytes of data
    fileprivate static func t(_ data: Data, _ n: Int) -> Data {
        return data.subdata(in: 0..<n)
    }
    
    /// XOR function : Compute left xor right, assumes left and right are the same length
    fileprivate static func xor(_ left: Data, _ right: Data) -> Data {
        let leftByteArray: [UInt8] = Array(left)
        let rightByteArray: [UInt8] = Array(right)
        var resultByteArray: [UInt8] = [UInt8]()
        for i in 0..<leftByteArray.count {
            resultByteArray.append(leftByteArray[i] ^ rightByteArray[i])
        }
        return Data(resultByteArray)
    }
    
    /// Convert 32-bit float to IEE 754 binary16 format 16-bit float
    /// Float16 is introduced in iOS 14
    fileprivate static func binary16(_ value: Float) -> Binary16 {
        var source: [Float] = [value]
        var target: [UInt16] = [0]
        source.withUnsafeMutableBufferPointer { sourceBP in
            var sourceBuffer = vImage_Buffer(data: sourceBP.baseAddress!, height: 1, width: 1, rowBytes: MemoryLayout<Float>.size)
            target.withUnsafeMutableBufferPointer { targetBP in
                var targetBuffer = vImage_Buffer(data: targetBP.baseAddress!, height: 1, width: 1, rowBytes: MemoryLayout<UInt16>.size)
                vImageConvert_PlanarFtoPlanar16F(&sourceBuffer, &targetBuffer, 0)
            }
        }
        let binary16 = Binary16(target[0])
        return binary16
    }

    /// Convert IEE 754 binary16 format 16-bit float to 32-bit float
    /// Float16 is introduced in iOS 14
    fileprivate static func float(_ value: Binary16) -> Float {
        var source: [UInt16] = [value]
        var target: [Float] = [0]
        source.withUnsafeMutableBufferPointer { sourceBP in
            var sourceBuffer = vImage_Buffer(data: sourceBP.baseAddress!, height: 1, width: 1, rowBytes: MemoryLayout<UInt16>.size)
            target.withUnsafeMutableBufferPointer { targetBP in
                var targetBuffer = vImage_Buffer(data: targetBP.baseAddress!, height: 1, width: 1, rowBytes: MemoryLayout<Float>.size)
                vImageConvert_Planar16FtoPlanarF(&sourceBuffer, &targetBuffer, 0)
            }
        }
        let float = target[0]
        return float
    }
}

fileprivate typealias Binary16 = UInt16

// MARK:- Public types

/// Secret key for deriving matching keys, contact keys, and contact idenfiers.
public typealias SecretKey = Data

/// Matching key for deriving contact keys, and contact identifiers.
public typealias MatchingKey = Data

/// Contact identifier shared between phones as evidence for an encounter in a specific time period.
public typealias ContactIdentifier = Data

/// Matching key seed derived from secret key for deriving matching keys
typealias MatchingKeySeed = Data

/// Contact key seed derived from matching key for deriving contact keys
typealias ContactKeySeed = Data

/// Contact key derived from contact key seed for deriving contact identifiers
typealias ContactKey = Data
