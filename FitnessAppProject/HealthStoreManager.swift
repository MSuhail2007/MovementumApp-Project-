import Foundation
import HealthKit
import Combine

// This class is a dedicated manager for all HealthKit-related tasks.
class HealthStoreManager: ObservableObject {
    
    private let healthStore = HKHealthStore()
    
    // These will hold the fetched data from the Health app
    @Published var dailySteps: Double = 0
    @Published var dailyWaterIntake: Double = 0
    @Published var restingHeartRate: Double = 0
    @Published var hrv: Double = 0
    // --- NEW: A property to hold the formatted sleep duration ---
    @Published var sleepDurationString: String = "--"
    
    // Asks the user for permission to read their health data.
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device.")
            return
        }
        
        // --- UPDATED: We now also ask for permission to read sleep data ---
        let typesToRead: Set = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .dietaryWater)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)! // The sleep data type
        ]
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { success, error in
            if success {
                print("HealthKit authorization granted.")
                // If permission is granted, fetch all of today's data
                self.fetchTodaysSteps()
                self.fetchTodaysWater()
                self.fetchRestingHeartRate()
                self.fetchHRV()
                self.fetchTodaysSleep() // Fetch sleep data
            } else {
                print("HealthKit authorization denied.")
            }
        }
    }
    
    // --- NEW: A function to fetch and calculate today's sleep duration ---
    func fetchTodaysSleep() {
        let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = createTodayPredicate()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let sleepSamples = samples as? [HKCategorySample] else { return }
            
            // Calculate the total duration from all sleep samples
            let totalSeconds = sleepSamples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            
            // Format the duration into "Xh Ym"
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .abbreviated
            formatter.allowedUnits = [.hour, .minute]
            
            DispatchQueue.main.async {
                self.sleepDurationString = formatter.string(from: totalSeconds) ?? "--"
                print("Successfully fetched sleep: \(self.sleepDurationString)")
            }
        }
        healthStore.execute(query)
    }
    
    // (Other fetch functions are unchanged)
    func fetchTodaysSteps() { /* ... */ }
    func fetchTodaysWater() { /* ... */ }
    func fetchRestingHeartRate() { /* ... */ }
    func fetchHRV() { /* ... */ }
    
    private func createTodayPredicate() -> NSPredicate {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = Date()
        return HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    }
}

