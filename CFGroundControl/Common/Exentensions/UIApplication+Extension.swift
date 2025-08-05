//
//  UIApplication+Extension.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 06/08/25.
//

import UIKit

extension UIApplication {
    var currentKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
    
    var rootViewController: UIViewController? {
        currentKeyWindow?.rootViewController
    }
}
