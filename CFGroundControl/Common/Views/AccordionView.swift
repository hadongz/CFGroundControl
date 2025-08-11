//
//  AccordionView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 04/08/25.
//

import SwiftUI

struct AccordionView<Content: View>: View {
    
    let title: String
    let content: () -> Content
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Text(title)
                        .font(.cfFont(.semiBold, .bodyLarge))
                        .foregroundStyle(Color.cfColor(.black300))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "arrowtriangle.right.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.cfColor(.darkYellow))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .background(Color.cfColor(.white))
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                VStack(spacing: 0) {
                    content()
                        .frame(maxWidth: .infinity)
                }
                .transition(.asymmetric(
                    insertion: .opacity
                        .combined(with: .move(edge: .top))
                        .combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity
                ))
            }
        }
        .background(Color.cfColor(.white))
    }
}
