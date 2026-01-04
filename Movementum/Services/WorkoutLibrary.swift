import Foundation

// A local workout library that builds workouts deterministically based on the user's goal
// and the configured workout frequency. This provides a fast, offline fallback to any AI
// planner and is used by the UI to show the user's daily plan.

struct WorkoutLibrary {
    static let shared = WorkoutLibrary()
    
    // A compact list of common exercises used across the app
    private let allExercises: [Exercise] = [
        // Upper Body
        Exercise(name: "Bench Press", sets: 3, reps: "8-12 reps", restTime: 90, type: .upperBody, animationName: "bench_press"),
        Exercise(name: "Pull Ups", sets: 3, reps: "To failure", restTime: 90, type: .upperBody, animationName: "pull_up"),
        Exercise(name: "Overhead Press", sets: 3, reps: "8-12 reps", restTime: 90, type: .upperBody, animationName: "overhead_press"),
        Exercise(name: "Dumbbell Row", sets: 3, reps: "8-12 reps", restTime: 90, type: .upperBody, animationName: "db_row"),
        // Lower Body
        Exercise(name: "Squats", sets: 3, reps: "8-12 reps", restTime: 90, type: .lowerBody, animationName: "squat"),
        Exercise(name: "Deadlifts", sets: 3, reps: "5-8 reps", restTime: 120, type: .lowerBody, animationName: "deadlift"),
        Exercise(name: "Lunges", sets: 3, reps: "12 reps/leg", restTime: 60, type: .lowerBody, animationName: "lunge"),
        Exercise(name: "Glute Bridges", sets: 3, reps: "12-15 reps", restTime: 60, type: .lowerBody, animationName: "glute_bridge"),
        // Core
        Exercise(name: "Plank", sets: 3, reps: "45s", restTime: 30, type: .core, animationName: "plank"),
        Exercise(name: "Bicycle Crunch", sets: 3, reps: "20 reps", restTime: 30, type: .core, animationName: "bicycle_crunch"),
        // Cardio / Conditioning
        Exercise(name: "Burpees", sets: 3, reps: "12 reps", restTime: 30, type: .cardio, animationName: "burpee"),
        Exercise(name: "Jump Rope", sets: 5, reps: "1 min", restTime: 30, type: .cardio, animationName: "jump_rope"),
        Exercise(name: "Mountain Climbers", sets: 4, reps: "30s", restTime: 15, type: .cardio, animationName: "mountain_climber"),
        // Mobility
        Exercise(name: "Cat-Cow Stretch", sets: 2, reps: "10 reps", restTime: 20, type: .mobility, animationName: "cat_cow"),
        Exercise(name: "World's Greatest Stretch", sets: 2, reps: "6 reps/side", restTime: 30, type: .mobility, animationName: "greatest_stretch"),
        Exercise(name: "Hip Flexor Stretch", sets: 2, reps: "30s/side", restTime: 30, type: .mobility, animationName: "hip_flexor"),
    ]
    
