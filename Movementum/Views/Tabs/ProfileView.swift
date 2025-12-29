import SwiftUI
import FirebaseAuth

// --- KEEPING YOUR EXISTING MODIFIERS ---
struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = 15
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Theme.pillBorder, lineWidth: 1)
            )
    }
}

extension View {
    func glassBackgroundStyle(cornerRadius: CGFloat = 15) -> some View {
        self.modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}

// --- NEW: A Row View specifically for the Screenshot's List Style ---
struct ProfileMenuRow<Destination: View>: View {
    let icon: String
    let title: String
    let destination: Destination
    var showChevron: Bool = true
    var isDestructive: Bool = false

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                // Icon Box
                ZStack {
                    if isDestructive {
                        Circle().fill(Theme.accent.opacity(0.15))
                            .frame(width: 40, height: 40)
                    } else {
                        // Standard Icon background (glassy or plain)
                        Circle().fill(Theme.surface.opacity(0.05))
                            .frame(width: 40, height: 40)
                    }
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(isDestructive ? Theme.accent : Theme.textColor)
                }
                
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isDestructive ? Theme.accent : Theme.textColor)
                
                Spacer()
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.secondaryTextColor)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

// Overload for Button actions (like Logout)
struct ProfileMenuButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    var isDestructive: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(isDestructive ? Theme.accent.opacity(0.15) : Theme.surface.opacity(0.05))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .foregroundColor(isDestructive ? Theme.accent : Theme.textColor)
                }
                
                Text(title)
                    .fontWeight(.medium)
                    .foregroundColor(isDestructive ? Theme.accent : Theme.textColor)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.secondaryTextColor)
            }
            .padding(.vertical, 8)
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    @EnvironmentObject var appState: AppState

    // Persisted user goals
    @AppStorage("dailyStepsGoal") private var dailyStepsGoal: Int = 10000
    @AppStorage("waterIntakeGoal") private var waterIntakeGoal: Int = 2500

    @State private var isShowingSettingsView = false
    
    // To match screenshot back button behavior (presentationMode)
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            ZStack {
                // 1. Background
                Theme.backgroundColor.edgesIgnoringSafeArea(.all)

                if let profile = diaryViewModel.userProfile {
                    ScrollView {
                        VStack(spacing: 24) {
                            
                            // 2. Custom Header (Matches Screenshot Top Bar)
                            HStack {
                                Button(action: {}) {
                                    
                                }
                                Spacer()
                                
                                Button(action: {
                                    // Share action
                                }) {
                                    
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 10)

                            // 3. Profile Card (Matches Screenshot User Card)
                            HStack(spacing: 15) {
                                // Avatar
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: [Theme.accent.opacity(0.3), Theme.accentDark.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    
                                    Text(getInitials(name: profile.name))
                                        .font(.title)
                                        .bold()
                                        .foregroundColor(Theme.textColor)
                                }
                                .frame(width: 60, height: 60)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.name)
                                        .font(.headline)
                                        .bold()
                                        .foregroundColor(Theme.textColor)
                                    
                                    // Using a dummy email or goal as subtitle to match screenshot
                                    Text(profile.goal) // e.g. "Weight Loss"
                                        .font(.subheadline)
                                        .foregroundColor(Theme.secondaryTextColor)
                                }
                                
                                Spacer()
                                
                                // Edit Button (Green/Accent Pencil)
                                Button(action: {
                                    // Navigate to edit profile
                                }) {
                                    
                                }
                            }
                            .padding(16)
                            
                            .padding(.horizontal)

                            // 4. Menu Section 1: Goals & Settings
                            // I mapped your existing features to the screenshot's list layout
                            VStack(spacing: 0) {
                                // Row 1: Account Settings
                                ProfileMenuButton(icon: "person", title: "Account Settings") {
                                    isShowingSettingsView = true
                                }
                                
                                Divider().background(Theme.pillBorder).padding(.leading, 56)

                                // Row 2: Payment (Replaced with Steps Goal for functionality)
                                ProfileMenuRow(icon: "figure.walk", title: "Daily Steps Goal", destination: EditStepsView())
                                
                                Divider().background(Theme.pillBorder).padding(.leading, 56)
                                
                                // Row 3: Water (Mapped from code)
                                ProfileMenuRow(icon: "drop.fill", title: "Water Settings", destination: EditWaterView())
                            }
                            .padding(16)
                            .glassBackgroundStyle(cornerRadius: 50)
                            .padding(.horizontal)

                            // 5. Menu Section 2: Care & History
                            VStack(spacing: 0) {
                                // Row: Primary Goal
                                ProfileMenuRow(icon: "target", title: "Primary Goal", destination: PrimaryGoalView().environmentObject(diaryViewModel))
                                
                                Divider().background(Theme.pillBorder).padding(.leading, 56)

                                // Row: History / Analytics
                                // Since "Medical History" isn't in your app, we use Analytics
                                ProfileMenuRow(icon: "chart.bar.doc.horizontal", title: "Analytics & History", destination: Text("Analytics View Here")) // Replace with your Analytics View
                                
                                Divider().background(Theme.pillBorder).padding(.leading, 56)

                                // Row: Help
                                ProfileMenuButton(icon: "info.circle", title: "Helps & Supports") {
                                    // Action
                                }
                            }
                            .padding(16)
                            .glassBackgroundStyle(cornerRadius: 50)
                            .padding(.horizontal)

                            // 6. Logout Section
                            VStack {
                                ProfileMenuButton(icon: "rectangle.portrait.and.arrow.right", title: "Logout", action: {
                                    try? Auth.auth().signOut()
                                    appState.isLoggedIn = false
                                }, isDestructive: true)
                            }
                            .padding(16)
                            .glassBackgroundStyle(cornerRadius: 50)
                            .padding(.horizontal)
                            
                            Spacer().frame(height: 100) // Bottom padding for TabBar
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationBarHidden(true) // Hide default nav bar to use custom one
            .sheet(isPresented: $isShowingSettingsView) {
                SettingsView()
            }
        }
    }
    
    // Helper to get initials
    func getInitials(name: String) -> String {
        let components = name.components(separatedBy: " ").filter { !$0.isEmpty }
        return components.compactMap { $0.first }.map(String.init).joined()
    }
}

// --- PREVIEW ---
#Preview {
    let previewViewModel = DiaryViewModel(isForPreview: true)
    return ProfileView()
        .preferredColorScheme(.dark)
        .environmentObject(previewViewModel)
        .environmentObject(AppState())
}
