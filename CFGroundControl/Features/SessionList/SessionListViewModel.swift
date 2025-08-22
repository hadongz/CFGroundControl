//
//  SessionListViewModel.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 05/08/25.
//

import Foundation
import Combine
import ZIPFoundation

struct SessionFolderData: Identifiable {
    let id: UUID = UUID()
    let url: URL
    let name: String
}

struct SessionDateSection: Identifiable {
    let date: Date
    let sessions: [SessionFolderData]
    
    var displayDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(date)
    }
    
    var sectionTitle: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else {
            return displayDate
        }
    }
    
    var id: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

final class SessionListViewModel: ObservableObject {
    
    @Published var sessionList: [SessionFolderData] = []
    @Published var sessionSections: [SessionDateSection] = []
    
    func loadSessionList() {
        sessionList.removeAll()
        sessionSections.removeAll()
        
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let sessionsURL = documentsDir.appendingPathComponent("DroneSessions")
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: sessionsURL.path) else { return }
        
        for filesName in files.sortedBySessionTimestamp() {
            let sessionURL = sessionsURL.appendingPathComponent(filesName)
            sessionList.append(SessionFolderData(url: sessionURL, name: filesName))
        }
        
        groupSessionsByDate()
    }
    
    func deleteSession(_ session: SessionFolderData) {
        do {
            try FileManager.default.removeItem(at: session.url)
            sessionList.removeAll { $0.id == session.id }
        } catch {
            print("Error deleting session: \(error)")
        }
    }
    
    func zipSession(_ session: SessionFolderData) -> URL? {
        let sourceURL = session.url
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(session.name).zip")
        try? FileManager.default.removeItem(at: destinationURL)
        
        do {
            try FileManager.default.zipItem(at: sourceURL, to: destinationURL)
            debugPrint("Successfully created zip at: \(destinationURL.path)")
            return destinationURL
        } catch {
            debugPrint("Failed to create zip: \(error)")
            return nil
        }
    }
    
    func shareAllSession() -> URL? {
        guard
            !sessionList.isEmpty,
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        else {
            debugPrint("No sessions available")
            return nil
        }
        
        let dirPath = documentsDir.appendingPathComponent("DroneSessions")
        
        guard FileManager.default.fileExists(atPath: dirPath.path) else {
            debugPrint("DroneSessions directory doesn't exist")
            return nil
        }
        
        let timestamp = Int(Date().timeIntervalSince1970)
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("DroneSessions_\(timestamp).zip")
        try? FileManager.default.removeItem(at: destinationURL)
        
        do {
            try FileManager.default.zipItem(at: dirPath, to: destinationURL)
            debugPrint("Successfully created zip at: \(destinationURL.path)")
            return destinationURL
        } catch {
            debugPrint("Failed to create zip: \(error)")
            return nil
        }
    }
    
    private func groupSessionsByDate() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        
        let calendar = Calendar.current
        
        // Group sessions by date
        let groupedSessions = Dictionary(grouping: sessionList) { session -> Date in
            let timestamp = String(session.name.dropFirst(8))
            if let date = dateFormatter.date(from: timestamp) {
                return calendar.startOfDay(for: date)
            }
            return Date.distantPast
        }
        
        // Convert to sections and sort by date (most recent first)
        sessionSections = groupedSessions.compactMap { (date, sessions) -> SessionDateSection? in
            guard date != Date.distantPast else { return nil }
            return SessionDateSection(date: date, sessions: sessions)
        }.sorted { $0.date > $1.date }
    }
}
