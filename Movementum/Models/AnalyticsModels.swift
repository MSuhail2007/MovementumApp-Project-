//
//  AnalyticsMetric.swift
//  Movementum
//
//  Created by Mohammed suhail on 05/10/2025.
//


import Foundation
import SwiftUI

// Shared analytics data model used across the app
struct DailyAnalyticsData: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let value: Double
}

// --- Enums to manage the state of the analytics filters ---
// By placing these in their own file, they are now accessible to the entire app.
enum AnalyticsMetric: String, CaseIterable, Identifiable {
    case calories = "Kcal"
    case protein = "Protein"
    case workouts = "Workouts"
    var id: String { self.rawValue }
}

enum AnalyticsTimeRange: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    var id: String { self.rawValue }
}
