//
//  HomeViewModel.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 31/07/25.
//

import Foundation
import Combine
import GameController

struct MotorData: Identifiable {
    let id: UUID = UUID()
    let timestamp: Date
    let motor1, motor2, motor3, motor4: Int
}

struct EulerAngleData: Identifiable {
    let id: UUID = UUID()
    let timestamp: Date
    let roll, pitch, yaw: Float
}

struct ThrottleData: Identifiable {
    let id: UUID = UUID()
    let timestamp: Date
    let value: Float
}

struct ControlLoopTimeData: Identifiable {
    let id: UUID = UUID()
    let timestamp: Date
    let avgLoopTime: Int
    let currentLoopTime: Int
}

struct AltitudeData: Identifiable {
    let id: UUID = UUID()
    let timestamp: Date
    let absoluteAltitude: Float
    let relativeAltitude: Float
}

struct TelemetryData {
    var isArmed = false
    var attitudeData: CircularBuffer<EulerAngleData> = CircularBuffer(capacity: 25)
    var statusText: CircularBuffer<String> = CircularBuffer(capacity: 50)
    var motorData: CircularBuffer<MotorData> = CircularBuffer(capacity: 25)
    var throttleData: CircularBuffer<ThrottleData> = CircularBuffer(capacity: 25)
    var pidData: CircularBuffer<EulerAngleData> = CircularBuffer(capacity: 25)
    var targetAttitudeData: CircularBuffer<EulerAngleData> = CircularBuffer(capacity: 25)
    var controlLoopTimeData: CircularBuffer<ControlLoopTimeData> = CircularBuffer(capacity: 25)
    var altitudeData: CircularBuffer<AltitudeData> = CircularBuffer(capacity: 25)
    
    var floatParams: [MAVParamValuePacket] = []
}

final class HomeViewModel: ObservableObject {
    
    @Published var isStickConnected: Bool = false
    
    @Published var rollInput: Float = 0.0
    @Published var pitchInput: Float = 0.0
    @Published var yawInput: Float = 0.0
    @Published var throttleInput: Float = 0.0
    
    @Published var isMAVLinkConnected = false
    @Published var connectionStatus = "Disconnected"
    @Published var errorMessage: String?
    @Published var port = "14550"
    
    @Published var telemetryData = TelemetryData()
    @Published var isLoadingParameters = false
    @Published var parametersRefreshTrigger = UUID()
    
    @Published var isRecordingSession: Bool = false
    @Published var maxAutoThrottleValue: String = ""
    @Published var maxManualThrottleValue: String = ""
    
    @Published var stickyThrottle: Bool = false
    
    var isSessionEmpty: Bool {
        return sessionRecorder.isSessionEmpty()
    }
    
    var currentContrroller: GCController?
    
    private let mavlinkManager = MAVLinkUDPManager.shared
    private let sessionRecorder = StreamingSessionRecorder()

