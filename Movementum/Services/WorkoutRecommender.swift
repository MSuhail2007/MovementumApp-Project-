import Foundation

class WorkoutRecommender {
    static let shared = WorkoutRecommender()
    
    func calculateBMI(height: Double, weight: Double) -> Double {
        guard height > 0 else { return 0 }
        return weight / (height * height)
    }
    
    /// Legacy helper kept for compatibility
    func suggestWorkout(height: Double, weight: Double, age: Int, goal: String, allWorkouts: [Workout]) -> [Workout] {
        let bmi = calculateBMI(height: height, weight: weight)
        var filteredWorkouts = allWorkouts.filter { $0.goalCategory == goal }
        
        // Safety filtering: prioritize low-impact if BMI>29 or age>55
        if bmi > 29.0 || age > 55 {
            // If there are low-impact workouts for this goal, prefer them
            let lowImpact = filteredWorkouts.filter { $0.isLowImpact }
            if !lowImpact.isEmpty {
                return lowImpact
            }
            // otherwise, try to downgrade intensity by returning workouts marked Beginner
            let beginner = filteredWorkouts.filter { $0.difficulty.lowercased().contains("beginner") }
            if !beginner.isEmpty {
                return beginner
            }
        }
        
        // Otherwise return all workouts matching goal
        return filteredWorkouts
    }
    
    /// New: suggest workouts using the full `UserProfile` (goal, difficulty, workoutMode, height, weight).
    /// - Parameters:
    ///   - profile: the user's profile
    ///   - age: user's age (used for safety decisions)
    ///   - allWorkouts: source list of workouts to consider (repository or library)
    /// - Returns: ordered list of matching workouts (most appropriate first)
    func suggestWorkouts(for profile: UserProfile, age: Int, allWorkouts: [Workout]) -> [Workout] {
        // Normalize height: if height appears to be stored in cm (>3) convert to meters
        let normalizedHeight: Double = profile.height > 3 ? (profile.height / 100.0) : profile.height
        let bmi = calculateBMI(height: normalizedHeight, weight: profile.weight)
        
        // 1) Filter by goal
        var candidates = allWorkouts.filter { $0.goalCategory.caseInsensitiveCompare(profile.goal) == .orderedSame }
        
        // 2) Mode filter: prefer workouts that support the user's chosen mode
        let modeMatches = candidates.filter { $0.allowedModes.contains(where: { $0.caseInsensitiveCompare(profile.workoutMode) == .orderedSame }) }
        if !modeMatches.isEmpty {
            candidates = modeMatches
        }
        
        // 3) Difficulty: prefer exact difficulty match
        let difficultyMatches = candidates.filter { $0.difficulty.caseInsensitiveCompare(profile.difficultyLevel) == .orderedSame }
        if !difficultyMatches.isEmpty {
            candidates = difficultyMatches
        }
        
        // 4) Safety prioritization (BMI or age)
        if bmi > 29.0 || age > 55 {
            let lowImpact = candidates.filter { $0.isLowImpact }
            if !lowImpact.isEmpty { candidates = lowImpact }
            else {
                let beginner = candidates.filter { $0.difficulty.lowercased().contains("beginner") }
                if !beginner.isEmpty { candidates = beginner }
            }
        }
        
        // 5) Sort: prefer exact mode & difficulty, then lowImpact, then duration ascending
        candidates.sort { a, b in
            // exact difficulty match score
            let aDiff = a.difficulty.caseInsensitiveCompare(profile.difficultyLevel) == .orderedSame ? 1 : 0
            let bDiff = b.difficulty.caseInsensitiveCompare(profile.difficultyLevel) == .orderedSame ? 1 : 0
            if aDiff != bDiff { return aDiff > bDiff }

            // mode match
            let aMode = a.allowedModes.contains(where: { $0.caseInsensitiveCompare(profile.workoutMode) == .orderedSame }) ? 1 : 0
            let bMode = b.allowedModes.contains(where: { $0.caseInsensitiveCompare(profile.workoutMode) == .orderedSame }) ? 1 : 0
            if aMode != bMode { return aMode > bMode }

            // low impact prefered when BMI/age high
            if bmi > 29.0 || age > 55 {
                if a.isLowImpact != b.isLowImpact { return a.isLowImpact && !b.isLowImpact }
            }

            // fallback: shorter duration (try to parse minutes if provided)
            let aMinutes = extractMinutes(from: a.duration)
            let bMinutes = extractMinutes(from: b.duration)
            return aMinutes < bMinutes
        }
        
        // Final fallback: if empty, return allWorkouts for the goal
        if candidates.isEmpty {
            candidates = allWorkouts.filter { $0.goalCategory.caseInsensitiveCompare(profile.goal) == .orderedSame }
        }
        
        return candidates
    }
    
