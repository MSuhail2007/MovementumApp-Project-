import SwiftUI
import UserNotifications

struct EditWaterView: View {
    @Environment(\.presentationMode) var presentationMode

    @AppStorage("waterIntakeGoal") private var waterIntakeGoal: Int = 2500
    @AppStorage("waterRemindersEnabled") private var waterRemindersEnabled: Bool = false
    @AppStorage("waterWakeupTime") private var waterWakeupTime: Double = 7 * 3600
    @AppStorage("waterSleepTime") private var waterSleepTime: Double = 23 * 3600
    @AppStorage("waterReminderIntervalHours") private var waterReminderIntervalHours: Int = 2

    @State private var tempGoal: Int = 2500
    @State private var tempRemindersOn: Bool = false
    @State private var tempWakeDate: Date = Date()
    @State private var tempSleepDate: Date = Date()
    @State private var tempIntervalHours: Int = 2

    private let intervalOptions: [Int] = [1,2,3,4,6,8]

    var body: some View {
        ZStack {
            // Background color (optional, matches standard grouped lists)
            Theme.backgroundColor
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 0) {
                
                // --- Top Card: Water Goal ---
                VStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("Water Intake")
                            .font(.headline)
                            .foregroundColor(Theme.textColor)
                        Text("Set your daily goal")
                            .font(.subheadline)
                            .foregroundColor(Theme.secondaryTextColor)
                    }
                    .padding(.top, 10)

                    // Goal Number
                    Text("\(tempGoal.formatted(.number)) ml")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textColor)

