//
//  NavigationManager.swift
//  CFGroundControl
//
//  Created by Muhammad Hadi on 30/12/24.
//

import SwiftUI

final class NavigationManager: ObservableObject {
    @Published var navigationPath: NavigationPath = NavigationPath()
    
    func push(_ type: any Hashable) {
        navigationPath.append(type)
    }
    
    func pop() {
        guard navigationPath.count > 0 else { return }
        navigationPath.removeLast()
    }
}
