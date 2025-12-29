import SwiftUI

struct ContentView: View {
    var body: some View {
        // --- THIS IS THE FIX ---
        // We are now using the standard, reliable iOS TabView.
        // This design is clean, familiar, and works perfectly.
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            WorkoutView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.walk.circle.fill")
                }

            DiaryView()
                .tabItem {
                    Label("Diary", systemImage: "book.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        // The accent color will correctly tint the selected tab icon and text.
        .accentColor(Theme.accentColor)
    }
}


#Preview {
    let previewViewModel = DiaryViewModel(isForPreview: true)
    
    return ContentView()
        .preferredColorScheme(.light)
        .environmentObject(previewViewModel)
}
