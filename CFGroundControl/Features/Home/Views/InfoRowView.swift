//
//  InfoRowView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 03/08/25.
//

import SwiftUI

struct InfoRowView: View {
    let label: String
    let value: String
    let isError: Bool
    
    init(label: String, value: String, isError: Bool = false) {
        self.label = label
        self.value = value
        self.isError = isError
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.cfFont(.regular, .bodySmall))
                .foregroundColor(Color.cfColor(.black300))
            
            Spacer()
            
            Text(value)
                .font(.cfFont(.semiBold, .bodySmall))
                .fontWeight(.medium)
                .foregroundColor(isError ? .red : Color.cfColor(.jetBlack))
        }
    }
}
