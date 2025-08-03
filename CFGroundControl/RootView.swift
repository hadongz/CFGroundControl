//
//  RootView.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 29/12/24.
//

import SwiftUI

struct RootView: View {
    @EnvironmentObject var navigaionManager: NavigationManager
    
    var body: some View {
        NavigationStack(path: $navigaionManager.navigationPath) {
            HomeView()
        }
    }
}
