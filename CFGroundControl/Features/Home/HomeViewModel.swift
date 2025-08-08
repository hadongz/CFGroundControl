//
//  HomeViewModel.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 31/07/25.
//

import Foundation
import Combine
import GameController
import Mavsdk
import MavsdkServer
import RxSwift
import Network

let MavScheduler = ConcurrentDispatchQueueScheduler(qos: .default)
let MavParamScheduler = SerialDispatchQueueScheduler(qos: .utility)

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

struct SessionData {
    var attitudeData: [EulerAngleData] = []
    var floatParams: [Param.FloatParam] = []
    var motorData: [MotorData] = []
    var throttleData: [ThrottleData] = []
    var pidData: [EulerAngleData] = []
    var targetAttitudeData: [EulerAngleData] = []
}

struct TelemetryData {
    var isArmed = false
    var attitudeData: [EulerAngleData] = []
    var statusText: [String] = []
    var floatParams: [Param.FloatParam] = []
    var motorData: [MotorData] = []
    var throttleData: [ThrottleData] = []
    var pidData: [EulerAngleData] = []
    var targetAttitudeData: [EulerAngleData] = []
}

final class HomeViewModel: ObservableObject {
    
    @Published var isStickConnected: Bool = false
    
    @Published var leftStickX: Float = 0.0    // Roll
    @Published var leftStickY: Float = 0.0    // Pitch
    @Published var rightStickX: Float = 0.0   // Yaw
    @Published var rightStickY: Float = 0.0   // Throttle
    
    @Published var isMAVLinkConnected = false
    @Published var connectionStatus = "Disconnected"
    @Published var errorMessage: String?
    @Published var port = "14550"
    
    @Published var telemetryData = TelemetryData()
    @Published var isLoadingParameters = false
    @Published var parametersRefreshTrigger = UUID()
    
    @Published var isRecordingSession: Bool = false
    
    var currentContrroller: GCController?
    private var drone: Drone?
    private var udpListener: NWListener?
    private var discoveredDroneIP: String?
    
    private let disposeBag = DisposeBag()
    private var controlTimer: Disposable?
    
    private let sessionRecorder = StreamingSessionRecorder()
    
    private let maxStatusTextCount: Int = 100
    
    private var autoThrottleActive: Bool = false
    private let maxAutoThrottle: Float = 0.35
    
    deinit {
        disconnectMAVLink()
        udpListener?.cancel()
    }
    
    func connectToMAVLink() {
        connectionStatus = "Connecting to MAVSDK Server..."
        
        let drone = Drone()
        
        drone.connect(systemAddress: "udp://:\(port)")
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .do(
                onError: { [weak self] error in
                    self?.connectionStatus = "Connection Failed: \(error.localizedDescription)"
                    self?.errorMessage = error.localizedDescription
                },
                onCompleted: { [weak self] in
                    self?.drone = drone
                    self?.subscribeMAVLinkConnection()
                }
            )
            .andThen(Observable<Any>.never())
            .subscribe(onDisposed: {
                print("Connection disposed")
                drone.disconnect()
            })
            .disposed(by: disposeBag)
    }
    
    func recordOrStopSession() {
        isRecordingSession ? saveSession() : recordSession()
    }
    
    func armOrDisarmDrone() {
        telemetryData.isArmed ? disarmDrone() : armDrone()
    }
    
