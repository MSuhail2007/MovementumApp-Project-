// DiaryViewModel.swift
// Movementum

import Foundation
import SwiftUI
import Combine
import FirebaseAuth

// MARK: - Simple data models used by views
struct UserProfile: Codable, Equatable {
    var name: String
    var dob: Date
    var height: Double
    var weight: Double
    var goal: String
    var workoutDaysPerWeek: Int
    var dailyStepsTarget: Int
    // New onboarding fields
    var difficultyLevel: String // "Beginner", "Intermediate", "Advanced"
    var workoutMode: String // "Home", "Gym", "Dumbbell Only"
}

struct FoodEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var calories: Int
    var protein: Double
    var fat: Double
    var carbs: Double
    var mealType: String
    var date: Date

    init(id: UUID = UUID(), name: String, calories: Int, protein: Double, fat: Double = 0.0, carbs: Double = 0.0, mealType: String, date: Date) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.fat = fat
        self.carbs = carbs
        self.mealType = mealType
        self.date = date
    }
}

struct WorkoutLog: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var duration: String
    var date: Date

    init(id: UUID = UUID(), name: String, duration: String, date: Date) {
        self.id = id
        self.name = name
        self.duration = duration
        self.date = date
    }
}

// Use the shared `UserRoutine` model from Models/WorkoutModels.swift

// MARK: - DiaryViewModel
final class DiaryViewModel: ObservableObject {
    // Published properties used in many views
    @Published var userProfile: UserProfile?
    // nil = unknown (not checked yet), true/false = existence known
    @Published var userProfileExists: Bool?

    @Published private(set) var entries: [FoodEntry] = []
    @Published private(set) var workoutLogs: [WorkoutLog] = []
    @Published private(set) var userRoutines: [UserRoutine] = []

    private var cancellables = Set<AnyCancellable>()
    private var authStateListenerHandle: AuthStateDidChangeListenerHandle?

    // MARK: - Persistence helpers
    private struct PersistedData: Codable {
        var userProfile: UserProfile?
        var entries: [FoodEntry]
        var workoutLogs: [WorkoutLog]
        var userRoutines: [UserRoutine]
    }

    // Legacy format (before height/weight/goal were added)
    private struct LegacyUserProfile: Codable {
        var name: String
        var dob: Date
        var workoutDaysPerWeek: Int
        var dailyStepsTarget: Int
    }

    private struct LegacyPersistedData: Codable {
        var userProfile: LegacyUserProfile?
        var entries: [FoodEntry]
        var workoutLogs: [WorkoutLog]
        // older versions did not include user routines
        var userRoutines: [UserRoutine]?
    }

    private var dataFileURL: URL {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("diary_data.json")
    }

    #if DEBUG
    /// Debug helper to expose the data file URL so developers can inspect the saved JSON when running the app.
    var debugDataFileURL: URL {
        dataFileURL
    }
    #endif

    private func saveToDisk() {
        let container = PersistedData(userProfile: userProfile, entries: entries, workoutLogs: workoutLogs, userRoutines: userRoutines)
        do {
            let data = try JSONEncoder().encode(container)
            try data.write(to: dataFileURL, options: .atomic)
        } catch {
            // For now we swallow errors but log them — in a full app you'd surface or recover
            print("DiaryViewModel: failed to save data: \(error)")
        }
    }

