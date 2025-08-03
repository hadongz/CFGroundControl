//
//  TelemteryCardView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 03/08/25.
//

import SwiftUI

struct TelemetryCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        ZStack(alignment: .center) {
            VStack {
                HStack {
                    Image(systemName: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(color)
                        .frame(width: 16, height: 16)
                    
                    Spacer()
                }
                
                Spacer()
            }
            
            VStack(alignment: .center, spacing: 4) {
                Text(value)
                    .font(.cfFont(.semiBold, .bodyLarge))
                    .fontWeight(.bold)
                    .foregroundColor(.cfColor(.jetBlack))
                
                Text(title)
                    .font(.cfFont(.regular, .small))
                    .foregroundColor(.cfColor(.black300))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    Color.cfColor(.white),
                    Color.cfColor(.lightYellow),
                    Color.cfColor(.yellow)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(12)
        .subtleShadow(radius: 6)
    }
}
