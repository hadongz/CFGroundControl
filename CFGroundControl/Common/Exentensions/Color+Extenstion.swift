//
//  Color+Extenstion.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 28/12/24.
//

import SwiftUI

extension Color {
    
    static func cfColor(_ color: CFColor, opacity: Double = 1.0) -> Color {
        Color(hex: color.hexNumber, opacity: opacity)
    }
    
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex & 0xFF0000) >> 16) / 255.0
        let green = Double((hex & 0x00FF00) >> 8) / 255.0
        let blue = Double(hex & 0x0000FF) / 255.0
        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }
}
