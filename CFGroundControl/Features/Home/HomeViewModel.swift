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
    
    var currentContrroller: GCController?
    private var drone: Drone?
    private let disposeBag = DisposeBag()
    private var udpListener: NWListener?
    private var discoveredDroneIP: String?
    
    private let maxStatusTextCount: Int = 100
    
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
    
    func armDrone() {
        guard let drone = drone, isMAVLinkConnected else { return }
        
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
        sendManualControlCommand()
        
        drone.action.kill()
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onCompleted: { [weak self] in
                    self?.resetStickValue()
                    self?.resetTelemetryData() 
                },
                onError: { [weak self] error in
                    print("Failed to disarm drone: \(error)")
                    self?.resetStickValue()
                    self?.resetTelemetryData()
                }
            )
            .disposed(by: disposeBag)
    }
    
    func getAllParameters() {
        guard let drone else { return }
        
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
                    print("Parameter \(name) updated to \(value)")
                    if let index = self?.telemetryData.floatParams.firstIndex(where: { $0.name == name }) {
                        self?.telemetryData.floatParams[index] = Param.FloatParam(name: name, value: value)
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
            DispatchQueue.main.async {
                self.leftStickX = abs(xValue) > deadband ? xValue - deadband : 0.0
                self.leftStickY = abs(yValue) > deadband ? yValue - deadband : 0.0
                self.sendManualControlCommand()
            }
        }
        
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] (input, xValue, yValue) in
            guard let self else { return }
            DispatchQueue.main.async {
                self.rightStickX = abs(xValue) > deadband ? xValue - deadband : 0.0
                self.rightStickY = abs(yValue) > deadband ? yValue - deadband : 0.0
                self.sendManualControlCommand()
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
                    getAllParameters()
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func sendManualControlCommand() {
        guard let drone else { return }
        drone.manualControl
            .setManualControlInput(
                x: leftStickY,
                y: leftStickX,
                z: rightStickY,
                r: rightStickX
            )
            .subscribe()
            .disposed(by: disposeBag)
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
                telemetryData.attitudeData.append(
                    EulerAngleData(
                        timestamp: timestamp,
                        roll: attitudeEuler.rollDeg,
                        pitch: attitudeEuler.pitchDeg,
                        yaw: attitudeEuler.yawDeg)
                )
                
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
                    
                    while telemetryData.motorData.count > 25 {
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
                    
                    while telemetryData.pidData.count > 25 {
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
    
    
    deinit {
        disconnectMAVLink()
        udpListener?.cancel()
    }
}
