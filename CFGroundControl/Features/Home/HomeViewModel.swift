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

let MavScheduler = ConcurrentDispatchQueueScheduler(qos: .userInitiated)
let MavSerialScheduler = SerialDispatchQueueScheduler(qos: .userInteractive)

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
    var attitudeData: [EulerAngleData] = []
    var statusText: [String] = []
    var floatParams: [Param.FloatParam] = []
    var motorData: [MotorData] = []
    var throttleData: [ThrottleData] = []
    var pidData: [EulerAngleData] = []
    var targetAttitudeData: [EulerAngleData] = []
    var controlLoopTimeData: [ControlLoopTimeData] = []
    var altitudeData: [AltitudeData] = []
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
    @Published var maxAutoThrottleValue: String = ""
    
    @Published var takeoffActivated: Bool = false
    @Published var landActivated: Bool = false
    
    var currentContrroller: GCController?
    private var connectingDrone: Bool = false
    private var drone: Drone?
    private var discoveredDroneIP: String?
    
    private let disposeBag = DisposeBag()
    private var controlTimer: Disposable?
    private var autoThrottleTimer: Disposable?
    
    private let sessionRecorder = StreamingSessionRecorder()
    
    private var maxAutoThrottle: Float = 0.30
    
    deinit {
        disconnectMAVLink()
    }
    
    init() {
        maxAutoThrottleValue = String(maxAutoThrottle)
    }
    
    func connectToMAVLink() {
        guard !connectingDrone else { return }
        
        connectionStatus = "Connecting to MAVSDK Server..."
        connectingDrone = true
        
        let drone = Drone()
        
        drone.connect(systemAddress: "udp://:\(port)")
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .do(
                onError: { [weak self] error in
                    self?.connectionStatus = "Connection Failed: \(error.localizedDescription)"
                    self?.errorMessage = error.localizedDescription
                    self?.connectingDrone = false
                },
                onCompleted: { [weak self] in
                    debugPrint("CONNECT COMPLETED")
                    self?.drone = drone
                    self?.subscribeMAVLinkConnection()
                    self?.connectingDrone = false
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
        getAllParameters()
        
        drone.action.arm()
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onCompleted: { [weak self] in
                    self?.resetStickValue()
                    self?.resetTelemetryData()
                    self?.resetTakeoffLandState()
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
            .subscribe({ [weak self] _ in
                self?.resetStickValue()
                self?.saveSession()
                self?.disposeManualControlMAVLink()
            })
            .disposed(by: disposeBag)
    }
    
    func getAllParameters() {
        guard let drone, !isLoadingParameters else { return }
        
        isLoadingParameters = true
        
        drone.param.getAllParams()
            .subscribe(on: MavSerialScheduler)
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
            .subscribe(on: MavSerialScheduler)
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
        resetStickValue()
        resetTakeoffLandState()
        resetTelemetryData()
        disposeManualControlMAVLink()
        drone?.disconnect()
        drone = nil
    }
    
    func stickDidConnect(_ controller: GCController) {
        isStickConnected = true
        currentContrroller = controller
        resetStickValue()
        resetTakeoffLandState()
        resetTelemetryData()
        setupInputControllers(controller)
    }
    
    func stickDidDisconnect() {
        isStickConnected = false
        currentContrroller = nil
        resetStickValue()
    }
    
    func updateMaxAutoThrottle(_ value: String) {
        if let value = Float(value), abs(value) >= 0.0 && abs(value) <= 1.0 {
            maxAutoThrottle = value
        } else {
            maxAutoThrottleValue = String(maxAutoThrottle)
        }
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
        telemetryData.controlLoopTimeData.removeAll()
    }
    
    private func resetTakeoffLandState() {
        takeoffActivated = false
        landActivated = false
    }
    
    private func setupInputControllers(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }
        
        let deadband: Float = 0.25
        
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] (input, xValue, yValue) in
            guard let self else { return }
            self.leftStickX = applyDeadband(xValue, deadband: deadband)
            self.leftStickY = applyDeadband(yValue, deadband: deadband)
        }
        
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] (input, xValue, yValue) in
            guard let self else { return }
            self.rightStickX = applyDeadband(xValue, deadband: deadband)
            if takeoffActivated && abs(yValue) > 0.0 {
                takeoffActivated = false
                landActivated = false
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
            if takeoffActivated {
                takeoffActivated = false
                landActivated = true
            } else {
                takeoffActivated = true
                landActivated = false
            }
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
                    resetTakeoffLandState()
                }
                
                if connectionState.isConnected {
                    startTelemetrySubscriptions()
                } else {
                    disconnectMAVLink()
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func setupManualControlMAVLink() {
        guard let drone else { return }
        
        autoThrottleTimer = Observable<Int>
            .interval(.milliseconds(250), scheduler: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] _ in
                guard let self, telemetryData.isArmed else { return }
                
                if takeoffActivated && landActivated {
                    takeoffActivated = false
                }
                
                if takeoffActivated && abs(rightStickY) <= maxAutoThrottle {
                    rightStickY += 0.01
                }
                
                if landActivated && abs(rightStickY) >= 0.0 {
                    rightStickY -= 0.01
                }
            })
        
        controlTimer = Observable<Int>
            .interval(.milliseconds(80), scheduler: MavSerialScheduler)
            .subscribe(onNext: { [weak self] _ in
                guard let self, telemetryData.isArmed else { return }
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
        autoThrottleTimer?.dispose()
        controlTimer = nil
        autoThrottleTimer = nil
    }
    
    private func startTelemetrySubscriptions() {
        guard let drone = drone else { return }
        
        drone.telemetry.armed
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] armed in
                guard let self else { return }
                if telemetryData.isArmed != armed {
                    resetStickValue()
                    resetTakeoffLandState()
                }
                telemetryData.isArmed = armed
            })
            .disposed(by: disposeBag)
        
        drone.telemetry.attitudeEuler
            .distinctUntilChanged()
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
        
        drone.telemetry.position
            .distinctUntilChanged()
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] pos in
                guard let self else { return }
                let data = AltitudeData(
                    timestamp: Date(),
                    absoluteAltitude: pos.absoluteAltitudeM,
                    relativeAltitude: pos.relativeAltitudeM
                )
                
                telemetryData.altitudeData.append(data)
                
                while telemetryData.altitudeData.count > 25 {
                    telemetryData.altitudeData.removeFirst()
                }
            })
            .disposed(by: disposeBag)
        
        drone.telemetry.statusText
            .distinctUntilChanged()
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] status in
                guard let self else { return }
                let statusText = status.text
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
                        
                        while telemetryData.motorData.count > 50 {
                            telemetryData.motorData.removeFirst()
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
                        
                        while telemetryData.pidData.count > 50 {
                            telemetryData.pidData.removeFirst()
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
                        
                        while telemetryData.throttleData.count > 25 {
                            telemetryData.throttleData.removeFirst()
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
                    
                    while telemetryData.targetAttitudeData.count > 10 {
                        telemetryData.targetAttitudeData.removeFirst()
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
                            currentFreq: targetValues[1],
                            minFreq: targetValues[2],
                            maxFreq: targetValues[3]
                        )
                    }
                    
                    while telemetryData.controlLoopTimeData.count > 25 {
                        telemetryData.controlLoopTimeData.removeFirst()
                    }
                    
                } else {
                    telemetryData.statusText.append(statusText)
                    while telemetryData.statusText.count > 100 {
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
    
    private func requestIMUCalibration() {
        guard let drone else { return }
        
        drone.calibration.calibrateGyro()
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { _ in
                debugPrint("Calibrate Gyro")
            })
            .disposed(by: disposeBag)
    }
    
    private func requestBaroCalibration() {
        guard let drone else { return }
        
        drone.calibration.calibrateLevelHorizon()
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { _ in
                debugPrint("Calibrate Level Horizon")
            })
            .disposed(by: disposeBag)
    }
}
