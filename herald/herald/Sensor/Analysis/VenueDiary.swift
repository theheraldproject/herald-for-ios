//
//  VenueDiary.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation

public protocol VenueDiaryDelegate {
    func venue(_ didUpdate: VenueDiaryEvent)
}

///
/// Represents a Venue Diary event.
///
/// It is possible to have more than one diary event in a given day. E.g. if you leave and return. This timing is controlled by a global variable in BLESensorConfiguration.
/// It is also possible to visit a place and have an event logged temporarily, but it not be shown in the diary. E.g. walking past a restaurant and checking its menu.
/// This timing is again controlled by a global variable in BLESensorConfiguration.
///
public class VenueDiaryEvent: NSObject {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Analysis.VenueDiaryEvent")
    
    // Country code. Necessary as venueCode is unique per country-state combination only
    private let country: UInt16
    // State code. Necessary as venueCode is unique per country-state combination only
    private let state: UInt16
    
    // The unique venue code
    private let code: UInt32
    // First time within THIS diary event we were present in the venue
    private let firstTime: Date
    // Last time within THIS diary event we were present in the venue
    private var lastTime: Date
    
    /// Have we exceeded the minimum time for a value venue check in yet?
    private var recordable: Bool
    /// Has this diary record exceeded the 'no long here' time?
    private var closed: Bool
    
    /// Last received payload
    public var payload: PayloadData? = nil
    
    /// Optional extended data
    public var extended: ExtendedData? = nil
    
    /// Optional name (Decoded from ExtendedData value)
    private var name: String? = nil
    
    // TODO add supports for within-venue subdivisions (rooms, dining areas, etc.)
    
    public init(country: UInt16, state: UInt16, venue code: UInt32, name: String? = nil, firstSeen at: Date) {
        self.country = country
        self.state = state
        self.code = code
        self.name = name
        firstTime = at
        lastTime = at
        recordable = false // not until we exceed the necessary MINIMUM check in time
        closed = false // not until we exceed the necessary MINIMUM check out time
    }
    
    public func addPresenceIfSameEvent(_ at: Date) -> Bool {
        if (at - lastTime) > BLESensorConfiguration.venueCheckOutTimeLimit {
            closed = true
            return false
        }
        lastTime = at
        if (lastTime - firstTime) > BLESensorConfiguration.venueCheckInTimeLimit {
            recordable = true
        }
        return true
    }
    
    public func updateStateIfNecessary(at: Date = Date()) {
        if (at - lastTime) > BLESensorConfiguration.venueCheckOutTimeLimit {
            closed = true
        }
    }
    
    public func getCountry() -> UInt16 {
        return country
    }
    
    public func getState() -> UInt16 {
        return state
    }
    
    public func getCode() -> UInt32 {
        return code
    }
    
    public func isRecordable() -> Bool {
        return recordable
    }
    
    public func isClosed() -> Bool {
        return closed
    }
    
    public func getFirstTime() -> Date {
        return firstTime
    }
    
    public func getLastTime() -> Date {
        return lastTime
    }
    
    public func getDuration() -> TimeInterval {
        return lastTime - firstTime
    }
    
    public func setName(name: String?) {
        self.name = name
    }
    
    public func getName() -> String? {
        return name
    }
}

public class UniqueVenue {
    // Country code. Necessary as venueCode is unique per country-state combination only
    private let country: UInt16
    // State code. Necessary as venueCode is unique per country-state combination only
    private let state: UInt16
    
    // The unique venue code
    private let code: UInt32
    
    // Name
    private let name: String?
    
    public init(country: UInt16, state: UInt16, venue: UInt32, name: String? = nil) {
        self.country = country
        self.state = state
        self.code = venue
        self.name = name
    }
    
    public func getCountry() -> UInt16 {
        return country
    }
    
    public func getState() -> UInt16 {
        return state
    }
    
    public func getCode() -> UInt32 {
        return code
    }
    
    public func getName() -> String {
        guard let name = name else {
            return "Unknown"
        }
        return name
    }
}

extension UniqueVenue : Equatable {
    public static func == (lhs: UniqueVenue, rhs: UniqueVenue) -> Bool {
        return lhs.country == rhs.country && lhs.state == rhs.state && lhs.code == rhs.code
    }
}

public class VenueDiary: NSObject, SensorDelegate {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Analysis.VenueDiary")
    private var textFile: TextFile?
    private let dateFormatter = DateFormatter()
    private let queue: DispatchQueue
    private var encounters: [VenueDiaryEvent] = []
    
    var delegates: [VenueDiaryDelegate] = []
    
    public func add(_ delegate: VenueDiaryDelegate) {
        delegates.append(delegate)
    }
    
    public override init() {
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        queue = DispatchQueue(label: "Sensor.Analysis.VenueDiary")
        textFile = nil
        super.init()
    }
    
