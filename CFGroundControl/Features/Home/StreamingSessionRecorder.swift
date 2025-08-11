//
//  StreamingSessionRecorder.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 05/08/25.
//

import Foundation
import Mavsdk

final class StreamingSessionRecorder {
    
    private var fileHandles: [String: FileHandle] = [:]
    private var sessionDirectory: URL?
    private var dateFormatter: ISO8601DateFormatter
    
    init() {
        dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
    
    deinit {
        stopRecording(parameters: [])
    }
    
    func startRecording() throws {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let sessionsDir = documentsDir.appendingPathComponent("DroneSessions")
        try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let sessionName = "session_\(formatter.string(from: Date()))"
        
        sessionDirectory = sessionsDir.appendingPathComponent(sessionName)
        try FileManager.default.createDirectory(at: sessionDirectory!, withIntermediateDirectories: true)
        
        createCSVFile(name: "attitude", headers: "timestamp,roll,pitch,yaw")
        createCSVFile(name: "motors", headers: "timestamp,motor1,motor2,motor3,motor4")
        createCSVFile(name: "throttle", headers: "timestamp,throttle")
        createCSVFile(name: "pid_output", headers: "timestamp,roll_pid,pitch_pid,yaw_pid")
        createCSVFile(name: "target_attitude", headers: "timestamp,target_roll,target_pitch,target_yaw")
        createCSVFile(name: "control_loop_time", headers: "timestamp,avg_freq,current_freq,min_freq,max_freq")
    }
    
    private func createCSVFile(name: String, headers: String) {
        guard let sessionDir = sessionDirectory else { return }
        
        let fileURL = sessionDir.appendingPathComponent("\(name).csv")
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            fileHandles[name] = handle
            let headerData = "\(headers)\n".data(using: .utf8)!
            handle.write(headerData)
        }
    }
    
    func writeAttitude(roll: Float, pitch: Float, yaw: Float) {
        guard let handle = fileHandles["attitude"] else { return }
        
        let timestamp = dateFormatter.string(from: Date())
        let line = "\(timestamp),\(roll),\(pitch),\(yaw)\n"
        
        if let data = line.data(using: .utf8) {
            handle.write(data)
        }
    }
    
    func writeMotors(m1: Int, m2: Int, m3: Int, m4: Int) {
        guard let handle = fileHandles["motors"] else { return }
        
        let timestamp = dateFormatter.string(from: Date())
        let line = "\(timestamp),\(m1),\(m2),\(m3),\(m4)\n"
        
        if let data = line.data(using: .utf8) {
            handle.write(data)
        }
    }
    
    func writeThrottle(value: Float) {
        guard let handle = fileHandles["throttle"] else { return }
        
        let timestamp = dateFormatter.string(from: Date())
        let line = "\(timestamp),\(value)\n"
        
        if let data = line.data(using: .utf8) {
            handle.write(data)
        }
    }
    
    func writePID(roll: Float, pitch: Float, yaw: Float) {
        guard let handle = fileHandles["pid_output"] else { return }
        
        let timestamp = dateFormatter.string(from: Date())
        let line = "\(timestamp),\(roll),\(pitch),\(yaw)\n"
        
        if let data = line.data(using: .utf8) {
            handle.write(data)
        }
    }
    
    func writeTargetAttitude(roll: Float, pitch: Float, yaw: Float) {
        guard let handle = fileHandles["target_attitude"] else { return }
        
        let timestamp = dateFormatter.string(from: Date())
        let line = "\(timestamp),\(roll),\(pitch),\(yaw)\n"
        
        if let data = line.data(using: .utf8) {
            handle.write(data)
        }
    }
    
    func writeControlLoopTime(avgFreq: Int, currentFreq: Int, minFreq: Int, maxFreq: Int) {
        guard let handle = fileHandles["control_loop_time"] else { return }
        let timestamp = dateFormatter.string(from: Date())
        let line = "\(timestamp),\(avgFreq),\(currentFreq),\(minFreq),\(maxFreq)\n"
        
        if let data = line.data(using: .utf8) {
            handle.write(data)
        }
    }
    
    func stopRecording(parameters: [Param.FloatParam]) {
        for (_, handle) in fileHandles {
            handle.closeFile()
        }
        
        fileHandles.removeAll()
        saveAllParameters(parameters)
        savePIDParameters(parameters)
        saveMetadata(parameters: parameters)
    }
    
    private func saveAllParameters(_ parameters: [Param.FloatParam]) {
        guard let sessionDir = sessionDirectory else { return }
        
        let fileURL = sessionDir.appendingPathComponent("all_parameters.csv")
        var csvText = "parameter_name,value\n"
        
        let sortedParams = parameters.sorted { $0.name < $1.name }
        
        for param in sortedParams {
            let escapedName = param.name.contains(",") ? "\"\(param.name)\"" : param.name
            csvText += "\(escapedName),\(param.value)\n"
        }
        
        try? csvText.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    private func savePIDParameters(_ parameters: [Param.FloatParam]) {
        guard let sessionDir = sessionDirectory else { return }
        
        let fileURL = sessionDir.appendingPathComponent("pid_parameters.csv")
        
        var paramDict: [String: Float] = [:]
        for param in parameters {
            paramDict[param.name] = param.value
        }
        
        let pidParams = [
            ("ROLL_P", "roll_kp"),
            ("ROLL_I", "roll_ki"),
            ("ROLL_D", "roll_kd"),
            ("PITCH_P", "pitch_kp"),
            ("PITCH_I", "pitch_ki"),
            ("PITCH_D", "pitch_kd"),
            ("YAW_P", "yaw_kp"),
            ("YAW_I", "yaw_ki"),
            ("YAW_D", "yaw_kd")
        ]
        
        let headers = pidParams.map { $0.1 }.joined(separator: ",")
        var csvText = "\(headers)\n"
        
        let values = pidParams.map { paramName, _ in
            if let value = paramDict[paramName] {
                return String(value)
            } else {
                return "N/A"
            }
        }
        csvText += values.joined(separator: ",") + "\n"
        
        try? csvText.write(to: fileURL, atomically: true, encoding: .utf8)
    }
    
    private func saveMetadata(parameters: [Param.FloatParam]) {
        guard let sessionDir = sessionDirectory else { return }
        
        let fileURL = sessionDir.appendingPathComponent("session_info.json")
        
        let pidParameters = parameters.filter { param in
            param.name.contains("ROLL_") ||
            param.name.contains("PITCH_") ||
            param.name.contains("YAW_")
        }
        
        let metadata: [String: Any] = [
            "session_end": dateFormatter.string(from: Date()),
            "total_parameters": parameters.count,
            "pid_parameters_found": pidParameters.count,
            "pid_values": pidParameters.reduce(into: [String: Float]()) { dict, param in
                dict[param.name] = param.value
            }
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted) {
            try? jsonData.write(to: fileURL)
        }
    }
}
