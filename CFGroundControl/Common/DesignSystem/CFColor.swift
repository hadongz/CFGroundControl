//
//  CFColor.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 28/12/24.
//

import Foundation

enum CFColor {
    case yellow
    case darkYellow
    case lightYellow
    
    case orange
    
    case jetBlack
    case black500
    case black400
    case black300
    case black200
    case black100
    
    case white
}

extension CFColor {
    
    var hexNumber: UInt32 {
        switch self {
        case .yellow:
            return 0xF7D786
        case .darkYellow:
            return 0xFCAA44
        case .lightYellow:
            return 0xFFF8E6
        case .orange:
            return 0xFF930F
        case .black500:
            return 0x212121
        case .black400:
            return 474747
        case .black300:
            return 0x717171
        case .black200:
            return 0x9E9E9E
        case .black100:
            return 0xCDCDCD
        case .jetBlack:
            return 0x0A0A0A
        case .white:
            return 0xFFFFFF
        }
    }
}
