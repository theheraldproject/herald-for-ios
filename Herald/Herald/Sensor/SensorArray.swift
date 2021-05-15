//
//  SensorArray.swift
//
//  Copyright 2020-2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import UIKit

/// Sensor array for combining multiple detection and tracking methods.
public class SensorArray : NSObject, Sensor {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "SensorArray")
    private var sensorArray: [Sensor] = []
    public let payloadData: PayloadData?
    public static let deviceDescription = "\(UIDevice.current.name) (iOS \(UIDevice.current.systemVersion))"
    private var concreteBle: ConcreteBLESensor?;
    
    public init(_ payloadDataSupplier: PayloadDataSupplier) {
        logger.debug("init")
        // Mobility sensor enables background BLE advert detection
        // - This is optional because an Android device can act as a relay,
        //   but enabling location sensor will enable direct iOS-iOS detection in background.
        // - Please note, the actual location is not used or recorded by HERALD.
        if let mobilitySensorResolution = BLESensorConfiguration.mobilitySensorEnabled {
            sensorArray.append(ConcreteMobilitySensor(resolution: mobilitySensorResolution, rangeForBeacon: UUID(uuidString:  BLESensorConfiguration.serviceUUID.uuidString)))
        }
        // BLE sensor for detecting and tracking proximity
        concreteBle = ConcreteBLESensor(payloadDataSupplier)
        sensorArray.append(concreteBle!)
        
        // Payload data at initiation time for identifying this device in the logs
        payloadData = payloadDataSupplier.payload(PayloadTimestamp(), device: nil)
        super.init()
        logger.debug("device (os=\(UIDevice.current.systemName)\(UIDevice.current.systemVersion),model=\(deviceModel()))")

        // Inertia sensor configured for automated RSSI-distance calibration data capture
        if BLESensorConfiguration.inertiaSensorEnabled {
            logger.debug("Inertia sensor enabled");
            sensorArray.append(ConcreteInertiaSensor());
            add(delegate: CalibrationLog(filename: "calibration.csv"));
        }

        if let payloadData = payloadData {
            logger.info("DEVICE (payloadPrefix=\(payloadData.shortName),description=\(SensorArray.deviceDescription))")
        } else {
            logger.info("DEVICE (payloadPrefix=EMPTY,description=\(SensorArray.deviceDescription))")
        }
        
//        // Test Diffie-Hellman on hardware
//        DispatchQueue(label: "Sensor.SensorArray.dhkaQueue").async {
//            self.test_dh()
//        }
    }
    
    private func deviceModel() -> String {
        var deviceInformation = utsname()
        uname(&deviceInformation)
        let mirror = Mirror(reflecting: deviceInformation.machine)
        return mirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else {
                return identifier
            }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
    }
    
    public func immediateSend(data: Data, _ targetIdentifier: TargetIdentifier) -> Bool {
        return concreteBle!.immediateSend(data: data,targetIdentifier);
    }
    
    public func immediateSendAll(data: Data) -> Bool {
        return concreteBle!.immediateSendAll(data: data);
    }
    
    public func add(delegate: SensorDelegate) {
        sensorArray.forEach { $0.add(delegate: delegate) }
    }
    
    public func start() {
        logger.debug("start")
        sensorArray.forEach { $0.start() }
    }
    
    public func stop() {
        logger.debug("stop")
        sensorArray.forEach { $0.stop() }
    }
    
