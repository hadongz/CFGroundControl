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
