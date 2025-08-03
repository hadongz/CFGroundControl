//
//  InputValueView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 03/08/25.
//

import SwiftUI

struct InputValueView: View {
    let label: String
    let value: Float
    let alignment: HorizontalAlignment
    
    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(.cfFont(.regular, .small))
                .foregroundColor(Color.cfColor(.black300))
            
            Text(String(format: "%.2f", value))
                .font(.cfFont(.regular, .small))
                .foregroundColor(Color.cfColor(.jetBlack))
        }
    }
}