    /// A simple planned exercise that includes training volume suggestions (sets/reps/rest)
    struct PlannedExercise: Codable, Hashable {
        let name: String
        let target: String? // e.g., "lowerBody", "upperBody"
        let impact: String // "High" / "Low"
        let sets: Int
        let reps: String
        let rest: Int // seconds
    }

    /// Generate a daily workout plan using rule-based filters (ValimAI logic described by the user)
    /// - Parameters:
    ///   - profile: UserProfile from DiaryViewModel
    ///   - age: user's age (used for safety checks)
    ///   - allWorkouts: available workouts repository
    /// - Returns: ordered array of PlannedExercise representing today's routine
    func generateDailyPlan(for profile: UserProfile, age: Int, allWorkouts: [Workout]) -> [PlannedExercise] {
        // Normalize height (cm -> m if necessary)
        let normalizedHeight = profile.height > 3 ? (profile.height / 100.0) : profile.height
        let bmi = calculateBMI(height: normalizedHeight, weight: profile.weight)

        // First try to load canonical exercise library (exercises.json) and use it if available
        let specs = ExerciseLibrary.loadExercises(from: "exercises")
        if !specs.isEmpty {
            // Build candidates from ExerciseSpec
            struct SpecCandidate { let spec: ExerciseSpec }
            var specCandidates = specs.map { SpecCandidate(spec: $0) }

            // Safety filtering
            let isHighRisk = (bmi > 30.0) || (age > 50)
            if isHighRisk {
                let lowImpact = specCandidates.filter { $0.spec.impactLevel.lowercased() == "low" }
                if !lowImpact.isEmpty { specCandidates = lowImpact }
                else {
                    // try to find low-impact replacements by matching muscle group
                    let highImpact = specCandidates.filter { $0.spec.impactLevel.lowercased() != "low" }
                    var replacements: [SpecCandidate] = []
                    for removed in highImpact {
                        if let match = specs.first(where: { $0.muscleGroup.first == removed.spec.muscleGroup.first && $0.impactLevel.lowercased() == "low" }) {
                            replacements.append(SpecCandidate(spec: match))
                        }
                    }
                    if !replacements.isEmpty { specCandidates = replacements }
                }
            }

            // Goal filtering
            let goalLower = profile.goal.lowercased()
            specCandidates = specCandidates.filter { sc in
                sc.spec.primaryGoals.contains { $0.caseInsensitiveCompare(profile.goal) == .orderedSame }
            }

            // Difficulty / mode preferences aren't encoded in ExerciseSpec's workout fields, so we just preserve order
            // Deduplicate
            var seen = Set<String>()
            var finalSpecs: [ExerciseSpec] = []
            for sc in specCandidates {
                if !seen.contains(sc.spec.id) {
                    finalSpecs.append(sc.spec)
                    seen.insert(sc.spec.id)
                }
            }

            // Choose desired count based on inferred template
            let g = profile.goal.lowercased()
            let desiredCount: Int = {
                if g.contains("weight") || g.contains("loss") { return 6 }
                if g.contains("strength") { return 5 }
                if g.contains("endurance") { return 6 }
                if g.contains("flex") || g.contains("yoga") { return 8 }
                return 5
            }()

            let chosen = Array(finalSpecs.prefix(desiredCount))

            // Convert to PlannedExercise using user's difficulty
            return chosen.map { $0.toPlannedExercise(for: profile.difficultyLevel) }
        }

        // Fallback: use Workout-level data when exercises.json not present
        // 1) Choose a template based on user's primary goal
        let goal = profile.goal.lowercased()
        enum Template { case weightLoss, strengthGain, endurance, flexibility, generic }
        let template: Template
        if goal.contains("weight") || goal.contains("loss") { template = .weightLoss }
        else if goal.contains("strength") { template = .strengthGain }
        else if goal.contains("endurance") { template = .endurance }
        else if goal.contains("flex") || goal.contains("yoga") { template = .flexibility }
        else { template = .generic }

        // 2) Build a flattened candidate exercise list from workouts that match the template
        struct Candidate {
            let exercise: Exercise
            let workout: Workout
            let impact: String // "High" / "Low"
            let target: String? // muscle type
        }

        var candidates: [Candidate] = []
        for w in allWorkouts {
            // filter workouts by goalCategory similarity for template
            let wc = w.goalCategory.lowercased()
            let matchesTemplate: Bool = {
                switch template {
                case .weightLoss: return wc.contains("weight") || wc.contains("loss") || wc.contains("fat")
                case .strengthGain: return wc.contains("strength") || wc.contains("muscle")
                case .endurance: return wc.contains("endurance") || wc.contains("run") || wc.contains("cardio")
                case .flexibility: return wc.contains("yoga") || wc.contains("flex") || wc.contains("stretch")
                case .generic: return true
                }
            }()
            if !matchesTemplate { continue }

            for ex in w.exercises {
                let imp = w.isLowImpact ? "Low" : "High"
                candidates.append(Candidate(exercise: ex, workout: w, impact: imp, target: ex.type?.rawValue))
            }
        }

        // If no candidates found, fallback to all exercises
        if candidates.isEmpty {
            for w in allWorkouts {
                for ex in w.exercises {
                    let imp = w.isLowImpact ? "Low" : "High"
                    candidates.append(Candidate(exercise: ex, workout: w, impact: imp, target: ex.type?.rawValue))
                }
            }
        }

        // 3) Safety filtering: remove high-impact if necessary
        let isHighRisk = (bmi > 30.0) || (age > 50)
        var filtered = candidates
        var removedHighImpact: [Candidate] = []
        if isHighRisk {
            let beforeCount = filtered.count
            filtered = filtered.filter { $0.impact == "Low" }
            removedHighImpact = candidates.filter { $0.impact == "High" }
            // if everything was removed, we will try to fall back to lower-impact alternatives later
            if filtered.isEmpty {
                // attempt to convert high-impact candidates into safer alternatives by picking other exercises targeting same muscle group
                var replacements: [Candidate] = []
                for removed in removedHighImpact {
                    if let match = candidates.first(where: { $0.target == removed.target && $0.impact == "Low" }) {
                        replacements.append(match)
                    }
                }
                filtered = replacements
            }
            // if still empty, keep original candidates but mark in comments (we still proceed to avoid empty plan)
            if filtered.isEmpty { filtered = candidates }
            let afterCount = filtered.count
            _ = (beforeCount, afterCount) // keep values for debugging if needed
        }

        // 4) Prefer exercises matching user's chosen difficulty level and workout mode
        let diffPref = profile.difficultyLevel.lowercased()
        let modePref = profile.workoutMode.lowercased()

        var prioritized = filtered.sorted { a, b in
            // difficulty score: 1 if matches or a workout is beginner and user beginner, else 0
            let aDiff = a.workout.difficulty.lowercased() == diffPref ? 1 : 0
            let bDiff = b.workout.difficulty.lowercased() == diffPref ? 1 : 0
            if aDiff != bDiff { return aDiff > bDiff }

            // mode score
            let aMode = a.workout.allowedModes.contains(where: { $0.caseInsensitiveCompare(profile.workoutMode) == .orderedSame }) ? 1 : 0
            let bMode = b.workout.allowedModes.contains(where: { $0.caseInsensitiveCompare(profile.workoutMode) == .orderedSame }) ? 1 : 0
            if aMode != bMode { return aMode > bMode }

            // prefer low impact if high risk
            if isHighRisk {
                if a.impact != b.impact { return a.impact == "Low" }
            }

            // fallback: prefer exercises from workouts with shorter duration
            let aMin = extractMinutes(from: a.workout.duration)
            let bMin = extractMinutes(from: b.workout.duration)
            return aMin < bMin
        }

        // 5) Deduplicate by exercise name preserving order
        var finalCandidates: [Candidate] = []
        var seen = Set<String>()
        for c in prioritized {
            if !seen.contains(c.exercise.name) {
                finalCandidates.append(c)
                seen.insert(c.exercise.name)
            }
        }

        // 6) Select number of exercises by template
        let desiredCount: Int = {
            switch template {
            case .weightLoss: return 6
            case .strengthGain: return 5
            case .endurance: return 6
            case .flexibility: return 8
            case .generic: return 5
            }
        }()

        // Clip or pad final list
        var chosen = Array(finalCandidates.prefix(desiredCount))

        // If we removed high-impact earlier and have space, try to add low-impact replacements for variety
        if isHighRisk && chosen.count < desiredCount {
            let extras = finalCandidates.filter { $0.impact == "Low" && !chosen.contains(where: { $0.exercise.name == $0.exercise.name }) }
            for ex in extras.prefix(desiredCount - chosen.count) { chosen.append(ex) }
        }

        // 7) Volume adjustments based on user's difficulty
        func volumeFor(level: String) -> (sets: Int, reps: String, rest: Int) {
            let lvl = level.lowercased()
            if lvl.contains("beginner") { return (3, "10", 60) }
            if lvl.contains("intermediate") { return (4, "12", 45) }
            if lvl.contains("advanced") { return (5, "to failure", 30) }
            // default
            return (3, "10", 60)
        }

        let vol = volumeFor(level: profile.difficultyLevel)

        // 8) Build PlannedExercise list
        var plan: [PlannedExercise] = []
        for c in chosen {
            plan.append(PlannedExercise(name: c.exercise.name, target: c.target, impact: c.impact, sets: vol.sets, reps: vol.reps, rest: vol.rest))
        }

        // 9) If plan empty, as fallback pick any exercises (guard against empty DB)
        if plan.isEmpty {
            // pick first available few
            let fallback = allWorkouts.flatMap { w in w.exercises.map { (w, $0) } }
            for pair in fallback.prefix(5) {
                let ex = pair.1
                plan.append(PlannedExercise(name: ex.name, target: ex.type?.rawValue, impact: pair.0.isLowImpact ? "Low" : "High", sets: vol.sets, reps: vol.reps, rest: vol.rest))
            }
        }

        return plan
    }
    
