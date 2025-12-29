//
//  GoalType.swift
//  Movementum
//
//  Created by Mohammed suhail on 13/10/2025.
//


import Foundation
import Combine

// --- This file is now the single source of truth for all shared models ---

// MARK: - Onboarding & Goal Models
enum GoalType: String, Codable, CaseIterable, Identifiable {
    case weightLoss = "Weight Loss"
    case muscleGain = "Muscle Gain"
    case bodyRecomposition = "Body Recomposition"
    var id: String { self.rawValue }
}

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case bodyweight = "Home (No Equipment)"
    case dumbbells = "Home (Dumbbells Only)"
    case fullGym = "Full Gym"
    var id: String { self.rawValue }
}

enum DietaryPreference: String, CaseIterable, Identifiable {
    case anything = "Anything"
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    var id: String { self.rawValue }
}

class OnboardingData: ObservableObject {
    @Published var goalType: GoalType? = nil
    @Published var customGoal: String = ""
    @Published var workoutDaysPerWeek: Int = 3
    @Published var equipment: Equipment = .bodyweight
    @Published var dietaryPreference: DietaryPreference = .anything
    @Published var workoutPlanSummary: String?
    @Published var dietPlanSummary: String?
}

// --- All workout and exercise-related models have been removed ---
