//
//  AppStateView.swift
//  FitnessAppProject
//
//  Created by Mohammed suhail on 25/08/2025.
//

import SwiftUI
import Combine

// This class will be used to share data across different parts of our app.
// Specifically, it will track the user's login status.
class AppState: ObservableObject {
    @Published var isLoggedIn = false
}
