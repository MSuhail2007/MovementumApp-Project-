import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

// --- Data Models ---
struct UserProfile: Codable, Equatable {
    var name: String
    var dob: Date
    var height: Double // Stored in cm
    var weight: Double // Stored in kg
    var goal: String
    // A property to store the user's workout frequency
    var workoutDaysPerWeek: Int
}

struct WorkoutLog: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    let name: String
    let duration: String
    let date: Date
}

struct FoodEntry: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    let name: String
    let calories: Int
    let protein: Double
    let mealType: String
    let date: Date
}


class DiaryViewModel: ObservableObject {
    // --- Published Properties ---
    @Published var foodEntries: [FoodEntry] = []
    @Published var workoutLogs: [WorkoutLog] = []
    @Published var userProfile: UserProfile?
    @Published var userProfileExists: Bool? = nil
    
    @Published var userID: String?
    private lazy var db = Firestore.firestore()
    private var listenerRegistrations: [ListenerRegistration] = []
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    // --- Authentication ---
    func listenForAuthChanges(appState: AppState) {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            if let user = user {
                self.userID = user.uid
                self.fetchData(appState: appState)
            } else {
                // On logout, clear all data and reset the app state
                self.userID = nil
                self.userProfile = nil
                self.userProfileExists = nil
                self.foodEntries.removeAll()
                self.workoutLogs.removeAll()
                self.listenerRegistrations.forEach { $0.remove() }
                appState.isLoggedIn = false
            }
        }
    }
    
    // --- Data Fetching ---
    private func fetchData(appState: AppState) {
        guard let userID = self.userID else { return }
        
        listenerRegistrations.forEach { $0.remove() }
        
        let profileListener = db.collection("users").document(userID)
            .addSnapshotListener { documentSnapshot, error in
                if documentSnapshot?.exists == true {
                    self.userProfile = try? documentSnapshot?.data(as: UserProfile.self)
                    self.userProfileExists = true
                    appState.isLoggedIn = true
                } else {
                    self.userProfileExists = false
                }
            }
        
        let foodListener = db.collection("users").document(userID).collection("foodEntries")
            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents else { return }
                self.foodEntries = documents.compactMap { try? $0.data(as: FoodEntry.self) }
            }
        
        let workoutListener = db.collection("users").document(userID).collection("workoutLogs")
            .addSnapshotListener { querySnapshot, error in
                guard let documents = querySnapshot?.documents else { return }
                self.workoutLogs = documents.compactMap { try? $0.data(as: WorkoutLog.self) }
            }
        
        listenerRegistrations.append(contentsOf: [profileListener, foodListener, workoutListener])
    }

    // --- Data Saving (with Simulator Logic) ---
    func save(userProfile: UserProfile) {
        if let userID = userID {
            do {
                try db.collection("users").document(userID).setData(from: userProfile, merge: true)
            } catch { print("Error saving user profile: \(error)") }
        } else {
            self.userProfile = userProfile
        }
    }
    
    func add(entry: FoodEntry) {
        if let userID = userID {
            do {
                _ = try db.collection("users").document(userID).collection("foodEntries").addDocument(from: entry)
            } catch { print("Error saving food entry: \(error)") }
        } else {
            foodEntries.append(entry)
        }
    }
    
    func add(workoutLog: WorkoutLog) {
        if let userID = userID {
            do {
                _ = try db.collection("users").document(userID).collection("workoutLogs").addDocument(from: workoutLog)
            } catch { print("Error saving workout log: \(error)") }
        } else {
            workoutLogs.append(workoutLog)
        }
    }
    
    // --- Helper Functions for Filtering ---
    func fetchEntries(for date: Date) -> [FoodEntry] {
        foodEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    func fetchEntries(for date: Date, mealType: String) -> [FoodEntry] {
        foodEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: date) && $0.mealType == mealType }
    }
    func fetchWorkoutLogs(for date: Date) -> [WorkoutLog] {
        workoutLogs.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }
    
    // --- Initializers ---
    init() {}
    
    convenience init(isForPreview: Bool = false, isForSimulator: Bool = false) {
        self.init()
        if isForPreview || isForSimulator {
            self.userProfile = UserProfile(
                name: "Suhail",
                dob: Calendar.current.date(from: .init(year: 2000, month: 1, day: 1))!,
                height: 175,
                weight: 70,
                goal: "Strength Gain",
                workoutDaysPerWeek: 5
            )
            self.foodEntries = []
            self.workoutLogs = []
        }
    }
}

