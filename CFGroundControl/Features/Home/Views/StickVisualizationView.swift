//
//  StickVisualizationView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 03/08/25.
//

import SwiftUI

struct StickVisualizationView: View {
    let title: String
    let x: Float
    let y: Float
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.cfFont(.regular, .small))
                .foregroundColor(Color.cfColor(.black300))
            
            ZStack {
                Circle()
                    .fill(Color.cfColor(.black100).opacity(0.3))
                    .frame(width: 80, height: 80)
                
                Rectangle()
                    .fill(Color.cfColor(.black200))
                    .frame(width: 1, height: 80)
                
                Rectangle()
                    .fill(Color.cfColor(.black200))
                    .frame(width: 80, height: 1)
                
                Circle()
                    .fill(Color.cfColor(.orange))
                    .frame(width: 12, height: 12)
                    .offset(
                        x: CGFloat(x) * 30,
                        y: CGFloat(-y) * 30
                    )
                    .animation(.easeOut(duration: 0.1), value: x)
                    .animation(.easeOut(duration: 0.1), value: y)
            }
        }
    }
}
