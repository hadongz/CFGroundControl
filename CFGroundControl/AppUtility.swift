//
//  AppUtility.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 29/12/24.
//

import SwiftUI

final class AppUtility: ObservableObject {
    
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
    
    var window: UIWindow? {
        guard let scene = UIApplication.shared.connectedScenes.first,
              let windowSceneDelegate = scene.delegate as? UIWindowSceneDelegate,
              let window = windowSceneDelegate.window else
        { return nil }
        return window
    }
    
    var statusBarHeight: CGFloat {
        return window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
    }
    
    var safeAreaInsets: UIEdgeInsets {
        window?.safeAreaInsets ?? .zero
    }
    
    init() {
        feedbackGenerator.prepare()
    }
    
    func addImpactFeedback() {
        feedbackGenerator.impactOccurred()
    }
}
