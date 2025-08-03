//
//  NavigationBarView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 15/01/25.
//

import SwiftUI

struct NavigationBarView<Content: View>: View {
    
    @EnvironmentObject var navigationManager: NavigationManager
    
    private let title: String
    private let content: () -> Content
    private let didTapBack: (() -> Void)?
    
    init(
        title: String,
        didTapBack: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.didTapBack = didTapBack
        self.content = content
    }
    
    var body: some View {
        VStack(spacing: .zero) {
            navigationBar
                .zIndex(99)
            
            content()
        }
    }
    
    var navigationBar: some View {
        VStack(alignment: .center) {
            HStack(alignment: .center) {
                Button {
                    if let didTapBack {
                        didTapBack()
                    } else {
                        navigationManager.pop()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 25, height: 25)
                        .foregroundStyle(Color.cfColor(.orange))
                }
                
                Spacer()
                
                Text(title)
                    .font(.cfFont(.semiBold, .title))
                    .foregroundStyle(Color.cfColor(.orange))
                    .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer()
                
                Rectangle()
                    .fill(.clear)
                    .frame(width: 25, height: 25)
            }
        }
        .padding(20)
        .background(Color.cfColor(.white).shadow(color: Color.cfColor(.black100).opacity(0.3), radius: 2, x: 0, y: 4))
        
    }
}

