//
//  View+Extension.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 31/12/24.
//

import SwiftUI

extension View {
    
    func subtleShadow(
        color: Color = .black,
        opacity: Double = 0.1,
        radius: CGFloat = 16,
        x: CGFloat = 0,
        y: CGFloat = 0
    ) -> some View {
        self.modifier(SubtleShadow(color: color, opacity: opacity, radius: radius, x: x, y: y))
    }
    
    func onViewDidLoad(perform action: (() -> Void)? = nil) -> some View {
        modifier(ViewDidLoadModifier(perform: action))
    }
    
    @inlinable public func reverseMask<Mask: View>( alignment: Alignment = .center, @ViewBuilder _ mask: () -> Mask) -> some View {
        self.mask {
            Rectangle().overlay(alignment: alignment) { mask() .blendMode(.destinationOut) }
        }
    }
}