    // MARK:- Internal State methods
    
    /// Set the file to save the data to
    public func setRecordingFile(_ file: TextFile) {
        textFile = file
        loadAll()
    }
    
    private func loadAll() {
        // DUMMY for TDD
    }
    
    private func saveAll() {
        // NOTE: filter by venueDiaryDefaultRecordingDays
        // DUMMY for TDD
    }
    
    /// Find a contact event and add to it, or create a new one
    public func findOrCreateEvent(country: UInt16,state:UInt16,venue:UInt32,
                                  name: String? = nil, extended: ExtendedData? = nil, seen at: Date, with payload: PayloadData?) -> VenueDiaryEvent {
        logger.debug("findOrCreateEvent (country=\(country), state=\(state), venue=\(venue)")
        // TODO ensure events are ordered by isClosed(false then true), and then lastSeen time
        // find in list by country, state, code, and isClosed == false
        for evt in encounters {
            if (evt.getCountry() == country && evt.getState() == state && evt.getCode() == venue) {
                // found
                // Check to see if this event closes it
                // If not, then it adds time, so is fine
                let extends = evt.addPresenceIfSameEvent(at)
                if extends {
                    evt.payload = payload
                    evt.extended = extended
                    delegates.forEach({ (delegate) in
                        delegate.venue(evt)
                    })
                    return evt
                }
                // We don't break because there may be multiple events for the same venue
            }
        }
        // If so, create a new event and return; OR
        // If not found, create a new event and return
        // TODO use payload somewhere
        let newEvent = VenueDiaryEvent(country: country, state: state, venue: venue,
                                       name: name, firstSeen: at)
        encounters.append(newEvent)
        newEvent.payload = payload
        delegates.forEach({ (delegate) in
            delegate.venue(newEvent)
        })
        return newEvent
    }
    
    /// MARK: Public informational methods
    public func eventListCount() -> Int {
        return encounters.count
    }
    
    public func uniqueVenueCount() -> Int {
        var venuesSeen : [UniqueVenue] = []
        for evt in encounters {
            let uv = UniqueVenue(country: evt.getCountry(),state: evt.getState(),venue: evt.getCode())
            if !venuesSeen.contains(uv) {
                venuesSeen.append(uv)
            }
        }
        return venuesSeen.count
    }
    
    /// Return all recordable events
    public func listRecordableEvents() -> [VenueDiaryEvent] {
        // DUMMY for TDD - TODO filter for actual recordable events
        return encounters
    }
    
    /// Return latest diary event, optionally may return latest that isn't yet recordable (so you can monitor the feature in a UI)
    public func getLatestEvent(_ recordableOnly: Bool = false) -> VenueDiaryEvent? {
        guard 0 < encounters.count else {
            return nil
        }
        // DUMMY for TDD
        return nil
    }
    
    // MARK:- SensorDelegate
    
    /// Utility function, mainly for testing. Could also be used for external event definitions (E.g. QR code scan)
    public func addEncounter(_ encounter : VenueEncounter, with payload: PayloadData?, at: Date = Date()) -> VenueDiaryEvent? {
        guard let venue = encounter.getVenue() else {
            return nil
        }
        return findOrCreateEvent(country: venue.getCountry(),
                                  state: venue.getState(),
                                  venue: venue.getCode(),
                                  name: venue.getName(),
                                  extended: encounter.getExtended(),
                                  seen: at,
                                  with: payload)
    }
    
    public func sensor(_ sensor: SensorType, didMeasure: Proximity, fromTarget: TargetIdentifier, withPayload: PayloadData) {
        // parse payload if venue
        guard sensor == SensorType.BLE || sensor == SensorType.BEACON || sensor == SensorType.BLMESH else {
            // Not going to be a useful payload, so return
            return
        }
        do {
            guard let encounter = try VenueEncounter(didMeasure, withPayload) else {
                return
            }
            logger.debug("didVisit(payload=\(withPayload.shortName))")
            let _ = addEncounter(encounter, with: withPayload, at: Date())
        } catch VenuePayloadParseError.UnsupportedPayloadIdAndVersion {
            // Payload is not a Herald beacon, this will be a common condition
            return
        } catch {
            // Parse payload failed, this should be logged
            logger.fault("didVisit parse error (payload=\(withPayload.shortName),error=\(error))")
            return
        }
    }
}

public enum VenuePayloadParseError : Error {
    case EmptyData
    case DataTooShort
    case InvalidDataValue(explanation: String)
    case UnsupportedPayloadIdAndVersion(identifier: UInt8)
}

public enum HeraldBeaconPayloadVersions : UInt8 {
    case V1 = 0x30
    case V2 = 0x31
    case V3 = 0x32
    case V4 = 0x33
    case V5 = 0x34
    case V6 = 0x35
    case V7 = 0x36
    case V8 = 0x37
}

