//
//  MAVLinkUDPManager.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 03/09/25.
//

import Foundation
import Network
import Combine

enum MAVLinkConnectionState {
    case NOT_CONNECTED
    case CONNECTING
    case CONNECTED
    case FAILED
}

struct MAVHeartBeatPacket {
    let isArmed: Bool
    let vehcileType: UInt8
    let autiPilot: UInt8
    let customMode: UInt32
    let systemStatus: UInt8
}

struct MAVAttitudePacket {
    let rollDeg: Float
    let pitchDeg: Float
    let yawDeg: Float
    let rollRate: Float
    let pitchRate: Float
    let yawRate: Float
}

struct MAVAltitudePacket {
    let lat: Double
    let long: Double
    let absoluteAltitude: Float
    let relativeAltitude: Float
}

struct MAVStatusTextPacket {
    let text: String
    let severity: UInt8
}

struct MAVParamValuePacket {
    let uuid: UUID = UUID()
    let id: String
    let value: Float
}

fileprivate protocol MAVLinkDelegate: AnyObject {
    func didReceiveHeartbeat(_ packet: MAVHeartBeatPacket)
    func didReceiveAttitude(_ packet: MAVAttitudePacket)
    func didReceiveAltitude(_ packet: MAVAltitudePacket)
    func didReceiveStatusText(_ packet: MAVStatusTextPacket)
    func didReceiveParamValue(_ packet: MAVParamValuePacket)
}

fileprivate final class MAVLinkBridge {
    static let shared = MAVLinkBridge()
    
    weak var delegate: MAVLinkDelegate?
}

final class MAVLinkUDPManager {
    
    static var shared: MAVLinkUDPManager = MAVLinkUDPManager()
    
    private var gcsClient: CF_GCSUDP_t = CF_GCSUDP_t()
    private var receiveTask: Task<Void, Never>?
    private var isReceiving: Bool = false
    private var failedDiscoveryCount: Int = 0
    
    private var lastHeartbeatSent: Date?
    private var lastHeartbeatReceived: Date?
    private var missedHeartbeatCount: Int = 0
    private let maxMissedHeartbeat: Int = 10
    
    private var heartbeatCancellation: AnyCancellable?
    
    private var paramList: [MAVParamValuePacket] = []
    
    let heartbeatPacket: CurrentValueSubject<MAVHeartBeatPacket?, Never> = CurrentValueSubject<MAVHeartBeatPacket?, Never>(nil)
    let attitudePacket: CurrentValueSubject<MAVAttitudePacket?, Never> = CurrentValueSubject<MAVAttitudePacket?, Never>(nil)
    let altitudePacket: CurrentValueSubject<MAVAltitudePacket?, Never> = CurrentValueSubject<MAVAltitudePacket?, Never>(nil)
    let statusTextPacket: CurrentValueSubject<MAVStatusTextPacket?, Never> = CurrentValueSubject<MAVStatusTextPacket?, Never>(nil)
    let paramListPacket: CurrentValueSubject<[MAVParamValuePacket], Never> = CurrentValueSubject<[MAVParamValuePacket], Never>([])
    let connectionStatus: CurrentValueSubject<MAVLinkConnectionState, Never> = CurrentValueSubject<MAVLinkConnectionState, Never>(.NOT_CONNECTED)
    
    init() {
        CF_gcs_udp_init(&gcsClient)
        setupMAVLinkCallbacks()
        MAVLinkBridge.shared.delegate = self
    }
    
