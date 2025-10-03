import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct FitnessApp: App {
    @StateObject private var diaryViewModel = DiaryViewModel()
    @StateObject private var appState = AppState()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isLoggedIn {
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .environmentObject(diaryViewModel)
            .environmentObject(appState)
            .onAppear {
                // --- THIS IS THE FIX ---
                // We now pass the appState to the listener function.
                diaryViewModel.listenForAuthChanges(appState: appState)
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}