/// Encounter record describing proximity with target at a moment in time
public class VenueEncounter {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "Analysis.VenueEncounter")
    
    let timestamp: Date
    let proximity: Proximity
    let payload: PayloadData
    
    // Parsed data
    var venueData: UniqueVenue?
    var extendedData: ExtendedData?
    
    var csvString: String { get {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let f0 = dateFormatter.string(from: timestamp)
        let f1 = proximity.value.description
        let f2 = proximity.unit.rawValue
        let f3 = proximity.calibration?.value.description ?? ""
        let f4 = proximity.calibration?.unit.rawValue ?? ""
        let f5 = payload.base64EncodedString()
        return "\(f0),\(f1),\(f2),\(f3),\(f4),\(f5)"
    }}
    
    /// Create encounter instance from source data
    public init?(_ didMeasure: Proximity, _ withPayload: PayloadData, timestamp: Date = Date()) throws {
        self.timestamp = timestamp
        self.proximity = didMeasure
        self.payload = withPayload
        try parsePayload()
    }

    /// Create encounter instance from log entry
    init?(_ row: String) {
        let fields = row.split(separator: ",")
        guard fields.count >= 6 else {
            return nil
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let timestamp = dateFormatter.date(from: String(fields[0])) else {
            return nil
        }
        self.timestamp = timestamp
        guard let proximityValue = Double(String(fields[1])) else {
            return nil
        }
        guard let proximityUnit = ProximityMeasurementUnit.init(rawValue: String(fields[2])) else {
            return nil
        }
        var calibration: Calibration? = nil
        if let calibrationValue = Double(String(fields[3])), let calibrationUnit = CalibrationMeasurementUnit.init(rawValue: String(fields[4])) {
            calibration = Calibration(unit: calibrationUnit, value: calibrationValue)
        }
        self.proximity = Proximity(unit: proximityUnit, value: proximityValue, calibration: calibration)
        guard let payload = PayloadData(base64Encoded: String(fields[5])) else {
            return nil
        }
        self.payload = payload
    }
    
    public func getVenue() -> UniqueVenue? {
        return venueData
    }
    
    private func parsePayload() throws {
        if (payload.count == 0) {
            throw VenuePayloadParseError.EmptyData
        }
        if (payload.count < 9) {
            throw VenuePayloadParseError.DataTooShort
        }
        // attempt to parse the payload
        // Read payload ID and version, and if we don't support it just return OK (forward compatibility)
        let payloadIdAndVersion : UInt8 = payload.data[0]
        if HeraldBeaconPayloadVersions.V1.rawValue == payloadIdAndVersion {
            // default parser
        } else if (payloadIdAndVersion > HeraldBeaconPayloadVersions.V1.rawValue) && (payloadIdAndVersion <= HeraldBeaconPayloadVersions.V8.rawValue) {
            // assume the default parser is fine
        } else {
            throw VenuePayloadParseError.UnsupportedPayloadIdAndVersion(identifier: payloadIdAndVersion)
        }
        logger.debug("Protocol code: \(payloadIdAndVersion), HeraldV1Beacon raw: \(HeraldBeaconPayloadVersions.V1.rawValue)")
        // If we do support it, attempt to parse
        let countryData : Data = payload.subdata(in: 1..<3) // bytes at pos 1 and 2
        logger.debug("Country: \(countryData.hexEncodedString)")
        let stateData : Data = payload.subdata(in: 3..<5) // bytes at pos 3 and 4
        logger.debug("stateData: \(stateData.hexEncodedString)")
        let venueCodeData : Data = payload.subdata(in: 5..<9) // bytes at pos 5 and 6 and 7 and 8
        logger.debug("venueCodeData: \(venueCodeData.hexEncodedString)")
        var ed : ConcreteExtendedDataV1? = nil
        var name: String? = nil
        if (payload.count > 9) {
            ed = ConcreteExtendedDataV1(PayloadData(payload.subdata(in: 9..<payload.count)))
            let sections = ed!.getSections()
            for section in sections {
                if section.code == ExtendedDataSegmentCodesV1.TextPremises.rawValue {
                    name = String(bytes: section.data, encoding: .utf8)
                }
            }
        }
        // If parsing fails, throw
        // If all succeeds, set members
        let countryInt : UInt16 = countryData.uint16(0)!
        let stateInt : UInt16 = stateData.uint16(0)!
        let codeInt : UInt32 = venueCodeData.uint32(0)!
        logger.debug("countryInt: \(countryInt), stateInt: \(stateInt), venueInt: \(codeInt)")
        let uv : UniqueVenue = UniqueVenue(country: countryInt,
                                           state: stateInt,
                                           venue: codeInt,
                                           name: name)
        self.venueData = uv
        self.extendedData = ed
    }
    
    public func getExtended() -> ExtendedData? {
        return extendedData
    }
}
