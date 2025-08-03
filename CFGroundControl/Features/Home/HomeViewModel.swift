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

    var currentContrroller: GCController?
    private var drone: Drone?
    private let disposeBag = DisposeBag()
    private var udpListener: NWListener?
    private var discoveredDroneIP: String?
    
    private let maxStatusTextCount: Int = 100
    
    struct TelemetryData {
        var isArmed = false
        var rollDeg: Float = 0.0
        var pitchDeg: Float = 0.0
        var yawDeg: Float = 0.0
        var statusText: [String] = []
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
        
        drone.action.kill()
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(
                onCompleted: { [weak self] in
                    self?.resetStickValue()
                },
                onError: { error in
                    print("Failed to disarm drone: \(error)")
                }
            )
            .disposed(by: disposeBag)
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
                self?.isMAVLinkConnected = connectionState.isConnected
                self?.connectionStatus = connectionState.isConnected ? "Connected to drone" : "Connecting..."
                if connectionState.isConnected {
                    self?.startTelemetrySubscriptions()
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
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] attitudeEuler in
                self?.telemetryData.rollDeg = attitudeEuler.rollDeg
                self?.telemetryData.pitchDeg = attitudeEuler.pitchDeg
                self?.telemetryData.yawDeg = attitudeEuler.yawDeg
            })
            .disposed(by: disposeBag)
        
        drone.telemetry.statusText
            .subscribe(on: MavScheduler)
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] statusText in
                guard let self else { return }
                telemetryData.statusText.append(statusText.text)
                while telemetryData.statusText.count > self.maxStatusTextCount {
                    telemetryData.statusText.removeFirst()
                }
            })
            .disposed(by: disposeBag)
    }
    
    func disconnectMAVLink() {
        isMAVLinkConnected = false
        connectionStatus = "Disconnected"
        drone?.disconnect()
        drone = nil
    }
    
    deinit {
        disconnectMAVLink()
        udpListener?.cancel()
    }
}
