//
//  BeaconCodes.swift
//
//  Copyright © 2020 . All rights reserved.
//

import Foundation

/**
 Beacon codes are derived from day codes. On each new day, the day code for the day, being a long value,
 is taken as 64-bit raw data. The bits are reversed and then hashed (SHA) to create a seed for the beacon
 codes for the day. It is cryptographically challenging to derive the day code from the seed, and it is this seed
 that will eventually be distributed by the central server for on-device matching. The generation of beacon
 codes is similar to that for day codes, it is based on recursive hashing and taking the modulo to produce
 a collection of long values, that are randomly selected as beacon codes. Given the process is deterministic,
 on-device matching is possible, once the beacon code seed is provided by the server.
 */
protocol BeaconCodes {
    func get(_ timestamp: Timestamp) -> BeaconCode?
    
    func get() -> BeaconCode?
}

typealias BeaconCode = Int64

class ConcreteBeaconCodes : BeaconCodes {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Payload..ConcreteBeaconCodes")
    static let codesPerDay = 240
    private var dayCodes: DayCodes
    private var seed: BeaconCodeSeed?
    private var values:[BeaconCode]?
    
    init(_ dayCodes: DayCodes) {
        self.dayCodes = dayCodes
        let _ = get()
    }
    
    func get(_ timestamp: Timestamp) -> BeaconCode? {
        guard let (seed, _) = dayCodes.seed(timestamp) else {
            logger.fault("No seed code available")
            return nil
        }
        let beaconCodes = ConcreteBeaconCodes.beaconCodes(seed, count: ConcreteBeaconCodes.codesPerDay)
        let (daySecond, _) = UInt64(NSDate(timeIntervalSince1970: timestamp.timeIntervalSince1970).timeIntervalSince1970).remainderReportingOverflow(dividingBy: UInt64(60*60*24))
        let (codeIndex, _) = daySecond.dividedReportingOverflow(by: UInt64(beaconCodes.count))
        return beaconCodes[Int(codeIndex)]
    }
    
    func get() -> BeaconCode? {
        let timerstamp = Timestamp()
        if seed == nil {
            guard let (seed, _) = dayCodes.seed(timerstamp) else {
                logger.fault("No seed code available")
                return nil
            }
            self.seed = seed
        }
        guard let (seedToday, today) = dayCodes.seed(timerstamp) else {
            logger.fault("No seed code available")
            return nil
        }
        if values == nil || seed != seedToday {
            logger.fault("Generating beacon codes for new day (day=\(today.description),seed=\(seedToday.description))")
            seed = seedToday
            values = ConcreteBeaconCodes.beaconCodes(seedToday, count: ConcreteBeaconCodes.codesPerDay)
        }
        guard let values = values else {
            logger.fault("No beacon code available")
            return nil
        }
        return values[Int.random(in: 0 ... (values.count - 1))]
    }
    
    static func beaconCodes(_ beaconCodeSeed: BeaconCodeSeed, count: Int) -> [BeaconCode] {
        let data = Data(withUnsafeBytes(of: beaconCodeSeed) { Data($0) }.reversed())
        var hash = SHA.hash(data: data)
        var values = [BeaconCode](repeating: 0, count: count)
        for i in (0 ... (count - 1)).reversed() {
            values[i] = JavaData.byteArrayToLong(digest: hash)
            let hashData = Data(hash)
            hash = SHA.hash(data: hashData)
        }
        return values
    }

}
