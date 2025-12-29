import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct MovementumApp: App {
    @StateObject private var diaryViewModel = DiaryViewModel()
    @StateObject private var appState = AppState()
    // --- THIS IS THE FIX: Create one single, shared "Health Brain" here ---
    @StateObject private var healthManager = HealthStoreManager()

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
            // --- AND provide it to all the views in your app ---
            .environmentObject(healthManager)
            .onAppear {
                diaryViewModel.listenForAuthChanges(appState: appState)
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .preferredColorScheme(appState.preferredColorScheme)
        }
    }
}
