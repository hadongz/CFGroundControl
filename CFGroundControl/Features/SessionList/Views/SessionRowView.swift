//
//  SessionRowView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 22/08/25.
//

import SwiftUI

struct SessionRowView: View {
    let session: SessionFolderData
    let onShare: (SessionFolderData) -> Void
    let onDelete: (SessionFolderData) -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.cfFont(.regular, .bodySmall))
                    .foregroundStyle(Color.cfColor(.black300))
                
                Text(sessionTime)
                    .font(.cfFont(.regular, .bodySmall))
                    .foregroundStyle(Color.cfColor(.black300))
            }
            
            Spacer()
            
            Button {
                onShare(session)
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.blue)
            }
            
            Button {
                onDelete(session)
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
        .background(Color.cfColor(.white))
        .cornerRadius(8)
        .subtleShadow()
    }
    
    private var sessionTime: String {
        let timestamp = String(session.name.dropFirst(8))
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        
        if let date = dateFormatter.date(from: timestamp) {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            return timeFormatter.string(from: date)
        }
        
        return timestamp
    }
}