    private var connectingDrone: Bool = false
    private var maxManualThrottle: Float = 0.55
    private var manualControlCancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        maxManualThrottleValue = String(maxManualThrottle)
    }
    
    func subscribeToMAVLink() {
        mavlinkManager
            .connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .CONNECTING:
                    connectingDrone = true
                    connectionStatus = "Connecting to Drone"
                case .CONNECTED:
                    connectingDrone = false
                    isMAVLinkConnected = true
                    connectionStatus = "Connected"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.getAllParameters() }
                case .FAILED:
                    connectingDrone = false
                    isMAVLinkConnected = false
                    connectionStatus = "Failed to Connect"
                    clenaup()
                case .NOT_CONNECTED:
                    connectingDrone = false
                    isMAVLinkConnected = false
                    connectionStatus = "Disconnected"
                    clenaup()
                }
            }
            .store(in: &cancellables)
        
        mavlinkManager
            .heartbeatPacket
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] packet in
                guard let self else { return }
                if telemetryData.isArmed != packet.isArmed {
                    resetStickValue()
                }
                telemetryData.isArmed = packet.isArmed
            }
            .store(in: &cancellables)
        
        mavlinkManager
            .attitudePacket
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] packet in
                guard let self else { return }
                
                let timestamp = Date()
                let data = EulerAngleData(
                    timestamp: timestamp,
                    roll: packet.rollDeg,
                    pitch: packet.pitchDeg,
                    yaw: packet.yawDeg
                )
                
                telemetryData.attitudeData.append(data)
                
                if isRecordingSession {
                    sessionRecorder.writeAttitude(
                        roll: packet.rollDeg,
                        pitch: packet.pitchDeg,
                        yaw: packet.yawDeg
                    )
                }
            }
            .store(in: &cancellables)
        
        mavlinkManager
            .altitudePacket
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] packet in
                guard let self else { return }
                let data = AltitudeData(
                    timestamp: Date(),
                    absoluteAltitude: packet.absoluteAltitude,
                    relativeAltitude: packet.relativeAltitude
                )
                
                telemetryData.altitudeData.append(data)
                
                if (isRecordingSession) {
                    sessionRecorder.writeAltitude(absoulte: data.absoluteAltitude, relative: data.relativeAltitude)
                }
            }
            .store(in: &cancellables)
        
        mavlinkManager
            .paramListPacket
            .receive(on: DispatchQueue.main)
            .sink { [weak self] packet in
                guard let self else { return }
                isLoadingParameters = false
                telemetryData.floatParams = packet
                parametersRefreshTrigger = UUID()
            }
            .store(in: &cancellables)
        
        mavlinkManager
            .statusTextPacket
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] packet in
                guard let self else { return }
                let statusText = packet.text
                let timestamp = Date()
                
                if statusText.hasPrefix("DBG:") {
                    let debugValues = statusText
                        .replacingOccurrences(of: "DBG:", with: "")
                        .split(separator: "|")
                    
                    guard debugValues.count >= 3 else { return }
                    
                    let motorValues = debugValues[0]
                        .split(separator: ",")
                        .compactMap { Int($0) }
                    
                    if motorValues.count >= 4 {
                        let data = MotorData(
                            timestamp: timestamp,
                            motor1: motorValues[0],
                            motor2: motorValues[1],
                            motor3: motorValues[2],
                            motor4: motorValues[3]
                        )
                        
                        telemetryData.motorData.append(data)
                        
                        if isRecordingSession {
                            sessionRecorder.writeMotors(
                                m1: data.motor1,
                                m2: data.motor2,
                                m3: data.motor3,
                                m4: data.motor4
                            )
                        }
                    }
                    
                    let pidValues = debugValues[1]
                        .split(separator: ",")
                        .compactMap { Float($0) }
                    
                    if pidValues.count >= 3 {
                        let data = EulerAngleData(
                            timestamp: timestamp,
                            roll: pidValues[0],
                            pitch: pidValues[1],
                            yaw: pidValues[2]
                        )
                        
                        telemetryData.pidData.append(data)
                        
                        if isRecordingSession {
                            sessionRecorder.writePID(roll: pidValues[0], pitch: pidValues[1], yaw: pidValues[2])
                        }
                    }
                    
                    if let throttleValue = Float(debugValues[2]) {
                        let data = ThrottleData(
                            timestamp: timestamp,
                            value: throttleValue
                        )
                        
                        telemetryData.throttleData.append(data)
                        
                        if isRecordingSession {
                            sessionRecorder.writeThrottle(value: throttleValue)
                        }
                    }
                    
                } else if statusText.hasPrefix("TARGET:") {
                    let targetValues = statusText
                        .replacingOccurrences(of: "TARGET:", with: "")
                        .split(separator: ",")
                        .compactMap { Float($0) }
                    
                    guard targetValues.count >= 3 else { return }
                    
                    let data = EulerAngleData(
                        timestamp: timestamp,
                        roll: targetValues[0],
                        pitch: targetValues[1],
                        yaw: targetValues[2]
                    )
                    
                    telemetryData.targetAttitudeData.append(data)
                    
                    if isRecordingSession {
                        sessionRecorder.writeTargetAttitude(roll: targetValues[0], pitch: targetValues[1], yaw: targetValues[2])
                    }
                } else if statusText.hasPrefix("LOOPTIME:") {
                    let targetValues = statusText
                        .replacingOccurrences(of: "LOOPTIME:", with: "")
                        .replacingOccurrences(of: " ", with: "")
                        .split(separator: ",")
                        .compactMap { Int($0) }
                    
                    guard targetValues.count >= 2 else { return }
                    
                    let data = ControlLoopTimeData(
                        timestamp: timestamp,
                        avgLoopTime: targetValues[0],
                        currentLoopTime: targetValues[1]
                    )
                    
                    telemetryData.controlLoopTimeData.append(data)
                    
                    if isRecordingSession {
                        sessionRecorder.writeControlLoopTime(
                            avgFreq: targetValues[0],
                            currentFreq: targetValues[1]
                        )
                    }
                } else {
                    telemetryData.statusText.append(statusText)
                }
            }
            .store(in: &cancellables)
    }
    
    func connectToMAVLink() {
        guard !connectingDrone, !isMAVLinkConnected else { return }
        
        mavlinkManager.connect()
    }
    
    func recordOrStopSession() {
        isRecordingSession ? saveSession() : recordSession()
    }
    
    func armOrDisarmDrone() {
        telemetryData.isArmed ? disarmDrone() : armDrone()
    }
    
    func armDrone() {
        guard isMAVLinkConnected else { return }
        mavlinkManager.actionArm()
        subscribeManualControl()
    }
    
    func disarmDrone() {
        guard isMAVLinkConnected else { return }
        mavlinkManager.actionDisarm()
        unsubscribeManualControl()
    }
    
    func getAllParameters() {
        guard isMAVLinkConnected, !isLoadingParameters else { return }
        
        isLoadingParameters = true
        mavlinkManager.actionRequestParamList()
    }
    
    func refreshParameters() {
        getAllParameters()
    }
    
    func updateParameter(name: String, value: Float?) {
        guard let value else { return }
        
        mavlinkManager.actionSetParam(name, value)
    }
    
    func disconnectMAVLink() {
        mavlinkManager.disconnect()
    }
    
    func stickDidConnect(_ controller: GCController) {
        isStickConnected = true
        currentContrroller = controller
        resetStickValue()
        setupInputControllers(controller)
    }
    
    func stickDidDisconnect() {
        isStickConnected = false
        currentContrroller = nil
        resetStickValue()
    }
    
    func updateMaxManualThrottle(_ value: String) {
        if let value = Float(value), abs(value) >= 0.0 && abs(value) <= 1.0 {
            maxManualThrottle = value
        } else {
            maxManualThrottleValue = String(maxManualThrottle)
        }
    }
    
    func updateParametersFromLastSession() {
        let floatParams = sessionRecorder.getLastParametersData()
        guard floatParams.count > 0 else { return }
        
        mavlinkManager.removeParamList()
        for param in floatParams {
            updateParameter(name: param.id, value: param.value)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.getAllParameters()
        }
    }
    
    func updateThrottleInputStyle() {
        stickyThrottle.toggle()
    }
    
    private func subscribeManualControl() {
        guard isMAVLinkConnected else { return }
        
        manualControlCancellable = Timer.publish(every: 0.05, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, telemetryData.isArmed else { return }
                mavlinkManager.actionManualControl(
                    roll: Int16(rollInput * 1000.0),
                    pitch: Int16(pitchInput * 1000.0),
                    yaw: Int16(yawInput * 1000.0),
                    throttle: Int16(throttleInput * 1000.0)
                )
            }
    }

    
    private func setupInputControllers(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        
        let deadband: Float = 0.10
        
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] (input, xValue, yValue) in
            guard let self else { return }
            self.rollInput = applyDeadband(xValue, deadband: deadband)
            self.pitchInput = applyDeadband(yValue, deadband: deadband)
        }
        
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] (input, xValue, yValue) in
            guard let self else { return }
            
            let updatedValue = applyDeadband(yValue, deadband: deadband)
            
            if stickyThrottle {
                if updatedValue > 0.0 {
                    throttleInput = min(maxManualThrottle, throttleInput + (updatedValue * 0.03))
                } else {
                    throttleInput = max(throttleInput + (updatedValue * 0.03), 0)
                }
            } else {
                guard updatedValue >= 0.0 else { return }
                throttleInput = updatedValue
            }
        }
        
        gamepad.buttonA.pressedChangedHandler = { [weak self] (input, value, isPressed) in
            guard isPressed else { return }
            DispatchQueue.main.async {
                self?.disarmDrone()
            }
        }
        
        gamepad.buttonB.pressedChangedHandler = { [weak self] (input, value, isPressed) in
            guard isPressed else { return }
            DispatchQueue.main.async {
                self?.armDrone()
            }
        }
        
        gamepad.buttonX.pressedChangedHandler = { [weak self] (input, value, isPressed) in
            guard isPressed else { return }
            DispatchQueue.main.async {
                self?.recordOrStopSession()
            }
        }
        
        gamepad.buttonY.pressedChangedHandler = { [weak self] (input, value, isPressed) in
            guard let self, isPressed, telemetryData.isArmed else { return }
            requestTakeOff()
        }
        
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] (input, value, isPressed) in
            guard let self, isPressed else { return }
            requestIMUCalibration()
        }
        
        gamepad.buttonOptions?.pressedChangedHandler = { [weak self] (input, value, isPressed) in
            guard let self, isPressed else { return }
            requestBaroCalibration()
        }
    }
    
    private func applyDeadband(_ value: Float, deadband: Float) -> Float {
        if abs(value) <= deadband { return 0.0 }
        
        let sign: Float = value > 0 ? 1.0 : -1.0
        let scaledValue = (abs(value) - deadband) / (1.0 - deadband)
        
        return sign * scaledValue * maxManualThrottle
    }
    
    private func recordSession() {
        guard telemetryData.isArmed, isMAVLinkConnected else { return }
        isRecordingSession = true
        try? sessionRecorder.startRecording()
    }
    
    private func saveSession() {
        guard isRecordingSession else { return }
        isRecordingSession = false
        sessionRecorder.stopRecording(parameters: telemetryData.floatParams)
    }
    
    private func requestIMUCalibration() {
        guard isMAVLinkConnected, !telemetryData.isArmed else { return }
        
        mavlinkManager.actionCalibrateIMU()
    }
    
    private func requestBaroCalibration() {
        guard isMAVLinkConnected, !telemetryData.isArmed else { return }
        
        mavlinkManager.actionCalibrateBaro()
    }
    
    private func requestTakeOff() {
        guard isMAVLinkConnected, telemetryData.isArmed else { return }
        
        mavlinkManager.actionTakeoff()
    }
    
    private func unsubscribeManualControl() {
        manualControlCancellable?.cancel()
        manualControlCancellable = nil
    }
    
    private func resetStickValue() {
        pitchInput = 0.0
        rollInput = 0.0
        yawInput = 0.0
        throttleInput = 0.0
    }
    
    private func resetTelemetryData() {
        telemetryData.attitudeData.removeAll()
        telemetryData.motorData.removeAll()
        telemetryData.targetAttitudeData.removeAll()
        telemetryData.pidData.removeAll()
        telemetryData.controlLoopTimeData.removeAll()
    }
    
    private func clenaup() {
        isMAVLinkConnected = false
        resetStickValue()
        resetTelemetryData()
        unsubscribeManualControl()
    }
}