//    // MARK: - Instrumented DH test
//
//    func test_dh() {
//        // MODP Group 1 : First Oakley Group 768-bits, generator = 2
//        let modpGroup1: String = (
//            "FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1" +
//            "29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD" +
//            "EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245" +
//            "E485B576 625E7EC6 F44C42E9 A63A3620 FFFFFFFF FFFFFFFF")
//            .replacingOccurrences(of: " ", with: "")
//        // MODP Group 2 : Second Oakley Group 1024-bits, generator = 2
//        let modpGroup2: String = (
//            "FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1" +
//            "29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD" +
//            "EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245" +
//            "E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED" +
//            "EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE65381" +
//            "FFFFFFFF FFFFFFFF")
//            .replacingOccurrences(of: " ", with: "")
//        let modpGroup5: String = (
//            "FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1" +
//            "29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD" +
//            "EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245" +
//            "E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED" +
//            "EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE45B3D" +
//            "C2007CB8 A163BF05 98DA4836 1C55D39A 69163FA8 FD24CF5F" +
//            "83655D23 DCA3AD96 1C62F356 208552BB 9ED52907 7096966D" +
//            "670C354E 4ABC9804 F1746C08 CA237327 FFFFFFFF FFFFFFFF")
//            .replacingOccurrences(of: " ", with: "")
//        let modpGroup14: String = (
//            "FFFFFFFF FFFFFFFF C90FDAA2 2168C234 C4C6628B 80DC1CD1" +
//            "29024E08 8A67CC74 020BBEA6 3B139B22 514A0879 8E3404DD" +
//            "EF9519B3 CD3A431B 302B0A6D F25F1437 4FE1356D 6D51C245" +
//            "E485B576 625E7EC6 F44C42E9 A637ED6B 0BFF5CB6 F406B7ED" +
//            "EE386BFB 5A899FA5 AE9F2411 7C4B1FE6 49286651 ECE45B3D" +
//            "C2007CB8 A163BF05 98DA4836 1C55D39A 69163FA8 FD24CF5F" +
//            "83655D23 DCA3AD96 1C62F356 208552BB 9ED52907 7096966D" +
//            "670C354E 4ABC9804 F1746C08 CA18217C 32905E46 2E36CE3B" +
//            "E39E772C 180E8603 9B2783A2 EC07A28F B5C55DF0 6F4C52C9" +
//            "DE2BCBF6 95581718 3995497C EA956AE5 15D22618 98FA0510" +
//            "15728E5A 8AACAA68 FFFFFFFF FFFFFFFF")
//            .replacingOccurrences(of: " ", with: "")
//
//        let p = UIntBig(modpGroup1)!
//        let g = UIntBig(2)
//        logger.debug("DHKA: p bits: \(p.bitLength())")
//        logger.debug("DHKA: g bits: \(g.bitLength())")
//        logger.debug("DHKA: p = \(p.hexEncodedString)")
//
//        let secureRandom = RandomSource(method: .SecureRandom)
//        let alicePrivateKey = UIntBig(bitLength: p.bitLength()-2, random: secureRandom)!
//        logger.debug("DHKA: alice private key bits: \(alicePrivateKey.bitLength())")
//        logger.debug("DHKA: alice private key = \(alicePrivateKey.hexEncodedString)")
//        let alicePublicKey = g.modPow(alicePrivateKey, p)
//        logger.debug("DHKA: alice public key bits: \(alicePublicKey.bitLength())")
//        logger.debug("DHKA: alice public key = \(alicePublicKey.hexEncodedString)")
//
//        let bobPrivateKey = UIntBig(bitLength: p.bitLength()-2, random: secureRandom)!
//        logger.debug("DHKA: bob private key bits: \(bobPrivateKey.bitLength())")
//        logger.debug("DHKA: bob private key = \(bobPrivateKey.hexEncodedString)")
//        let bobPublicKey = g.modPow(bobPrivateKey, p)
//        logger.debug("DHKA: bob public key bits: \(bobPublicKey.bitLength())")
//        logger.debug("DHKA: bob public key = \(bobPublicKey.hexEncodedString)")
//
//        let aliceSharedKey = bobPublicKey.modPow(alicePrivateKey, p)
//        logger.debug("DHKA: alice shared key bits: \(aliceSharedKey.bitLength())")
//        logger.debug("DHKA: alice shared key = \(aliceSharedKey.hexEncodedString)")
//        let bobSharedKey = alicePublicKey.modPow(bobPrivateKey, p)
//        logger.debug("DHKA: bob shared key bits: \(bobSharedKey.bitLength())")
//        logger.debug("DHKA: bob shared key = \(bobSharedKey.hexEncodedString)")
//        logger.debug("DHKA: alice and bob have same shared key = \(aliceSharedKey == bobSharedKey)")
//    }
}
