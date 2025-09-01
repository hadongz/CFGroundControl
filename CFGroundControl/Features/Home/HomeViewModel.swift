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
    var attitudeData: CircularBuffer<EulerAngleData> = CircularBuffer(capacity: 25)
    var statusText: CircularBuffer<String> = CircularBuffer(capacity: 50)
    var motorData: CircularBuffer<MotorData> = CircularBuffer(capacity: 25)
    var throttleData: CircularBuffer<ThrottleData> = CircularBuffer(capacity: 25)
    var pidData: CircularBuffer<EulerAngleData> = CircularBuffer(capacity: 25)
    var targetAttitudeData: CircularBuffer<EulerAngleData> = CircularBuffer(capacity: 25)
    var controlLoopTimeData: CircularBuffer<ControlLoopTimeData> = CircularBuffer(capacity: 25)
    var altitudeData: CircularBuffer<AltitudeData> = CircularBuffer(capacity: 25)
    
    var floatParams: [Param.FloatParam] = []
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
    private var connectingDrone: Bool = false
    private var drone: Drone?
    private var discoveredDroneIP: String?
    
    private var disposeBag = DisposeBag()
    private var connectionDisposeBag = DisposeBag()
    private var manualControlDisposeBag = DisposeBag()
    private var telemetryDisposeBag = DisposeBag()

    private let sessionRecorder = StreamingSessionRecorder()
    
    private var maxManualThrottle: Float = 0.75
    
    deinit {
        disconnectMAVLink()
    }
    
    init() {
        maxManualThrottleValue = String(maxManualThrottle)
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
                    debugPrint("Connected to Drone")
                    self?.drone = drone
                    self?.subscribeMAVLinkConnection()
                    self?.connectingDrone = false
                }
            )
            .andThen(Observable<Any>.never())
            .subscribe(onDisposed: { [weak self] in
                guard let self else { return }
                print("Connection disposed")
                disconnectMAVLink()
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
        
        drone.action.arm()
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe({ [weak self] _ in
                guard let self = self else { return }
                resetStickValue()
                resetTelemetryData()
                subscribeManualControl()
            })
            .disposed(by: disposeBag)
    }
    
    func disarmDrone() {
        guard let drone = drone, isMAVLinkConnected else { return }
        
        drone.action.kill()
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe({ [weak self] _ in
                guard let self else { return }
                saveSession()
                resetStickValue()
                unsubscribeManualControl()
            })
            .disposed(by: disposeBag)
    }
    
    func getAllParameters() {
        guard let drone, !isLoadingParameters else { return }
        
        isLoadingParameters = true
        
        drone.param.getAllParams()
            .subscribe(on: MavSerialScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe({ [weak self] result in
                guard let self, let params = try? result.get() else { return }
                telemetryData.floatParams = params.floatParams
                isLoadingParameters = false
                parametersRefreshTrigger = UUID()
            })
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
            .subscribe({ [weak self] _ in
                guard let self else { return }
                if let index = telemetryData.floatParams.firstIndex(where: { $0.name == name }) {
                    telemetryData.floatParams[index] = Param.FloatParam(name: name, value: value)
                }
            })
            .disposed(by: disposeBag)
    }
    
    func disconnectMAVLink() {
        isMAVLinkConnected = false
        connectionStatus = "Disconnected"
        resetStickValue()
        resetTelemetryData()
        drone?.disconnect()
        drone = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self else { return }
            disposeBag = DisposeBag()
            connectionDisposeBag = DisposeBag()
            manualControlDisposeBag = DisposeBag()
            telemetryDisposeBag = DisposeBag()
        }
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
        
        for param in floatParams {
            updateParameter(name: param.name, value: param.value)
        }
        
        getAllParameters()
    }
    
    func updateThrottleInputStyle() {
        stickyThrottle.toggle()
    }
    
    func subscribeManualControl() {
        guard let drone, isMAVLinkConnected else { return }
        
        Observable<Int>
            .interval(.milliseconds(100), scheduler: MavSerialScheduler)
            .filter { [weak self] _ in
                guard let self else { return false }
                return telemetryData.isArmed
            }
            .flatMap({ [weak self] _ -> Observable<Void> in
                guard let self else { return .empty() }
                return drone.manualControl
                    .setManualControlInput(
                        x: pitchInput,
                        y: rollInput,
                        z: yawInput,
                        r: throttleInput
                    )
                    .andThen(Observable.just(()))
                    .catch { _ in return Observable.just(()) }
            })
            .retry()
            .subscribe(onDisposed: {
                print("Manual Control subscription disposed")
            })
            .disposed(by: manualControlDisposeBag)
    }
    
    func subsribeTelemetry() {
        guard let drone, isMAVLinkConnected else { return }
        
        drone.telemetry.armed
            .distinctUntilChanged()
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] armed in
                guard let self else { return }
                if telemetryData.isArmed != armed {
                    resetStickValue()
                }
                telemetryData.isArmed = armed
            })
            .disposed(by: telemetryDisposeBag)
        
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
            })
            .disposed(by: telemetryDisposeBag)
        
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
                
                if (isRecordingSession) {
                    sessionRecorder.writeAltitude(absoulte: data.absoluteAltitude, relative: data.relativeAltitude)
                }
                
            })
            .disposed(by: telemetryDisposeBag)
        
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
            })
            .disposed(by: telemetryDisposeBag)
    }
    
    func unsubscribeTelemetry() {
        telemetryDisposeBag = DisposeBag()
    }
    
    func unsubscribeManualControl() {
        manualControlDisposeBag = DisposeBag()
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
        if abs(value) < deadband { return 0.0 }
        let sign = value > 0 ? Float(maxManualThrottle) : Float(-maxManualThrottle)
        let scaledValue = (abs(value) - deadband) / (1.0 - deadband)
        return sign * scaledValue
    }
    
    private func subscribeMAVLinkConnection() {
        guard let drone else { return }
        
        drone.core.connectionState
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .do(onNext: { [weak self] connectionState in
                guard let self else { return }
                let lastConnectionState = isMAVLinkConnected
                isMAVLinkConnected = connectionState.isConnected
                connectionStatus = connectionState.isConnected ? "Connected to drone" : "Connecting..."
                
                if lastConnectionState != isMAVLinkConnected {
                    resetTelemetryData()
                    resetStickValue()
                }
                
                if connectionState.isConnected {
                    subsribeTelemetry()
                } else {
                    disconnectMAVLink()
                }
            })
            .delay(.seconds(2), scheduler: MavScheduler)
            .subscribe(onNext: { [weak self] connectionState in
                guard let self else { return }
                if connectionState.isConnected {
                    DispatchQueue.main.async {
                        self.getAllParameters()
                    }
                }
            })
            .disposed(by: connectionDisposeBag)
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
            .subscribe()
            .disposed(by: disposeBag)
    }
    
    private func requestBaroCalibration() {
        guard let drone else { return }
        
        drone.calibration.calibrateLevelHorizon()
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe()
            .disposed(by: disposeBag)
    }
    
    private func requestTakeOff() {
        guard let drone else { return }
        
        drone.action.takeoff()
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe()
            .disposed(by: disposeBag)
    }
}
