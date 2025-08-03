//
//  UINavControllerHelper.swift
//  SnapSevit
//
//  Created by Muhammad Hadi on 29/12/24.
//

import UIKit

final class UINavControllerHelper {
    
    static let shared = UINavControllerHelper()
    
    func getRootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first,
              let windowSceneDelegate = scene.delegate as? UIWindowSceneDelegate,
              let window = windowSceneDelegate.window else
        { return nil }
        return window?.rootViewController
    }
}
