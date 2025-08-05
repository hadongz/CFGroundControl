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
    
    func share(items: [Any], from viewController: UIViewController? = nil, cleanup: (() -> Void)? = nil) {
        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)
        
        if let cleanup = cleanup {
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                cleanup()
            }
        }
        
        let presenter = viewController ?? UIApplication.shared.rootViewController
        
        guard let presenter = presenter else { return }
        
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX, y: presenter.view.bounds.midY, width: 0, height: 0)
        }
        
        presenter.present(activityVC, animated: true)
    }
}
