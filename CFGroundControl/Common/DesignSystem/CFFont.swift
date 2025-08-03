//
//  CFFont.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 29/12/24.
//

import SwiftUI

enum CFFontType: String {
    case light = "Poppins-Light"
    case regular = "Poppins-Regular"
    case semiBold = "Poppins-Semibold"
    case bold = "Poppins-Bold"
}

enum CFFontSize {
    case header1
    case header3
    case header5
    case title
    case bodyLarge
    case bodySmall
    case small
    
    var value: CGFloat {
        switch self {
        case .header1:
            return 48
        case .header3:
            return 32
        case .header5:
            return 24
        case .title:
            return 18
        case .bodyLarge:
            return 16
        case .bodySmall:
            return 14
        case .small:
            return 12
        }
    }
}
