import Foundation

final class WorkoutRepository {
    static let shared = WorkoutRepository()

    private(set) var allWorkouts: [Workout] = []

    private init() {
        // Prefer canonical exercises.json via ExerciseLibrary; fall back to the static built-ins if missing
        let specs = ExerciseLibrary.loadExercises(from: "exercises")
        if !specs.isEmpty {
            // Convert each ExerciseSpec into a tiny Workout so the repository can continue to return [Workout]
            var generated: [Workout] = []
            for spec in specs {
                // Map difficulty tier to a readable difficulty
                let difficulty: String = {
                    switch spec.difficultyTier {
                    case 1: return "Beginner"
                    case 2: return "Intermediate"
                    case 3: return "Advanced"
                    default: return "Intermediate"
                    }
                }()

                // Use the first primary goal as the workout's goal category (if multiple goals exist)
                let goalCat = spec.primaryGoals.first ?? "General"

                // Convert the spec to an app Exercise using the intermediate parameters as representative
                let ex = spec.toAppExercise(for: "Intermediate")

                let workout = Workout(name: spec.name, goalCategory: goalCat, difficulty: difficulty, isLowImpact: spec.impactLevel.lowercased() == "low", duration: "10 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: [ex])
                generated.append(workout)
            }

            allWorkouts = generated
        } else {
            // No canonical exercises.json found — use the built-in static workouts
            allWorkouts = WorkoutRepository.staticBuiltIns()
        }

        // Ensure there's at least the static built-ins if everything else failed
        if allWorkouts.isEmpty {
            allWorkouts = WorkoutRepository.staticBuiltIns()
        }
    }

    private static func staticBuiltIns() -> [Workout] {
        return [
            Workout(name: "Metabolic Igniter", goalCategory: "Weight Loss", difficulty: "Intermediate", isLowImpact: false, duration: "30 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: [
                Exercise(name: "Jumping Jacks", sets: 3, reps: "60s", restTime: 15, type: .cardio, animationName: "jumping_jacks"),
                Exercise(name: "Bodyweight Squats", sets: 3, reps: "20 reps", restTime: 15, type: .lowerBody, animationName: "squat"),
            ])
        ]
    }

    // Convenience lookup
    func workouts(forGoal goal: String) -> [Workout] {
        allWorkouts.filter { $0.goalCategory.caseInsensitiveCompare(goal) == .orderedSame }
    }
}