    func connect(port: UInt16 = 14550) {
        connectionStatus.send(.CONNECTING)
        
        Task {
            var ipBuffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            
            let result = CF_gcs_udp_discover_drone(Int32(port), 5000, &ipBuffer, Int(INET_ADDRSTRLEN))
            
            await MainActor.run { [ipBuffer] in
                if result, let droneIP = String(validatingUTF8: ipBuffer) {
                    connectToDrone(ip: droneIP, port: port)
                } else if failedDiscoveryCount > 5 {
                    connectionStatus.send(.FAILED)
                    failedDiscoveryCount = 0
                } else {
                    failedDiscoveryCount += 1
                    DispatchQueue.main .asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.connect()
                    }
                }
            }
        }
    }
    
    func actionArm() {
        sendAction { buffer, size in
            CF_gcs_build_arm_disarm(buffer, size, true)
        }
    }
    
    func actionDisarm() {
        sendAction { buffer, size in
            CF_gcs_build_arm_disarm(buffer, size, false)
        }
    }
    
    func actionManualControl(roll: Int16, pitch: Int16, yaw: Int16, throttle: Int16) {
        sendAction { buffer, size in
            CF_gcs_build_manual_control(buffer, size, roll, pitch, yaw, throttle)
        }
    }
    
    func actionCalibrateIMU() {
        sendAction { buffer, size in
            CF_gcs_build_calibrate_imu(buffer, size)
        }
    }
    
    func actionCalibrateBaro() {
        sendAction { buffer, size in
            CF_gcs_build_calibrate_baro(buffer, size)
        }
    }
    
    func actionTakeoff() {
        sendAction { buffer, size in
            CF_gcs_build_takeoff(buffer, size)
        }
    }
    
    func actionRequestParamList() {
        paramList.removeAll()
        sendAction { buffer, size in
            CF_gcs_build_param_list(buffer, size)
        }
    }
    
    func actionSetParam(_ id: String, _ value: Float) {
        sendAction { buffer, size in
            CF_gcs_build_set_param(buffer, size, id, value)
        }
    }
    
    func removeParamList() {
        paramList.removeAll()
    }
    
    func disconnect() {
        guard connectionStatus.value != .NOT_CONNECTED else { return }
        
        // Clean up network
        isReceiving = false
        receiveTask?.cancel()
        receiveTask = nil
        heartbeatCancellation?.cancel()
        heartbeatCancellation = nil
        
        // Reset state
        connectionStatus.send(.NOT_CONNECTED)
        missedHeartbeatCount = 0
        failedDiscoveryCount = 0
        lastHeartbeatReceived = nil
        lastHeartbeatSent = nil
        paramList.removeAll()
        
        // Close socket
        CF_gcs_udp_disconnect(&gcsClient)
    }
    
    private func connectToDrone(ip: String, port: UInt16) {
        let result = CF_gcs_udp_connect(&gcsClient, ip, Int32(port))
        
        if result {
            sendIntervalHeartbeat()
            startReceiving()
        } else {
            connectionStatus.send(.FAILED)
        }
    }
    
    private func startReceiving() {
        isReceiving = true
        
        receiveTask = Task {
            var buffer = [UInt8](repeating: 0, count: 2048)
            var consecutiveErrors = 0
            
            while isReceiving && !Task.isCancelled {
                let bytesReceived = CF_gcs_udp_receive(&gcsClient, &buffer, buffer.count)
                
                if bytesReceived > 0 {
                    consecutiveErrors = 0
                    
                    buffer.withUnsafeBytes { rawBuffer in
                        CF_gcs_parser_process(rawBuffer.bindMemory(to: UInt8.self).baseAddress!, Int(bytesReceived))
                    }
                    
                } else if bytesReceived == 0 {
                    consecutiveErrors = 0
                    
                } else {
                    consecutiveErrors += 1
                    if consecutiveErrors > 100 {
                        break
                    }
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000)
            }
        }
    }
    
    private func setupMAVLinkCallbacks() {
        var callback = CF_GCSCallback_t()
        
        callback.on_heartbeat = { (isArmed, vehicleType, autopilot, customMode, systemStatus) in
            let heartbeatPacket = MAVHeartBeatPacket(
                isArmed: isArmed,
                vehcileType: vehicleType,
                autiPilot: autopilot,
                customMode: customMode,
                systemStatus: systemStatus
            )
            
            MAVLinkBridge.shared.delegate?.didReceiveHeartbeat(heartbeatPacket)
        }
        
        callback.on_attitude = { (rollDeg, pitchDeg, yawDeg, rollRate, pitchRate, yawRate) in
            let attitudePacket = MAVAttitudePacket(
                rollDeg: rollDeg,
                pitchDeg: pitchDeg,
                yawDeg: yawDeg,
                rollRate: rollRate,
                pitchRate: pitchRate,
                yawRate: yawRate
            )
            
            MAVLinkBridge.shared.delegate?.didReceiveAttitude(attitudePacket)
        }
        
        callback.on_position = { (lat, lon, altM, relativeAltM) in
            let altitudePacket = MAVAltitudePacket(
                lat: lat,
                long: lon,
                absoluteAltitude: altM,
                relativeAltitude: relativeAltM
            )
            
            MAVLinkBridge.shared.delegate?.didReceiveAltitude(altitudePacket)
        }
        
        callback.on_status_text = { (text, severity) in
            guard let text else { return }
            let str = String(cString: text)
            let statusTextPacket = MAVStatusTextPacket(text: str, severity: severity)
            
            MAVLinkBridge.shared.delegate?.didReceiveStatusText(statusTextPacket)
        }
        
        callback.on_param_value = { (paramId, paramValue) in
            guard let paramId else { return }
            let id = String(cString: paramId)
            let paramValuePacket = MAVParamValuePacket(id: id, value: paramValue)
            
            MAVLinkBridge.shared.delegate?.didReceiveParamValue(paramValuePacket)
        }
        
        CF_gcs_parser_init(&callback)
    }
    
    private func sendIntervalHeartbeat() {
        heartbeatCancellation = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink(receiveValue: { [weak self] _ in
                guard let self else { return }
                checkConnectionHealth()
                sendHeartbeat()
            })
    }
    
    private func checkConnectionHealth() {
        switch connectionStatus.value {
        case .CONNECTING:
            missedHeartbeatCount += 1
            if missedHeartbeatCount > maxMissedHeartbeat {
                disconnect()
            }
        case .CONNECTED:
            guard let lastHeartbeatReceived else { break }
            let now = Date()
            let latency = now.timeIntervalSince(lastHeartbeatReceived)
            if latency > 10.0 {
                disconnect()
            }
        case .NOT_CONNECTED, .FAILED:
            heartbeatCancellation?.cancel()
            heartbeatCancellation = nil
        }
    }
    
    private func sendHeartbeat() {
        var buffer = [UInt8](repeating: 0, count: 280)
        
        buffer.withUnsafeMutableBytes { bufferPtr in
            guard let baseAddress = bufferPtr.bindMemory(to: UInt8.self).baseAddress else {
                return
            }
            
            let packetLength = CF_gcs_build_heartbeat(baseAddress, bufferPtr.count)
            
            if packetLength > 0 {
                let result = CF_gcs_udp_send(&gcsClient, baseAddress, packetLength)
                if !result {
                    debugPrint("[GCS] Failed to send heartbeat (error: \(result))")
                } else {
                    lastHeartbeatSent = Date()
                }
            } else {
                debugPrint("[GCS] Failed to build heartbeat packet")
            }
        }
    }
    
    private func sendAction(builder: (UnsafeMutablePointer<UInt8>, Int) -> Int) {
        var buffer = [UInt8](repeating: 0, count: 280)
        
        buffer.withUnsafeMutableBytes { bufferPtr in
            guard let baseAddress = bufferPtr.bindMemory(to: UInt8.self).baseAddress else {
                return
            }
            
            let packetLength = builder(baseAddress, bufferPtr.count)
            
            if packetLength > 0 {
                let result = CF_gcs_udp_send(&gcsClient, baseAddress, packetLength)
                
                if !result {
                    debugPrint("[GCS] Failed to send heartbeat (error: \(result))")
                }
            } else {
                debugPrint("[GCS] Failed to build heartbeat packet")
            }
        }
    }
}

extension MAVLinkUDPManager: MAVLinkDelegate {
    
    func didReceiveHeartbeat(_ packet: MAVHeartBeatPacket) {
        if connectionStatus.value == .CONNECTING {
            connectionStatus.send(.CONNECTED)
        }
        
        lastHeartbeatReceived = Date()
        missedHeartbeatCount = 0
        heartbeatPacket.send(packet)
    }
    
    func didReceiveAttitude(_ packet: MAVAttitudePacket) {
        attitudePacket.send(packet)
    }
    
    func didReceiveAltitude(_ packet: MAVAltitudePacket) {
        altitudePacket.send(packet)
    }
    
    func didReceiveStatusText(_ packet: MAVStatusTextPacket) {
        statusTextPacket.send(packet)
    }
    
    func didReceiveParamValue(_ packet: MAVParamValuePacket) {
        paramList.append(packet)
        paramListPacket.send(paramList)
    }
}