    private func loadFromDisk() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: dataFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: dataFileURL)
            let container = try JSONDecoder().decode(PersistedData.self, from: data)
            // Assign loaded values on main thread
            DispatchQueue.main.async {
                self.userProfile = container.userProfile
                self.userProfileExists = container.userProfile != nil
                self.entries = container.entries
                self.workoutLogs = container.workoutLogs
                self.userRoutines = container.userRoutines
            }
        } catch {
            // If decoding fails, attempt to decode legacy format and migrate
            do {
                let data = try Data(contentsOf: dataFileURL)
                let legacy = try JSONDecoder().decode(LegacyPersistedData.self, from: data)
                DispatchQueue.main.async {
                    if let legacyProfile = legacy.userProfile {
                        // provide reasonable defaults for new fields when migrating
                        let migrated = UserProfile(
                            name: legacyProfile.name,
                            dob: legacyProfile.dob,
                            height: 0.0,
                            weight: 0.0,
                            goal: "General Fitness",
                            workoutDaysPerWeek: legacyProfile.workoutDaysPerWeek,
                            dailyStepsTarget: legacyProfile.dailyStepsTarget,
                            difficultyLevel: "Beginner", // default value
                            workoutMode: "Home" // default value
                        )
                        self.userProfile = migrated
                        self.userProfileExists = true
                    } else {
                        self.userProfile = nil
                        self.userProfileExists = false
                    }

                    self.entries = legacy.entries
                    self.workoutLogs = legacy.workoutLogs
                    self.userRoutines = legacy.userRoutines ?? []

                    // Save migrated data back to disk so future loads use the new format
                    self.saveToDisk()
                }
            } catch {
                print("DiaryViewModel: failed to load data: \(error)")
            }
        }
    }

    // MARK: - Computed goals used by views
    var calculatedCalorieGoal: Double {
        let base = 2000.0
        guard let profile = userProfile else { return base }
        switch profile.workoutDaysPerWeek {
        case 0...2: return base - 200
        case 3: return base
        case 4: return base + 150
        default: return base + 300
        }
    }

    var calculatedProteinGoal: Double {
        let base = 112.0
        guard let profile = userProfile else { return base }
        if profile.workoutDaysPerWeek >= 4 { return base + 20 }
        if profile.workoutDaysPerWeek <= 2 { return base - 20 }
        return base
    }

    // MARK: - Init
    init(isForPreview: Bool = false) {
        if isForPreview {
            seedPreviewData()
        } else {
            // In the real app you'd initialize listeners (e.g. Firebase Auth, DB sync)
            userProfile = nil
            userProfileExists = nil
            // load persisted data if present
            loadFromDisk()

            // autosave whenever any of the main published properties change
            Publishers.CombineLatest4($userProfile, $entries, $workoutLogs, $userRoutines)
                .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.saveToDisk()
                }
                .store(in: &cancellables)
        }
    }

    // MARK: - Public API used by Views
    func fetchEntries(for date: Date, mealType: String? = nil) -> [FoodEntry] {
        entries.filter { entry in
            Calendar.current.isDate(entry.date, inSameDayAs: date) && (mealType == nil || entry.mealType == mealType)
        }
    }

    func fetchWorkoutLogs(for date: Date) -> [WorkoutLog] {
        workoutLogs.filter { log in
            Calendar.current.isDate(log.date, inSameDayAs: date)
        }
    }

    func add(entry: FoodEntry) {
        entries.append(entry)
        // Persist or sync to backend in a full implementation
        // saveToDisk() will be triggered by the autosave pipeline
    }

    func add(workoutLog: WorkoutLog) {
        workoutLogs.append(workoutLog)
    }

    func save(userProfile profile: UserProfile) {
        self.userProfile = profile
        self.userProfileExists = true
        // Persist locally if needed — autosave will handle this
    }

    /// Register a Firebase Auth state listener and map auth state to app flow.
    /// - If a Firebase user is present, attempt to load a persisted app profile. If none
    ///   exists, mark `userProfileExists = false` so the UI navigates to onboarding.
    /// - If there's a persisted profile, mark `userProfileExists = true` and set `appState.isLoggedIn`.
    func listenForAuthChanges(appState: AppState) {
        // Remove any existing listener first
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
            authStateListenerHandle = nil
        }

        authStateListenerHandle = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if let _ = user {
                    // User signed in. Try to load local persisted profile.
                    self.loadFromDisk()

                    if self.userProfile != nil {
                        // Returning user with saved profile — go straight to app.
                        self.userProfileExists = true
                        appState.isLoggedIn = true
                    } else {
                        // Signed-in user but no saved profile — treat as new user, go to onboarding.
                        self.userProfileExists = false
                        appState.isLoggedIn = false
                    }
                } else {
                    // User signed out — reset state so LoginView shows.
                    self.userProfile = nil
                    self.userProfileExists = nil
                    appState.isLoggedIn = false
                }
            }
        }
    }

    deinit {
        if let handle = authStateListenerHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // New helper APIs
    func update(entry: FoodEntry) {
        guard let idx = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[idx] = entry
    }

    func remove(entryID: UUID) {
        entries.removeAll { $0.id == entryID }
    }

    func remove(workoutID: UUID) {
        workoutLogs.removeAll { $0.id == workoutID }
    }

    // MARK: - User routines (simple local storage)
    func add(routine: UserRoutine) {
        userRoutines.append(routine)
    }

    func removeRoutine(_ routine: UserRoutine) {
        userRoutines.removeAll { $0.id == routine.id }
    }

    func clearAllData() {
        userProfile = nil
        userProfileExists = false
        entries.removeAll()
        workoutLogs.removeAll()
        saveToDisk()
    }

    // MARK: - Preview seed
    private func seedPreviewData() {
        let profile = UserProfile(name: "Alex", dob: Date(timeIntervalSince1970: 0), height: 170.0, weight: 70.0, goal: "General Fitness", workoutDaysPerWeek: 3, dailyStepsTarget: 8000, difficultyLevel: "Beginner", workoutMode: "Home")
        self.userProfile = profile
        self.userProfileExists = true

        let now = Date()
        entries = [
            FoodEntry(name: "Oats with banana", calories: 350, protein: 12.5, mealType: "Breakfast", date: now),
            FoodEntry(name: "Chicken salad", calories: 520, protein: 36.0, mealType: "Lunch", date: now),
            FoodEntry(name: "Paneer curry", calories: 650, protein: 28.0, mealType: "Dinner", date: now)
        ]

        workoutLogs = [
            WorkoutLog(name: "Full Body Strength", duration: "50 Mins", date: now)
        ]

        // simple preview routine (uses shared UserRoutine model)
        userRoutines = [
            UserRoutine(name: "Quick Full Body", duration: "30 Minutes", exercises: [], createdAt: now)
        ]
    }
}
