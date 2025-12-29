import Foundation
import HealthKit
import Combine

class HealthStoreManager: ObservableObject {
    
    private let healthStore = HKHealthStore()
    
    // All the data points your app can fetch
    @Published var dailySteps: Double = 0
    @Published var restingHeartRate: Double = 0
    @Published var hrv: Double = 0
    @Published var sleepDurationString: String = "--"
    @Published var latestHeight: Double?
    @Published var latestWeight: Double?
    @Published var dailyWaterIntake: Double = 0
    // --- NEW: A property to hold the user's date of birth ---
    @Published var dateOfBirth: Date?

    // --- NEW: Today's water log entries (simple DTO for UI) ---
    struct WaterLogEntry: Identifiable {
        let id = UUID()
        let amountML: Double
        let date: Date
    }
    @Published var waterLogEntries: [WaterLogEntry] = []
    
    // --- This function now accepts a "completion" callback ---
    func requestAuthorization(completion: @escaping () -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not available on this device.")
            completion()
            return
        }

        // --- UPDATED: Request write permission for dietaryWater (so we can save water samples). Also request read permissions as before.
        let dietaryWaterType = HKObjectType.quantityType(forIdentifier: .dietaryWater)!
        let typesToShare: Set<HKSampleType> = [dietaryWaterType]

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            dietaryWaterType,
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)! // DOB permission
        ]

        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    print("HealthKit authorization granted.")
                    // Fetch all data
                    self.fetchDateOfBirth()
                    self.fetchLatestHeight()
                    self.fetchLatestWeight()
                    self.fetchTodaysSteps()
                    self.fetchRestingHeartRate()
                    self.fetchHRV()
                    self.fetchTodaysSleep()
                    self.fetchTodaysWater()
                    // fetch detailed samples as well
                    self.fetchTodaysWaterSamples()
                } else {
                    print("HealthKit authorization denied.")
                }
                completion()
            }
        }
    }
    
    // --- NEW: A function to fetch the user's date of birth ---
    func fetchDateOfBirth() {
        do {
            let birthDateComponents = try healthStore.dateOfBirthComponents()
            self.dateOfBirth = birthDateComponents.date
        } catch {
            print("Error fetching date of birth: \(error.localizedDescription)")
        }
    }
    
    // (All other fetch functions are correct and unchanged)
    func fetchLatestHeight() { guard let heightType = HKSampleType.quantityType(forIdentifier: .height) else { return }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: heightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            DispatchQueue.main.async {
                self.latestHeight = sample.quantity.doubleValue(for: .meterUnit(with: .centi))
            }
        }
        healthStore.execute(query) }
    func fetchLatestWeight() {         guard let weightType = HKSampleType.quantityType(forIdentifier: .bodyMass) else { return }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let sample = samples?.first as? HKQuantitySample else { return }
            DispatchQueue.main.async {
                self.latestWeight = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
            }
        }
        healthStore.execute(query)
 }
    func fetchTodaysSteps() { let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let predicate = createTodayPredicate()
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async { self.dailySteps = 0 }
                return
            }
            DispatchQueue.main.async {
                self.dailySteps = sum.doubleValue(for: .count())
            }
        }
        healthStore.execute(query) }
    func fetchTodaysWater() { let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        let predicate = createTodayPredicate()
        
        let query = HKStatisticsQuery(quantityType: waterType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else {
                DispatchQueue.main.async { self.dailyWaterIntake = 0 }
                return
            }
            DispatchQueue.main.async {
                // Store daily water intake in milliliters (ml) to be consistent across the app
                let liters = sum.doubleValue(for: .liter())
                let milliliters = liters * 1000.0
                self.dailyWaterIntake = milliliters
                // Also refresh detailed samples list
                self.fetchTodaysWaterSamples()
            }
        }
        healthStore.execute(query) }
    func fetchRestingHeartRate() {let hrType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let latestSample = samples?.first as? HKQuantitySample else { return }
            DispatchQueue.main.async {
                self.restingHeartRate = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            }
        }
        healthStore.execute(query)}
    func fetchHRV() { let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let latestSample = samples?.first as? HKQuantitySample else { return }
            DispatchQueue.main.async {
                self.hrv = latestSample.quantity.doubleValue(for: .secondUnit(with: .milli))
            }
        }
        healthStore.execute(query)}
    func fetchTodaysSleep() {let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        let predicate = HKQuery.predicateForSamples(withStart: Calendar.current.date(byAdding: .hour, value: -24, to: Date()), end: Date(), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let sleepSamples = samples as? [HKCategorySample] else { return }
            
            let totalSeconds = sleepSamples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
            
            let formatter = DateComponentsFormatter()
            formatter.unitsStyle = .abbreviated
            formatter.allowedUnits = [.hour, .minute]
            
            DispatchQueue.main.async {
                self.sleepDurationString = formatter.string(from: totalSeconds) ?? "--"
            }
        }
        healthStore.execute(query)}
    private func createTodayPredicate() -> NSPredicate { let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = Date()
        return HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate) }

    // --- NEW: Log a water intake sample (amountML) into HealthKit ---
    func logWater(amountML: Double, completion: @escaping (Error?) -> Void) {
        let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        let liters = amountML / 1000.0
        let quantity = HKQuantity(unit: .liter(), doubleValue: liters)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: Date(), end: Date())
        healthStore.save(sample) { success, error in
            DispatchQueue.main.async {
                if success {
                    // Refresh today's water total and samples
                    self.fetchTodaysWater()
                    completion(nil)
                } else {
                    completion(error)
                }
            }
        }
    }

    // --- NEW: Fetch today's water samples (detailed entries) ---
    func fetchTodaysWaterSamples() {
        let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        let predicate = createTodayPredicate()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: waterType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let samples = samples as? [HKQuantitySample] else {
                DispatchQueue.main.async { self.waterLogEntries = [] }
                return
            }
            let entries = samples.map { sample in
                return WaterLogEntry(amountML: sample.quantity.doubleValue(for: .liter()) * 1000.0, date: sample.startDate)
            }
            DispatchQueue.main.async {
                self.waterLogEntries = entries
            }
        }
        healthStore.execute(query)
    }

    // --- NEW: Delete a specific water entry by matching date and amount ---
    func deleteWaterEntry(_ entry: WaterLogEntry, completion: @escaping (Error?) -> Void) {
        let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)!
        // Narrow window around the sample date to find the exact sample
        let predicate = HKQuery.predicateForSamples(withStart: entry.date.addingTimeInterval(-2), end: entry.date.addingTimeInterval(2), options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        let query = HKSampleQuery(sampleType: waterType, predicate: predicate, limit: 10, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let samples = samples as? [HKQuantitySample] else {
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // Try to find a close match by amount (within 1 ml)
            if let match = samples.first(where: { abs($0.quantity.doubleValue(for: .liter()) * 1000.0 - entry.amountML) < 1.0 }) {
                self.healthStore.delete(match) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            // Refresh totals and list
                            self.fetchTodaysWater()
                            self.fetchTodaysWaterSamples()
                            completion(nil)
                        } else {
                            completion(error)
                        }
                    }
                }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }

        healthStore.execute(query)
    }
}
