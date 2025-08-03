//
//  Font+Extension.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 29/12/24.
//

import SwiftUI

extension Font {
    
    static func cfFont(_ type: CFFontType, _ size: CFFontSize) -> Font {
        .custom(type.rawValue, fixedSize: size.value)
    }
}