    func armDrone() {
        guard let drone = drone, isMAVLinkConnected else { return }
        
        setupManualControlMAVLink()
        
        drone.action.arm()
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onCompleted: { [weak self] in
                    self?.resetStickValue()
                },
                onError: { error in
                    print("Failed to arm drone: \(error)")
                }
            )
            .disposed(by: disposeBag)
    }
    
    func disarmDrone() {
        guard let drone = drone, isMAVLinkConnected else { return }
        
        resetStickValue()
        
        drone.action.kill()
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onCompleted: { [weak self] in
                    self?.resetStickValue()
                    self?.resetTelemetryData()
                    self?.disposeManualControlMAVLink()
                },
                onError: { [weak self] error in
                    print("Failed to disarm drone: \(error)")
                    self?.resetStickValue()
                    self?.resetTelemetryData()
                    self?.disposeManualControlMAVLink()
                }
            )
            .disposed(by: disposeBag)
    }
    
    func getAllParameters() {
        guard let drone, !isLoadingParameters else { return }
        
        isLoadingParameters = true
        
        drone.param.getAllParams()
            .subscribe(on: MavParamScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onSuccess: { [weak self] params in
                    print("Success get parameters: \(params.floatParams.count)")
                    guard let self else { return }
                    self.telemetryData.floatParams = params.floatParams
                    self.isLoadingParameters = false
                    self.parametersRefreshTrigger = UUID()
                },
                onFailure: { [weak self] error in
                    print("Failed to get parameters: \(error)")
                    self?.isLoadingParameters = false
                }
            )
            .disposed(by: disposeBag)
    }
    
    func refreshParameters() {
        getAllParameters()
    }
    
    func updateParameter(name: String, value: Float?) {
        guard let drone = drone, let value = value else { return }
        
        drone.param.setParamFloat(name: name, value: value)
            .subscribe(on: MavParamScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onCompleted: { [weak self] in
                    guard let self else { return }
                    print("Parameter \(name) updated to \(value)")
                    if let index = telemetryData.floatParams.firstIndex(where: { $0.name == name }) {
                        telemetryData.floatParams[index] = Param.FloatParam(name: name, value: value)
                    }
                },
                onError: { error in
                    print("Failed to update parameter \(name): \(error)")
                }
            )
            .disposed(by: disposeBag)
    }
    
    func disconnectMAVLink() {
        isMAVLinkConnected = false
        connectionStatus = "Disconnected"
        drone?.disconnect()
        drone = nil
    }
    
    func stickDidConnect(_ controller: GCController) {
        isStickConnected = true
        currentContrroller = controller
        setupInputControllers(controller)
    }
    
    func stickDidDisconnect() {
        isStickConnected = false
        currentContrroller = nil
        resetStickValue()
    }
    
    private func resetStickValue() {
        leftStickY = 0.0
        leftStickX = 0.0
        rightStickX = 0.0
        rightStickY = 0.0
    }
    
    private func resetTelemetryData() {
        telemetryData.attitudeData.removeAll()
        telemetryData.motorData.removeAll()
        telemetryData.targetAttitudeData.removeAll()
        telemetryData.pidData.removeAll()
    }
    
    private func setupInputControllers(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        
        let deadband: Float = 0.35
        
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] (input, xValue, yValue) in
            guard let self else { return }
            self.leftStickX = applyDeadband(xValue, deadband: deadband)
            self.leftStickY = applyDeadband(yValue, deadband: deadband)
        }
        
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] (input, xValue, yValue) in
            guard let self else { return }
            self.rightStickX = applyDeadband(xValue, deadband: deadband)
            if autoThrottleActive && abs(yValue) > 0.0 {
                autoThrottleActive.toggle()
                self.rightStickY = applyDeadband(yValue, deadband: deadband)
            } else {
                self.rightStickY = applyDeadband(yValue, deadband: deadband)
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
            autoThrottleActive.toggle()
        }
    }
    
    private func applyDeadband(_ value: Float, deadband: Float) -> Float {
        if abs(value) < deadband { return 0.0 }
        let sign = value > 0 ? Float(1.0) : Float(-1.0)
        let scaledValue = (abs(value) - deadband) / (1.0 - deadband)
        return sign * scaledValue
    }
    
    private func subscribeMAVLinkConnection() {
        guard let drone else { return }
        drone.core.connectionState
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] connectionState in
                guard let self else { return }
                let lastConnectionState = isMAVLinkConnected
                isMAVLinkConnected = connectionState.isConnected
                connectionStatus = connectionState.isConnected ? "Connected to drone" : "Connecting..."
                
                if lastConnectionState != isMAVLinkConnected {
                    resetTelemetryData()
                    resetStickValue()
                }
                
                if connectionState.isConnected {
                    startTelemetrySubscriptions()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.getAllParameters()
                    }
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func setupManualControlMAVLink() {
        guard let drone else { return }
        
        Observable<Int>
            .interval(.milliseconds(250), scheduler: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard let self else { return }
                if autoThrottleActive && rightStickY <= maxAutoThrottle {
                    rightStickY += 0.01
                }
            })
            .disposed(by: disposeBag)
        
        controlTimer = Observable<Int>
            .interval(.milliseconds(50), scheduler: MavParamScheduler)
            .subscribe(onNext: { [weak self] _ in
                guard let self else { return }
                _ = drone.manualControl
                    .setManualControlInput(
                        x: leftStickY,
                        y: leftStickX,
                        z: rightStickX,
                        r: rightStickY
                    )
                    .subscribe()
                    .dispose()
            })
    }
    
    private func disposeManualControlMAVLink() {
        controlTimer?.dispose()
        controlTimer = nil
    }
    
    private func startTelemetrySubscriptions() {
        guard let drone = drone else { return }
        
        drone.telemetry.armed
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] armed in
                self?.telemetryData.isArmed = armed
            })
            .disposed(by: disposeBag)
        
        drone.telemetry.attitudeEuler
            .throttle(.milliseconds(100), scheduler: MainScheduler.instance)
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] attitudeEuler in
                guard let self else { return }
                
                let timestamp = Date()
                let data = EulerAngleData(
                    timestamp: timestamp,
                    roll: attitudeEuler.rollDeg,
                    pitch: attitudeEuler.pitchDeg,
                    yaw: attitudeEuler.yawDeg
                )
                
                telemetryData.attitudeData.append(data)
                
                if isRecordingSession {
                    sessionRecorder.writeAttitude(
                        roll: attitudeEuler.rollDeg,
                        pitch: attitudeEuler.pitchDeg,
                        yaw: attitudeEuler.yawDeg
                    )
                }
                
                while telemetryData.attitudeData.count > 25 {
                    telemetryData.attitudeData.removeFirst()
                }
            })
            .disposed(by: disposeBag)
        
        drone.telemetry.statusText
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                guard let self else { return }
                let statusText = status.text
                let timestamp = Date()
                
                if statusText.hasPrefix("MOTOR:") {
                    let motorValues = statusText
                        .replacingOccurrences(of: "MOTOR:", with: "")
                        .split(separator: ",")
                        .compactMap { Int($0) }
                    
                    guard motorValues.count >= 4 else { return }
                    
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
                    
                    while telemetryData.motorData.count > 50 {
                        telemetryData.motorData.removeFirst()
                    }
                    
                } else if statusText.hasPrefix("PID:") {
                    let pidValues = statusText
                        .replacingOccurrences(of: "PID:", with: "")
                        .split(separator: ",")
                        .compactMap { Float($0) }
                    
                    guard pidValues.count >= 3 else { return }
                    
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
                    
                    while telemetryData.pidData.count > 50 {
                        telemetryData.pidData.removeFirst()
                    }
                    
                } else if statusText.hasPrefix("THROTTLE:") {
                    let throttleString = statusText.replacingOccurrences(of: "THROTTLE:", with: "")
                    
                    guard let throttleValue = Float(throttleString) else { return }
                    
                    let data = ThrottleData(
                        timestamp: timestamp,
                        value: throttleValue
                    )
                    
                    telemetryData.throttleData.append(data)
                    
                    if isRecordingSession {
                        sessionRecorder.writeThrottle(value: throttleValue)
                    }
                    
                    while telemetryData.throttleData.count > 25 {
                        telemetryData.throttleData.removeFirst()
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
                    
                    while telemetryData.targetAttitudeData.count > 10 {
                        telemetryData.targetAttitudeData.removeFirst()
                    }
                    
                } else {
                    telemetryData.statusText.append(statusText)
                    while telemetryData.statusText.count > maxStatusTextCount {
                        telemetryData.statusText.removeFirst()
                    }
                }
            })
            .disposed(by: disposeBag)
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
}
