import SwiftUI
import FirebaseAuth
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    @EnvironmentObject var appState: AppState
    
    @State private var isShowingEditProfile = false
    
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("reminderTime") private var reminderTime: Date = {
        var components = DateComponents(); components.hour = 8; components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()

    var body: some View {
        NavigationView {
            ZStack {
                Theme.backgroundColor.edgesIgnoringSafeArea(.all)
                
                Form {
                    // --- Account Section ---
                    Section(header: Text("Account").foregroundColor(Theme.secondaryTextColor)) {
                        Button(action: { isShowingEditProfile = true }) {
                            HStack {
                                Label("Edit Profile", systemImage: "person.fill")
                                Spacer()
                                Image(systemName: "chevron.right").foregroundColor(.gray)
                            }
                        }
                        .foregroundColor(Theme.textColor)
                    }
                    .listRowBackground(Theme.secondaryBackgroundColor)
                    
                    // --- Notifications Section ---
                    Section(header: Text("Notifications").foregroundColor(Theme.secondaryTextColor)) {
                        Toggle(isOn: $notificationsEnabled) {
                            Label("Daily Reminders", systemImage: "bell.fill")
                        }
                        .tint(Theme.accentColor)
                        
                        if notificationsEnabled {
                            DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        }
                    }
                    .listRowBackground(Theme.secondaryBackgroundColor)
                    
                    // --- Health Data Section ---
                    Section(header: Text("Health Data").foregroundColor(Theme.secondaryTextColor)) {
                        Button(action: openAppSettings) {
                            HStack {
                                Label("Manage Health Permissions", systemImage: "heart.text.square.fill")
                                Spacer()
                                Image(systemName: "arrow.up.right.square").foregroundColor(.gray)
                            }
                        }
                        .foregroundColor(Theme.textColor)
                    }
                    .listRowBackground(Theme.secondaryBackgroundColor)
                    
                    // --- NEW: Support & Feedback Section ---
                    Section(header: Text("Support & Feedback").foregroundColor(Theme.secondaryTextColor)) {
                        Button(action: contactSupport) {
                            Label("Contact Support", systemImage: "envelope.fill")
                        }
                        Button(action: rateApp) {
                            Label("Rate on App Store", systemImage: "star.fill")
                        }
                    }
                    .foregroundColor(Theme.textColor)
                    .listRowBackground(Theme.secondaryBackgroundColor)
                    
                    // --- NEW: Legal Section ---
                    Section(header: Text("Legal").foregroundColor(Theme.secondaryTextColor)) {
                        // These will open web links. You will need to replace the placeholder URLs.
                        Link(destination: URL(string: "https://msuhail2007.github.io/movementum-policy/privacy-policy.html")!) {
                            Label("Terms of Service", systemImage: "doc.text.fill")
                        }
                        Link(destination: URL(string: "https://msuhail2007.github.io/movementum-policy/privacy-policy.html")!) {
                            Label("Privacy Policy", systemImage: "hand.raised.fill")
                        }
                    }
                    .foregroundColor(Theme.textColor)
                    .listRowBackground(Theme.secondaryBackgroundColor)
                    
                    // --- Actions Section ---
                    Section {
                        Button(action: logOut) {
                            Text("Log Out").foregroundColor(.red).frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                    .listRowBackground(Theme.secondaryBackgroundColor)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text("Settings").bold().foregroundColor(Theme.textColor) }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.foregroundColor(Theme.accentColor) }
            }
            .sheet(isPresented: $isShowingEditProfile) {
                if let profile = diaryViewModel.userProfile {
                    EditProfileView(profile: profile).environmentObject(diaryViewModel)
                }
            }
            .onAppear(perform: checkNotificationStatus)
            .onChange(of: notificationsEnabled, handleNotificationToggleChange)
            .onChange(of: reminderTime, handleReminderTimeChange)
        }
    }
    
    // --- NEW: Functions for the new sections ---
    private func contactSupport() {
        // This will create an email draft. Replace with your support email.
        let email = "mohamedsuhail069@gmail.com"
        if let url = URL(string: "mailto:\(email)") {
            openURL(url)
        }
    }
    
    private func rateApp() {
        // Replace "123456789" with your app's actual ID from the App Store.
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id123456789?action=write-review") {
            openURL(url)
        }
    }
    
    // --- NEW: This function opens the app's settings ---
    private func openAppSettings() {
        // This special URL string takes the user directly to your app's settings page
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
    
    private func handleNotificationToggleChange() {
        if notificationsEnabled {
            requestNotificationPermission()
        } else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }
    
    private func handleReminderTimeChange() {
        if notificationsEnabled {
            scheduleDailyReminder()
        }
    }
    
    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.notificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.notificationsEnabled = granted
                if granted {
                    self.scheduleDailyReminder()
                }
            }
        }
    }
    
    private func scheduleDailyReminder() {
        let content = UNMutableNotificationContent()
        let userName = diaryViewModel.userProfile?.name ?? "User"
        content.title = "Good Morning, \(userName)!"
        content.body = "It's a new day to crush your goals. Don't forget to log your breakfast!"
        content.sound = .default

        let dateComponents = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyMorningReminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            } else {
                print("Daily reminder successfully scheduled.")
            }
        }
    }
    
    private func logOut() {
        do {
            try Auth.auth().signOut()
            appState.isLoggedIn = false
            dismiss()
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.light)
        .environmentObject(DiaryViewModel(isForPreview: true))
        .environmentObject(AppState())
}

