//
//  AppStateView.swift
//  FitnessAppProject
//
//  Created by Mohammed mithul pranav n on 25/08/2025.
//

import SwiftUI
import Combine

// This class will be used to share data across different parts of our app.
// Specifically, it will track the user's login status and app-wide appearance mode.
class AppState: ObservableObject {
    @Published var isLoggedIn = false

    // Persisted appearance preference: "system", "light", "dark"
    @AppStorage("appearanceMode") private var storedAppearance: String = "system"

    // Provide a safe default so property initialization doesn't rely on reading another property.
    @Published var appearanceMode: String = "system" {
        didSet { storedAppearance = appearanceMode }
    }

    init() {
        // Now both properties are initialized; read persisted value and apply it.
        self.appearanceMode = storedAppearance
    }

    // Convenience helpers
    var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
