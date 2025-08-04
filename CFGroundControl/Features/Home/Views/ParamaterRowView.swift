//
//  ParamaterRowView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 04/08/25.
//

import SwiftUI

struct ParamaterRowView: View {
    let name: String
    let currentValue: Float
    let refreshTrigger: UUID
    @State private var value: String = ""
    @State private var isEditing: Bool = false
    @State private var hasError: Bool = false
    @State private var isUpdating: Bool = false
    
    let onValueChanged: ((String, Float?) -> Void)?
    
    init(name: String, value: Float, refreshTrigger: UUID = UUID(), onValueChanged: ((String, Float?) -> Void)? = nil) {
        self.name = name
        self.currentValue = value
        self.refreshTrigger = refreshTrigger
        self.onValueChanged = onValueChanged
    }
    
    private var isValidFloat: Bool {
        Float(value) != nil
    }
    
    private func handleParameterUpdate() {
        guard isValidFloat else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            isUpdating = true
        }
        
        if let floatValue = Float(value) {
            onValueChanged?(name, floatValue)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isUpdating = false
                }
            }
        }
    }
    
    private var textFieldBackgroundColor: Color {
        if hasError {
            return Color.red.opacity(0.1)
        } else if isEditing {
            return Color.cfColor(.lightYellow).opacity(0.3)
        } else {
            return Color.cfColor(.black100).opacity(0.3)
        }
    }
    
    private var textFieldBorderColor: Color {
        if hasError {
            return Color.red.opacity(0.5)
        } else if isEditing {
            return Color.cfColor(.darkYellow)
        } else {
            return Color.cfColor(.black200)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(name)
                    .foregroundStyle(Color.cfColor(.jetBlack))
                    .font(.cfFont(.semiBold, .bodySmall))
                
                Spacer()
                
                if isUpdating {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                } else if hasError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                } else if !isEditing && isValidFloat {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                        .opacity(0.7)
                }
            }
            
            TextField("Enter value", text: $value)
                .foregroundStyle(hasError ? Color.red : Color.cfColor(.jetBlack))
                .font(.cfFont(.regular, .bodySmall))
                .keyboardType(.numbersAndPunctuation)
                .textFieldStyle(PlainTextFieldStyle())
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(textFieldBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(textFieldBorderColor, lineWidth: isEditing ? 2 : 1)
                )
                .cornerRadius(8)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing = true
                    }
                }
                .onChange(of: value) { newValue in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        hasError = !newValue.isEmpty && !isValidFloat
                        isUpdating = false
                    }
                }
                .onSubmit {
                    handleParameterUpdate()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isEditing = false
                    }
                }
        }
        .padding(.vertical, 4)
        .onAppear {
            resetToCurrentValue()
        }
        .onChange(of: refreshTrigger) { _ in
            if !isEditing {
                resetToCurrentValue()
            }
        }
    }
    
    private func resetToCurrentValue() {
        withAnimation(.easeInOut(duration: 0.2)) {
            value = String(format: "%.3f", currentValue)
            hasError = false
            isUpdating = false
        }
    }
}
