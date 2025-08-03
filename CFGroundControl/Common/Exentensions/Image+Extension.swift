//
//  Image+Extension.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 29/12/24.
//

import SwiftUI

extension Image {
    
    static func illustration(_ type: CFIllustration) -> Image {
        Image(type.rawValue)
    }
    
    static func icon(_ type: CFIcon) -> Image {
        Image(type.rawValue)
    }
}
