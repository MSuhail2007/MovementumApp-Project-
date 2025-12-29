import Foundation

// --- This file is now the single, definitive source of truth for all workout models ---

// An enum to categorize exercises
enum ExerciseType: String, Codable, CaseIterable {
    case upperBody, lowerBody, core, cardio, mobility
}

// A simple Exercise struct, now including the 'type' and restTime
struct Exercise: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var sets: Int
    var reps: String
    var restTime: Int // seconds
    var type: ExerciseType?
    var animationName: String?
}

// The Workout struct now holds an array of these Exercise objects
struct Workout: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var goalCategory: String // "Weight Loss", "Muscle Gain", "Body Recomposition"
    var difficulty: String // "Beginner", "Intermediate", "Advanced"
    var isLowImpact: Bool
    var duration: String
    var allowedModes: [String] // e.g. ["Home","Gym","Dumbbell Only"]
    var exercises: [Exercise]
}

// A data model for our workout days
struct WorkoutDay: Identifiable, Equatable {
    let id = UUID()
    let name: String // e.g., "Mon"
    let dayIndex: Int // 0 for Monday, 1 for Tuesday, etc.
}

// A user-created routine that can be saved and reused
struct UserRoutine: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var duration: String
    var exercises: [Exercise]
    var createdAt: Date
}
