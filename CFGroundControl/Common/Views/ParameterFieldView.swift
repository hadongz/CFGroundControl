//
//  ParameterFieldView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 11/08/25.
//

import SwiftUI

struct ParameterFieldView: View {
    
    let title: String
    @Binding var value: String
    var placeholder: String = "Enter value"
    var keyboardType: UIKeyboardType = .numbersAndPunctuation
    var validator: ((String) -> Bool)? = nil
    var onSubmit: ((String) -> Void)? = nil
    var onChange: ((String) -> Void)? = nil
    
    @State private var isEditing = false
    @State private var hasError = false
    @FocusState private var isFocused: Bool
    
    private var isValid: Bool {
        guard let validator = validator, !value.isEmpty else { return true }
        return validator(value)
    }
    
    private var textFieldBackgroundColor: Color {
        if hasError {
            return Color.red.opacity(0.05)
        } else if isEditing {
            return Color.blue.opacity(0.05)
        } else {
            return Color.gray.opacity(0.05)
        }
    }
    
    private var borderColor: Color {
        if hasError {
            return .red
        } else if isEditing {
            return .blue
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                TextField(placeholder, text: $value)
                    .foregroundStyle(Color.primary)
                    .font(.system(size: 14))
                    .keyboardType(keyboardType)
                    .textFieldStyle(PlainTextFieldStyle())
                    .focused($isFocused)
                    .onChange(of: value) { newValue in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            hasError = !isValid
                        }
                        onChange?(newValue)
                    }
                    .onSubmit {
                        handleSubmit()
                    }
                
                if isEditing && !value.isEmpty {
                    Button(action: {
                        value = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .imageScale(.small)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(textFieldBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .onChange(of: isFocused) { focused in
            withAnimation(.easeInOut(duration: 0.2)) {
                isEditing = focused
            }
        }
    }
    
    private func handleSubmit() {
        guard isValid else { return }
        onSubmit?(value)
        isFocused = false
    }
    
    struct Validator {
        static func floatValidator(min: Float? = nil, max: Float? = nil) -> (String) -> Bool {
            return { value in
                guard let floatValue = Float(value) else { return false }
                if let min = min, floatValue < min { return false }
                if let max = max, floatValue > max { return false }
                return true
            }
        }
        
        static func intValidator(min: Int? = nil, max: Int? = nil) -> (String) -> Bool {
            return { value in
                guard let intValue = Int(value) else { return false }
                if let min = min, intValue < min { return false }
                if let max = max, intValue > max { return false }
                return true
            }
        }
    }
}

