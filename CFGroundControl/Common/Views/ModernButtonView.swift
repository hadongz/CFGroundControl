//
//  ModernButtonView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 03/08/25.
//

import SwiftUI

struct ModernButtonView: View {
    let title: String
    let icon: String
    let color: Color
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if icon != "" {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.cfFont(.semiBold, .bodySmall))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(isEnabled ? color : Color.cfColor(.black200))
            .cornerRadius(8)
        }
        .disabled(!isEnabled)
    }
}