    /// Generate a 7-day weekly plan (each entry corresponds to day index 0..6)
    /// - Returns: array of tuples (dayIndex, isRestDay, exercises)
    func generateWeeklyPlan(for profile: UserProfile, age: Int, allWorkouts: [Workout]) -> [(dayIndex: Int, isRest: Bool, exercises: [PlannedExercise])] {
        // Determine pattern based on difficulty level
        let level = profile.difficultyLevel.lowercased()
        var pattern: [Bool] // true = workout day, false = rest/active recovery

        if level.contains("beginner") {
            // Workout / Rest / Workout / Rest / Workout / Rest / Rest
            pattern = [true, false, true, false, true, false, false]
        } else if level.contains("intermediate") {
            // Workout / Workout / Rest / Workout / Workout / Rest / Rest
            pattern = [true, true, false, true, true, false, false]
        } else if level.contains("advanced") {
            // Push / Pull / Legs / Push / Pull / Legs / Rest -> we'll mark as workouts every day except last
            pattern = [true, true, true, true, true, true, false]
        } else {
            // default to 3 days on
            pattern = [true, false, true, false, true, false, false]
        }

        // Build week
        var week: [(Int, Bool, [PlannedExercise])] = []

        for day in 0..<7 {
            if pattern[day] {
                // Create a daily plan
                let daily = generateDailyPlan(for: profile, age: age, allWorkouts: allWorkouts)
                week.append((day, false, daily))
            } else {
                // Rest day -> Active recovery suggestion
                let recovery = [PlannedExercise(name: "10-min Stretching", target: "mobility", impact: "Low", sets: 1, reps: "10m", rest: 0),
                                PlannedExercise(name: "Light Walk", target: "cardio", impact: "Low", sets: 1, reps: "5000 steps", rest: 0)]
                week.append((day, true, recovery))
            }
        }

        return week
    }

    private func extractMinutes(from duration: String) -> Int {
        // Attempt to extract an integer number of minutes from strings like "45 Mins", "30 Minutes"
        let numbers = duration.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        if let val = Int(numbers) { return val }
        return 999
    }
}
