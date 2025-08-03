//
//  CFGroundControlApp.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 25/07/25.
//

import SwiftUI

@main
struct CFGroundControlApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject var appUtility = AppUtility()
    @StateObject var navigationManager = NavigationManager()
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(navigationManager)
                .environmentObject(appUtility)
        }
    }
}
