//
//  UltrasoundSensor.swift
//  C19X-SENSOR-iOS
//
//  Created by Freddy Choi on 24/07/2020.
//  Copyright © 2020 C19X. All rights reserved.
//

import Foundation
import AVFoundation

/// WORK IN PROGRESS
protocol UltrasoundSensor : Sensor {
}

/**
 Proximity sensor based on CoreAudio.
 Requires : Signing & Capabilities : BackgroundModes : Audio, AirPlay and Picture in Picture = YES
 Requires : Info.plist : Privacy - Microphone Usage Description
 */
class ConcreteUltrasoundSensor : NSObject, UltrasoundSensor {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "ConcreteUltrasoundSensor")
    private var delegates: [SensorDelegate] = []
    
    func add(delegate: SensorDelegate) {
        delegates.append(delegate)
    }
    
    func start() {
        logger.debug("start")
    }
    
    func stop() {
        logger.debug("stop")
    }
}

class UltrasoundReceiver : NSObject {
    private let logger = ConcreteSensorLogger(subsystem: "Sensor", category: "UltrasoundReceiver")
    private let audioSession = AVAudioSession.sharedInstance()
    private let audioEngine = AVAudioEngine()

    override init() {
        logger.debug("init")
        super.init()
        audioSession.requestRecordPermission() { [unowned self] allowed in
            if allowed {
                self.logger.debug("requestRecordPermission=allowed")
            } else {
                self.logger.fault("requestRecordPermission=denied")
            }
        }
        do {
            if #available(iOS 10.0, *) {
                try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
            } else {
                try audioSession.setCategory(.playAndRecord, options: [.mixWithOthers, .defaultToSpeaker])
            }
            try audioSession.setActive(true)
        } catch {
            logger.fault("audioSession configuration and start failed (error=\(error.localizedDescription))")
        }
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1000, format: nil) { buffer, time in
            let bufferLength = Int(buffer.frameLength)
            guard let pointee = buffer.floatChannelData?.pointee else {
                return
            }
            var values: [Float] = .init(repeating: 0, count: bufferLength)
            for i in (0...bufferLength) {
                values[i] = pointee[i]
            }
            self.fft(frame: values)
        }
    }
    
    private func fft(frame: [Float]) {
        
    }
    
    func start() {
        do {
            try audioEngine.start()
        } catch let error as NSError {
            print("Got an error starting audioEngine: \(error.domain), \(error)")
        }
    }

    func stop() {
    }
}
