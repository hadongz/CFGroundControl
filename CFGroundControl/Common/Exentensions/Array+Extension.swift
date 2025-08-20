//
//  Array+Extension.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 31/12/24.
//

import Foundation

extension Collection {
    
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Array where Element == String {
    
    func sortedBySessionTimestamp() -> [String] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        
        return self.sorted { session1, session2 in
            let timestamp1 = String(session1.dropFirst(8))
            let timestamp2 = String(session2.dropFirst(8))
            
            if let date1 = dateFormatter.date(from: timestamp1),
               let date2 = dateFormatter.date(from: timestamp2) {
                return date1 > date2
            }
            
            return timestamp1 < timestamp2
        }
    }
    
    mutating func sortBySessionTimestamp() {
        self = sortedBySessionTimestamp()
    }
}
