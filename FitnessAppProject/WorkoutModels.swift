import Foundation

// --- Data Models for Workouts ---
// This is now the central definition for a single exercise for the whole app.
struct Exercise: Identifiable {
    let id = UUID()
    let name: String
    let sets: Int
    let reps: String
    let animationName: String
}

// This is the central definition for a complete workout plan.
struct Workout: Identifiable {
    let id = UUID()
    let name: String
    let duration: String
    let exercises: [Exercise]
}