                    // Controls Row (+ / -)
                    HStack {
                        Button(action: {
                            let v = max(0, tempGoal - 100)
                            tempGoal = v
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }) {
                            Image(systemName: "minus")
                                .font(.title2)
                                .foregroundColor(Theme.textColor)
                                .frame(width: 44, height: 44)
                                .background(Circle().stroke(Theme.pillBorder.opacity(0.3), lineWidth: 1))
                        }

                        Spacer()
                        
                        // We repeat the number here or leave it empty?
                        // The sketch has the number in the middle, but we already showed it big above.
                        // Let's show the number again smaller or just keep the buttons spaced out like the sketch.
                        // Sketch implies:  ( - )   3,100 ml   ( + )
                        
                        Text("\(tempGoal.formatted(.number)) ml")
                             .font(.body)
                             .foregroundColor(Theme.secondaryTextColor)

                        Spacer()

                        Button(action: {
                            let v = tempGoal + 100
                            tempGoal = v
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                                
                                
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(Theme.textColor)
                                .frame(width: 44, height: 44)
                                .background(Circle().stroke(Theme.pillBorder.opacity(0.3), lineWidth: 1))
                                
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 10)
                }
                .padding(20)
                .background(Theme.secondaryBackgroundColor)
                .glassEffect()
                .cornerRadius(120)
                .shadow(color: Theme.softShadow, radius: 5, x: 0, y: 2)
                
                .padding(.horizontal)
                .padding(.top, 20)
                
                // --- Reminders Section ---
                VStack(spacing: 16) {
                    
                    // Toggle Row
                    HStack {
                        Image(systemName: "bell")
                        Text("Reminder")
                            .font(.body)
                        Spacer()
                        Toggle("", isOn: $tempRemindersOn)
                            .labelsHidden()
                            .onChange(of: tempRemindersOn) { new in
                                waterRemindersEnabled = new
                            }
                    }
                    .padding()
                    .background(Theme.secondaryBackgroundColor)
                    .glassEffect()
                    .cornerRadius(30) // Pill shape
                    .shadow(color: Theme.softShadow, radius: 5, x: 0, y: 2)

                    if tempRemindersOn {
                        // Time Pickers Row (Side by Side)
                        HStack(spacing: 12) {
                            // Wake Up
                            HStack {
                                Image(systemName: "sunrise.fill")
                                    .foregroundColor(Theme.accent)
                                DatePicker("", selection: $tempWakeDate, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Theme.secondaryBackgroundColor)
                            .glassEffect()
                            .cornerRadius(30)
                            .shadow(color: Theme.softShadow, radius: 2, x: 0, y: 1)

                            // Bedtime
                            HStack {
                                Image(systemName: "moon.fill")
                                    .foregroundColor(Theme.accent)
                                DatePicker("", selection: $tempSleepDate, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Theme.secondaryBackgroundColor)
                            .glassEffect()
                            .cornerRadius(30)
                            .shadow(color: Theme.softShadow, radius: 2, x: 0, y: 1)
                        }

                        // Interval Row
                        HStack {
                            Text("Every")
                                .foregroundColor(Theme.secondaryTextColor)
                            
                            Picker("Interval", selection: $tempIntervalHours) {
                                ForEach(intervalOptions, id: \.self) { val in
                                    Text("\(val)h").tag(val)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            Spacer()
                            
                            Text("\(reminderCount()) Remind")
                                .font(.caption)
                                .foregroundColor(Theme.secondaryTextColor)
                        }
                        .padding(.top, 5)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)

                Spacer()

                // --- Save Button ---
                Button(action: saveAndSchedule) {
                    Text("Save & Close")
                        .font(.headline)
                        .foregroundColor(Theme.textColor)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .glassEffect()
                        .background(Theme.accent)
                        .cornerRadius(30) // Pill shape
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
        }
        .onAppear(perform: loadCurrentValues)
        .navigationBarHidden(true)
    }

    // --- LOGIC FUNCTIONS (Unchanged) ---

    private func loadCurrentValues() {
        tempGoal = waterIntakeGoal
        tempRemindersOn = waterRemindersEnabled
        tempWakeDate = dateFromSeconds(waterWakeupTime)
        tempSleepDate = dateFromSeconds(waterSleepTime)
        tempIntervalHours = waterReminderIntervalHours
    }

    private func saveAndSchedule() {
        waterIntakeGoal = max(0, tempGoal)
        waterRemindersEnabled = tempRemindersOn
        waterWakeupTime = secondsFromDate(tempWakeDate)
        waterSleepTime = secondsFromDate(tempSleepDate)
        waterReminderIntervalHours = tempIntervalHours

        if tempRemindersOn {
            scheduleWaterNotifications()
        } else {
            removeWaterNotifications()
        }

        presentationMode.wrappedValue.dismiss()
    }

    private func dateFromSeconds(_ seconds: Double) -> Date {
        let calendar = Calendar.current
        // Just for display, we use today's date with the stored hour/min
        let todayStart = calendar.startOfDay(for: Date())
        return todayStart.addingTimeInterval(seconds)
    }

    private func secondsFromDate(_ date: Date) -> Double {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return Double(h * 3600 + m * 60)
    }

    private func scheduleWaterNotifications() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            guard granted else { return }
            self.removeWaterNotifications()

            let wakeSeconds = Int(self.secondsFromDate(self.tempWakeDate))
            var sleepSeconds = Int(self.secondsFromDate(self.tempSleepDate))
            if sleepSeconds <= wakeSeconds {
                sleepSeconds += 24 * 3600
            }

            var current = wakeSeconds
            var identifiers: [String] = []

            while current <= sleepSeconds {
                let hour = (current / 3600) % 24
                let minute = (current % 3600) / 60

                let content = UNMutableNotificationContent()
                content.title = "Hydration Reminder"
                content.body = "Time to drink water."
                content.sound = UNNotificationSound.default

                var dateComponents = DateComponents()
                dateComponents.hour = hour
                dateComponents.minute = minute

                let identifier = "waterReminder_\(hour)_\(minute)"
                identifiers.append(identifier)

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                center.add(request)
            
                current += self.tempIntervalHours * 3600
            }
        }
    }

    private func removeWaterNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let idsToRemove = requests.map { $0.identifier }.filter { $0.starts(with: "waterReminder_") }
            if !idsToRemove.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: idsToRemove)
            }
        }
    }

    private func reminderCount() -> Int {
        let wakeSeconds = Int(secondsFromDate(tempWakeDate))
        var sleepSeconds = Int(secondsFromDate(tempSleepDate))
        if sleepSeconds <= wakeSeconds { sleepSeconds += 24 * 3600 }
        let totalSeconds = sleepSeconds - wakeSeconds
        // Avoid division by zero
        let interval = max(1, tempIntervalHours)
        let count = (totalSeconds / (interval * 3600)) + 1
        return count
    }
}

#Preview {
    EditWaterView()
        .preferredColorScheme(.dark)
}
