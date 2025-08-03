//
//  SubtleShadow.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 31/12/24.
//

import SwiftUI


struct SubtleShadow: ViewModifier {
    var color: Color = .black
    var opacity: Double = 0.1
    var radius: CGFloat = 6
    var x: CGFloat = 0
    var y: CGFloat = 4
    
    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(opacity), radius: radius, x: x, y: y)
    }
}
