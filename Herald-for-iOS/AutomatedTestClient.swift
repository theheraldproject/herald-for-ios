//
//  AutomatedTestClient.swift
//
//  Copyright 2021 Herald Project Contributors
//  SPDX-License-Identifier: Apache-2.0
//

import Foundation
import UIKit
import Herald

class AutomatedTestClient: SensorDelegate {
    private let logger = Log(subsystem: "Herald", category: "AutomatedTestClient")
    private let serverAddress: String
    private let sensorArray: SensorArray
    private let heartbeatInterval: TimeInterval
    private var timerThread: Timer?
    private var resettables: [Resettable] = []
    private var commandQueue: [String] = []
    private let executorService = DispatchQueue(label: "App.AutomatedTestClient")
    private var sensorArrayState: Bool = false
    private var lastTimerCallback: Date = Date.distantPast
    private var lastActionHeartbeat: Date = Date.distantPast
    private var processingQueue: Bool = false
    
    
    init(serverAddress: String, sensorArray: SensorArray, heartbeatInterval: TimeInterval) {
        self.serverAddress = (serverAddress.hasSuffix("/") ? serverAddress : "\(serverAddress)/")
        self.sensorArray = sensorArray
        self.heartbeatInterval = heartbeatInterval
        self.timerThread = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.timerCallback), userInfo: nil, repeats: true)
        // Add resettable
        add(ConcreteSensorLogger(subsystem: "App", category: "AutomatedTestClient"))
    }
    
    /// Timer callback to trigger process queue once per second
    @objc func timerCallback() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTimerCallback)
        guard elapsed >= TimeInterval(1) else {
            return
        }
        executorService.async {
            guard now.timeIntervalSince(self.lastActionHeartbeat) > self.heartbeatInterval else {
                return
            }
            self.actionHeartbeat()
            self.lastActionHeartbeat = now
        }
        lastTimerCallback = now
    }
    
    // MARK: - SensorDelegate
    
    func sensor(_ sensor: SensorType, didUpdateState: SensorState) {
        guard sensor == .ARRAY else {
            return
        }
        sensorArrayState = (didUpdateState == .on)
        logger.debug("sensor (didUpdateState=\(didUpdateState))")
        actionHeartbeat()
    }
    
    /// Add resettable item for resetting on clear action.
    func add(_ resettable: Resettable) {
        resettables.append(resettable)
    }
    
    func processQueue() {
        guard !processingQueue else {
            return
        }
        while !commandQueue.isEmpty {
            processingQueue = true
            let command = commandQueue.removeFirst()
            if "start" == command {
                logger.debug("processQueue, processing (command=start,action=startSensorArray)")
                sensorArray.start()
            } else if "stop" == command {
                logger.debug("processQueue, processing (command=stop,action=stopSensorArray)")
                sensorArray.stop()
            } else if command.starts(with: "upload") {
                let filename = String(command.dropFirst("upload(".count).dropLast(1))
                logger.debug("processQueue, processing (command=upload,action=uploadFile,filename=\(filename))")
                actionUpload(filename)
            } else if "clear" == command {
                logger.debug("processQueue, processing (command=clear,action=clear)")
                actionClear()
            } else {
                logger.fault("processQueue, ignoring unknown command (command=\(command))")
            }
        }
        processingQueue = false
    }
    
    // MARK: - Actions
    
    func actionHeartbeat() {
        guard let payloadData = sensorArray.payloadData else {
            return
        }
        serverHeartbeat(
            model: UIDevice.current.name,
            os: "iOS",
            version: UIDevice.current.systemVersion,
            payload: ConcretePayloadDataFormatter().shortFormat(payloadData),
            status: (sensorArrayState ? "on" : "off"),
            postProcess: processQueue)
    }
    
    func actionUpload(_ filename: String) {
        guard let payloadData = sensorArray.payloadData else {
            return
        }
        serverUpload(
            model: UIDevice.current.name,
            os: "iOS",
            version: UIDevice.current.systemVersion,
            payload: ConcretePayloadDataFormatter().shortFormat(payloadData),
            status: (sensorArrayState ? "on" : "off"),
            filename: filename)
    }
    
    func actionClear() {
        resettables.forEach({ $0.reset() })
    }
    
    // MARK: - Server API

    private func serverHeartbeat(model: String, os: String, version: String, payload: String, status: String, postProcess: @escaping () -> Void) {
        let urlString = "\(serverAddress)heartbeat?model=\(model.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!)&os=\(os.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!)&version=\(version.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!)&payload=\(payload.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!)&status=\(status.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!)"
        guard let url = URL(string: urlString) else {
            logger.fault("serverHeartbeat, invalid URL (url=\(urlString))")
            return
        }
        let getUrlTask = URLSession.shared.dataTask(with: url) { data, responseStatusCode, error in
            self.lastActionHeartbeat = Date()
            guard let data = data, error == nil else {
                self.logger.fault("serverHeartbeat, failed to get URL (url=\(url))")
                return
            }
            guard let response = String(data: data, encoding: .utf8) else {
                self.logger.fault("serverHeartbeat, failed to decode response data")
                return
            }
            guard !response.isEmpty else {
                self.logger.fault("serverHeartbeat, no response from server")
                return
            }
            guard response.starts(with: "ok") else {
                self.logger.fault("serverHeartbeat, server responded with error (response=\(response))")
                return
            }
            let commands: [String] = response.split(separator: ",").map({ String($0) })
            if commands.count > 1 {
                for i in 1...commands.count-1 {
                    self.commandQueue.append(commands[i])
                }
            }
            self.logger.debug("serverHeartbeat, complete (commandQueue=\(self.commandQueue))")
            postProcess()
            self.logger.debug("serverHeartbeat, post process complete")
        }
        getUrlTask.resume()
    }

    private func serverUpload(model: String, os: String, version: String, payload: String, status: String, filename: String) {
        let urlString = "\(serverAddress)upload?model=\(model.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!)&os=\(os.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!)&version=\(version.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!)&payload=\(payload.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!)&status=\(status.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!)&filename=\(filename.addingPercentEncoding(withAllowedCharacters: .rfc3986Unreserved)!)"
        guard let url = URL(string: urlString) else {
            logger.fault("serverUpload, invalid URL (url=\(urlString))")
            return
        }
        guard let fileUrl = TextFile(filename: filename).url else {
            logger.fault("serverUpload, invalid file (filename=\(filename))")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let postUrlTask = URLSession.shared.uploadTask(with: request, fromFile: fileUrl) { data, responseStatusCode, error in
            self.lastActionHeartbeat = Date()
            guard let data = data, error == nil else {
                self.logger.fault("serverUpload, failed to get URL (url=\(url))")
                return
            }
            guard let response = String(data: data, encoding: .utf8) else {
                self.logger.fault("serverUpload, failed to decode response data")
                return
            }
            guard !response.isEmpty else {
                self.logger.fault("serverUpload, no response from server")
                return
            }
            guard response.starts(with: "ok") else {
                self.logger.fault("serverUpload, server responded with error (response=\(response))")
                return
            }
            self.logger.debug("serverUpload, complete (response=\(response))")
        }
        postUrlTask.resume()
    }
}

extension CharacterSet {
    static let rfc3986Unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}
