import SwiftUI
import FirebaseAuth
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    @EnvironmentObject var appState: AppState

    @State private var isShowingEditProfile = false

    // State for delete account alerts
    @State private var isShowingDeleteAlert = false
    @State private var isShowingErrorAlert = false
    @State private var deletionErrorMessage = ""

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
                    // --- Appearance Section ---
                    Section(header: Text("Appearance").foregroundColor(Theme.secondaryTextColor)) {
                        Picker("Theme", selection: $appState.appearanceMode) {
                            Text("System").tag("system")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .glassEffect()
                        .pickerStyle(.segmented)
                        .padding(.vertical, 6)
                        
                    }
                    .listRowBackground(Theme.secondaryBackgroundColor)

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

                    // --- Support & Feedback Section ---
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

                    // --- Legal Section ---
                    Section(header: Text("Legal").foregroundColor(Theme.secondaryTextColor)) {
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

                        // --- NEW DELETE BUTTON ---
                        Button(action: { isShowingDeleteAlert = true }) {
                            Text("Delete Account")
                                .foregroundColor(Theme.danger)
                                .frame(maxWidth: .infinity, alignment: .center)
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
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.foregroundColor(Theme.accent) }
            }
            .sheet(isPresented: $isShowingEditProfile) {
                if let profile = diaryViewModel.userProfile {
                    EditProfileView(profile: profile).environmentObject(diaryViewModel)
                }
            }
            // --- NEW ALERTS FOR DELETE ACCOUNT ---
            .alert("Delete Account?", isPresented: $isShowingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action is permanent and cannot be undone.")
            }
            .alert("Error", isPresented: $isShowingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(deletionErrorMessage)
            }
            // --- END OF NEW ALERTS ---
            .onAppear(perform: checkNotificationStatus)
            .onChange(of: notificationsEnabled, handleNotificationToggleChange)
            .onChange(of: reminderTime, handleReminderTimeChange)
        }
    }

    // --- Functions for Support & Feedback ---
    private func contactSupport() {
        let email = "mithulpranavn@gmail.com"
        if let url = URL(string: "mailto:\(email)") {
            openURL(url)
        }
    }

    private func rateApp() {
        // TODO: Replace "123456789" with your app's actual ID
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id123456789?action=write-review") {
            openURL(url)
        }
    }

    // --- Function for Health Data ---
    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    // --- Notification Functions ---
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

    // --- Account Action Functions ---
    private func logOut() {
        do {
            try Auth.auth().signOut()
            appState.isLoggedIn = false
            dismiss()
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }

    // --- NEW DELETE ACCOUNT FUNCTION ---
    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else {
            self.deletionErrorMessage = "No user is currently signed in."
            self.isShowingErrorAlert = true
            return
        }

        // Save the UID to delete database records
        let userID = user.uid

        user.delete { error in
            DispatchQueue.main.async {
                if let error = error {
                    // Handle common "requires recent login" error
                    if let authError = error as NSError?, authError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                        self.deletionErrorMessage = "This is a sensitive operation. Please log out and sign in again before deleting your account."
                    } else {
                        // Handle other errors
                        self.deletionErrorMessage = "Error deleting account: \(error.localizedDescription)"
                    }
                    self.isShowingErrorAlert = true
                } else {
                    // --- SUCCESS ---

                    // TODO: Call your ViewModel to delete user data from Firestore/Database
                    // Example: diaryViewModel.deleteUserData(for: userID)

                    // Set app state to logged out
                    self.appState.isLoggedIn = false
                    self.dismiss() // Dismiss the settings view
                }
            }
        }
    }
}

// --- Preview ---
#Preview {
    SettingsView()
        .environmentObject(DiaryViewModel(isForPreview: true))
        .environmentObject(AppState())
}