    // Public API: returns a workout for the given goal and day.
    // Backwards-compatible string-based API (keeps existing callers working)
    func generateWorkout(for goal: String?, dayIndex: Int, daysPerWeek: Int) -> Workout {
        // Map stored string to the new GoalType enum with compatibility for legacy values
        let normalized = (goal ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let goalType: GoalType
        if let gt = GoalType(rawValue: normalized) {
            goalType = gt
        } else {
            // compatibility mapping for legacy goal names
            switch normalized.lowercased() {
            case "strength gain", "build muscle", "build muscle mass", "muscle":
                goalType = .muscleGain
            case "endurance", "cardio":
                goalType = .weightLoss
            case "mobility":
                goalType = .bodyRecomposition
            case "general fitness", "general", "fitness":
                goalType = .bodyRecomposition
            case "weight loss", "fat loss":
                goalType = .weightLoss
            default:
                goalType = .bodyRecomposition
            }
        }
        return generateWorkout(for: goalType, dayIndex: dayIndex, daysPerWeek: daysPerWeek)
    }

    // New GoalType-aware API (preferred)
    func generateWorkout(for goal: GoalType?, dayIndex: Int, daysPerWeek: Int) -> Workout {
        let g = goal ?? .bodyRecomposition
        switch g {
        case .weightLoss:
            return weightLossWorkout(dayIndex: dayIndex, daysPerWeek: daysPerWeek)
        case .muscleGain:
            // map to previous strength template (hypertrophy-focused)
            return strengthWorkout(dayIndex: dayIndex, daysPerWeek: daysPerWeek)
        case .bodyRecomposition:
            // use the general/balanced template for recomposition
            return generalFitnessWorkout(dayIndex: dayIndex, daysPerWeek: daysPerWeek)
        }
    }
    
    // MARK: - Templates
    private func weightLossWorkout(dayIndex: Int, daysPerWeek: Int) -> Workout {
        // Higher emphasis on cardio & full body circuits
        let cardio = exercises(ofType: .cardio, count: 2)
        let fullBody = exercises(ofTypes: [.upperBody, .lowerBody, .core], count: 2)
        let mobility = exercises(ofType: .mobility, count: 1)
        
        // Schedule: alternate circuit/cardio/rest depending on frequency
        switch daysPerWeek {
        case 5:
            if dayIndex % 2 == 0 { return Workout(name: "Full Body Circuit", goalCategory: "Weight Loss", difficulty: "Intermediate", isLowImpact: false, duration: "40 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: cardio + fullBody) }
            else { return Workout(name: "HIIT + Core", goalCategory: "Weight Loss", difficulty: "Intermediate", isLowImpact: false, duration: "30 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: cardio + [Exercise(name: "Plank", sets: 3, reps: "45s", restTime: 30, type: .core, animationName: "plank")]) }
        case 4:
            if dayIndex % 3 == 0 { return Workout(name: "Active Recovery", goalCategory: "Weight Loss", difficulty: "Beginner", isLowImpact: true, duration: "25 Mins", allowedModes: ["Home","Dumbbell Only"], exercises: mobility) }
            return Workout(name: "Circuit + Cardio", goalCategory: "Weight Loss", difficulty: "Intermediate", isLowImpact: false, duration: "35 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: cardio + fullBody)
        case 3:
            if dayIndex == 0 { return Workout(name: "Full Body Strength", goalCategory: "Weight Loss", difficulty: "Intermediate", isLowImpact: false, duration: "45 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: fullBody) }
            if dayIndex == 2 { return Workout(name: "Cardio Intervals", goalCategory: "Weight Loss", difficulty: "Intermediate", isLowImpact: false, duration: "30 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: cardio + mobility) }
            return Workout(name: "Active Recovery", goalCategory: "Weight Loss", difficulty: "Beginner", isLowImpact: true, duration: "25 Mins", allowedModes: ["Home","Dumbbell Only"], exercises: mobility)
        default:
            return Workout(name: "Cardio + Mobility", goalCategory: "Weight Loss", difficulty: "Beginner", isLowImpact: false, duration: "30 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: cardio + mobility)
        }
    }
    
    private func strengthWorkout(dayIndex: Int, daysPerWeek: Int) -> Workout {
        // Emphasis on heavy compound lifts and lower volume accessory work
        let upper = exercises(ofType: .upperBody, count: 2)
        let lower = exercises(ofType: .lowerBody, count: 2)
        let core = exercises(ofType: .core, count: 1)
        let mobility = exercises(ofType: .mobility, count: 1)
        
        switch daysPerWeek {
        case 5:
            switch dayIndex % 5 {
            case 0: return Workout(name: "Upper Body Strength A", goalCategory: "Muscle Gain", difficulty: "Intermediate", isLowImpact: false, duration: "50 Mins", allowedModes: ["Gym","Dumbbell Only"], exercises: upper + core)
            case 1: return Workout(name: "Lower Body Strength A", goalCategory: "Muscle Gain", difficulty: "Intermediate", isLowImpact: false, duration: "50 Mins", allowedModes: ["Gym","Dumbbell Only"], exercises: lower + mobility)
            case 2: return Workout(name: "Full Body", goalCategory: "Muscle Gain", difficulty: "Intermediate", isLowImpact: false, duration: "55 Mins", allowedModes: ["Gym","Dumbbell Only"], exercises: upper + lower + core)
            case 3: return Workout(name: "Upper Body Strength B", goalCategory: "Muscle Gain", difficulty: "Intermediate", isLowImpact: false, duration: "50 Mins", allowedModes: ["Gym","Dumbbell Only"], exercises: upper + core)
            default: return Workout(name: "Lower Body Strength B", goalCategory: "Muscle Gain", difficulty: "Intermediate", isLowImpact: false, duration: "50 Mins", allowedModes: ["Gym","Dumbbell Only"], exercises: lower + mobility)
            }
        case 4:
            if dayIndex % 4 == 0 || dayIndex % 4 == 2 { return Workout(name: "Upper Body", goalCategory: "Muscle Gain", difficulty: "Intermediate", isLowImpact: false, duration: "50 Mins", allowedModes: ["Gym","Dumbbell Only"], exercises: upper + core) }
            return Workout(name: "Lower Body", goalCategory: "Muscle Gain", difficulty: "Intermediate", isLowImpact: false, duration: "50 Mins", allowedModes: ["Gym","Dumbbell Only"], exercises: lower + mobility)
        case 3:
            if dayIndex % 3 == 0 { return Workout(name: "Full Body Strength", goalCategory: "Muscle Gain", difficulty: "Intermediate", isLowImpact: false, duration: "55 Mins", allowedModes: ["Gym","Dumbbell Only"], exercises: upper + lower + core) }
            if dayIndex % 3 == 1 { return Workout(name: "Upper Focus", goalCategory: "Muscle Gain", difficulty: "Intermediate", isLowImpact: false, duration: "50 Mins", allowedModes: ["Gym","Dumbbell Only"], exercises: upper + core) }
            return Workout(name: "Lower Focus", goalCategory: "Muscle Gain", difficulty: "Intermediate", isLowImpact: false, duration: "50 Mins", allowedModes: ["Gym","Dumbbell Only"], exercises: lower + mobility)
        default:
            return Workout(name: "Full Body Strength", goalCategory: "Muscle Gain", difficulty: "Intermediate", isLowImpact: false, duration: "50 Mins", allowedModes: ["Gym","Dumbbell Only"], exercises: upper + lower + core)
        }
    }
    
    private func enduranceWorkout(dayIndex: Int, daysPerWeek: Int) -> Workout {
        // Longer duration, higher reps, sustained cardio
        let cardio = exercises(ofType: .cardio, count: 2)
        let core = exercises(ofType: .core, count: 1)
        let mobility = exercises(ofType: .mobility, count: 1)
        
        switch daysPerWeek {
        case 5,4:
            if dayIndex % 3 == 0 { return Workout(name: "Long Cardio", goalCategory: "Weight Loss", difficulty: "Intermediate", isLowImpact: false, duration: "45-60 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: cardio + mobility) }
            return Workout(name: "Tempo + Core", goalCategory: "Weight Loss", difficulty: "Intermediate", isLowImpact: false, duration: "40 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: cardio + core)
        case 3:
            if dayIndex == 1 { return Workout(name: "Long Endurance", goalCategory: "Weight Loss", difficulty: "Intermediate", isLowImpact: false, duration: "60 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: cardio + mobility) }
            return Workout(name: "Interval Conditioning", goalCategory: "Weight Loss", difficulty: "Intermediate", isLowImpact: false, duration: "35 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: cardio + core)
        default:
            return Workout(name: "Endurance Session", goalCategory: "Weight Loss", difficulty: "Intermediate", isLowImpact: false, duration: "30-45 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: cardio + mobility)
        }
    }
    
    private func mobilityWorkout(dayIndex: Int) -> Workout {
        let mobility = exercises(ofType: .mobility, count: 3)
        return Workout(name: "Mobility & Recovery", goalCategory: "Body Recomposition", difficulty: "Beginner", isLowImpact: true, duration: "20-30 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: mobility)
    }
    
    private func generalFitnessWorkout(dayIndex: Int, daysPerWeek: Int) -> Workout {
        // Balanced mix of strength, cardio and mobility
        let upper = exercises(ofType: .upperBody, count: 1)
        let lower = exercises(ofType: .lowerBody, count: 1)
        let cardio = exercises(ofType: .cardio, count: 1)
        let core = exercises(ofType: .core, count: 1)
        let mobility = exercises(ofType: .mobility, count: 1)
        
        switch daysPerWeek {
        case 5:
            if dayIndex % 5 == 4 { return Workout(name: "Active Recovery", goalCategory: "Body Recomposition", difficulty: "Beginner", isLowImpact: true, duration: "25 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: mobility) }
            if dayIndex % 2 == 0 { return Workout(name: "Upper + Cardio", goalCategory: "Body Recomposition", difficulty: "Intermediate", isLowImpact: false, duration: "40 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: upper + cardio + core) }
            return Workout(name: "Lower + Mobility", goalCategory: "Body Recomposition", difficulty: "Intermediate", isLowImpact: false, duration: "45 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: lower + mobility + core)
        case 3:
            if dayIndex % 3 == 0 { return Workout(name: "Full Body", goalCategory: "Body Recomposition", difficulty: "Intermediate", isLowImpact: false, duration: "50 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: upper + lower + core) }
            if dayIndex % 3 == 1 { return Workout(name: "Cardio + Core", goalCategory: "Body Recomposition", difficulty: "Intermediate", isLowImpact: false, duration: "35 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: cardio + core) }
            return Workout(name: "Mobility & Strength", goalCategory: "Body Recomposition", difficulty: "Intermediate", isLowImpact: false, duration: "40 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: upper + lower + mobility)
        default:
            return Workout(name: "Balanced Session", goalCategory: "Body Recomposition", difficulty: "Intermediate", isLowImpact: false, duration: "35 Mins", allowedModes: ["Home","Gym","Dumbbell Only"], exercises: upper + lower + core + mobility)
        }
    }

    // New: Generate a 7-day schedule with exactly `profile.workoutDaysPerWeek` workout days (randomized), rest days otherwise.
    func generateWeeklySchedule(for profile: UserProfile) -> [Workout] {
        // Normalize days per week
        let daysPerWeek = max(0, min(7, profile.workoutDaysPerWeek))

        // Helper rest workout
        func restWorkout() -> Workout {
            Workout(name: "Rest Day", goalCategory: "Rest", difficulty: "Rest", isLowImpact: true, duration: "", allowedModes: [], exercises: [])
        }

        // If the user chose 0 days, return all rest days
        guard daysPerWeek > 0 else {
            return Array(repeating: restWorkout(), count: 7)
        }

        // Pick `daysPerWeek` unique day indices in [0..6] randomly
        var indices = Array(0..<7)
        indices.shuffle()
        let picked = Set(indices.prefix(daysPerWeek))

        // Build the week array: for picked indices generate a workout, otherwise Rest
        var week: [Workout] = []
        for day in 0..<7 {
            if picked.contains(day) {
                // Use the existing generator to create a workout for that day
                let workout = generateWorkout(for: profile.goal, dayIndex: day, daysPerWeek: daysPerWeek)
                week.append(workout)
            } else {
                week.append(restWorkout())
            }
        }

        return week
    }

    // MARK: - Helpers
    private func exercises(ofType type: ExerciseType, count: Int) -> [Exercise] {
        let filtered = allExercises.filter { $0.type == type }
        return Array(filtered.prefix(count))
    }
    
    private func exercises(ofTypes types: [ExerciseType], count: Int) -> [Exercise] {
        var result: [Exercise] = []
        for t in types {
            if let e = allExercises.first(where: { $0.type == t && !result.contains($0) }) {
                result.append(e)
            }
            if result.count >= count { break }
        }
        // If not enough, pad with any exercises
        if result.count < count {
            let pad = allExercises.filter { !result.contains($0) }
            result.append(contentsOf: pad.prefix(max(0, count - result.count)))
        }
        return result
    }
}
