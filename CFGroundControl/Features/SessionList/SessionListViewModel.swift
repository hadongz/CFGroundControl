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

final class SessionListViewModel: ObservableObject {
    
    @Published var sessionList: [SessionFolderData] = []
    
    func loadSessionList() {
        sessionList.removeAll()
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let sessionsURL = documentsDir.appendingPathComponent("DroneSessions")
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: sessionsURL.path) else { return }
        
        for filesName in files {
            let sessionURL = sessionsURL.appendingPathComponent(filesName)
            sessionList.append(SessionFolderData(url: sessionURL, name: filesName))
        }
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
    
}
