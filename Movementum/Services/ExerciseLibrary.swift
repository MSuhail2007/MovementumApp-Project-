import Foundation

// Models matching the user's proposed exercises.json schema.
// These are kept separate from the app's runtime Exercise model to avoid collisions.

public struct ExerciseSpec: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String?
    public let muscleGroup: [String]
    public let type: String

    // Logic tags
    public let primaryGoals: [String]
    public let difficultyTier: Int
    public let impactLevel: String
    public let equipmentNeeded: [String]

    // Adaptive params
    public let parameters: DifficultyParams
    public let imageName: String?

    // Coding keys to map snake_case JSON keys to camelCase Swift properties
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case muscleGroup = "muscle_group"
        case type
        case primaryGoals = "primary_goals"
        case difficultyTier = "difficulty_tier"
        case impactLevel = "impact_level"
        case equipmentNeeded = "equipment_needed"
        case parameters
        case imageName = "image_name"
    }
}

public struct DifficultyParams: Codable {
    public let beginner: WorkoutDetails
    public let intermediate: WorkoutDetails
    public let advanced: WorkoutDetails
}

public struct WorkoutDetails: Codable {
    public let sets: Int
    // Optional because some exercises use reps (e.g. "10") and others use time (durationSec)
    public let reps: String?
    public let durationSec: Int?
    public let restSec: Int

    enum CodingKeys: String, CodingKey {
        case sets
        case reps
        case durationSec = "duration_sec"
        case restSec = "rest_sec"
    }
}

// Loader utility to read exercises.json from the app bundle
public struct ExerciseLibrary {
    public static func loadExercises(from filename: String) -> [ExerciseSpec] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            print("ExerciseLibrary: could not find resource \(filename).json")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode([ExerciseSpec].self, from: data)
            return decoded
        } catch {
            print("ExerciseLibrary: failed to decode \(filename): \(error)")
            return []
        }
    }
}

// MARK: - Converters to runtime models

extension ExerciseSpec {
    /// Convert to the app's runtime Exercise model using the provided difficulty ("beginner"/"intermediate"/"advanced").
    /// This uses the parameter block to populate sets/reps/restTime. If an exercise uses duration, reps will be set to duration string.
    func toAppExercise(for difficulty: String) -> Exercise {
        let level = difficulty.lowercased()
        let details: WorkoutDetails
        if level.contains("beginner") { details = parameters.beginner }
        else if level.contains("intermediate") { details = parameters.intermediate }
        else { details = parameters.advanced }

        let repsOrDuration: String = {
            if let r = details.reps { return r }
            if let d = details.durationSec { return "\(d)s" }
            return ""
        }()

        // Map string 'type' to ExerciseType enum where possible
        let typeEnum: ExerciseType = {
            let t = type.lowercased()
            if t.contains("upper") { return .upperBody }
            if t.contains("lower") { return .lowerBody }
            if t.contains("core") { return .core }
            if t.contains("cardio") { return .cardio }
            if t.contains("mobility") || t.contains("stretch") { return .mobility }
            return .cardio
        }()

        // Build the app Exercise (existing model uses sets/reps/restTime/type)
        return Exercise(name: name, sets: details.sets, reps: repsOrDuration, restTime: details.restSec, type: typeEnum, animationName: imageName ?? "")
    }

    /// Convert to the Recommender's PlannedExercise using a difficulty level string
    func toPlannedExercise(for difficulty: String) -> WorkoutRecommender.PlannedExercise {
        let level = difficulty.lowercased()
        let details: WorkoutDetails
        if level.contains("beginner") { details = parameters.beginner }
        else if level.contains("intermediate") { details = parameters.intermediate }
        else { details = parameters.advanced }

        let repsOrDuration: String = {
            if let r = details.reps { return r }
            if let d = details.durationSec { return "\(d)s" }
            return ""
        }()

        return WorkoutRecommender.PlannedExercise(name: name, target: muscleGroup.first, impact: impactLevel, sets: details.sets, reps: repsOrDuration, rest: details.restSec)
    }
}
