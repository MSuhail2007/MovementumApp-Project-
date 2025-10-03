import SwiftUI
import Combine

// --- Data Models for the Onboarding Flow ---
enum GoalType: String, CaseIterable, Identifiable {
    case weightLoss = "Weight Loss"
    case strengthGain = "Strength Gain"
    case endurance = "Endurance"
    case mobility = "Mobility"
    case generalFitness = "General Fitness"
    var id: String { self.rawValue }
}

enum Equipment: String, CaseIterable, Identifiable {
    case bodyweight = "Bodyweight"
    case dumbbells = "Dumbbells"
    case fullGym = "Full Gym"
    var id: String { self.rawValue }
}

enum DietaryPreference: String, CaseIterable, Identifiable {
    case anything = "Anything"
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    var id: String { self.rawValue }
}

// A class to hold all the user's selections during onboarding
class OnboardingData: ObservableObject {
    @Published var goalType: GoalType = .generalFitness
    @Published var customGoal: String = ""
    @Published var workoutDaysPerWeek: Int = 3
    @Published var equipment: Equipment = .bodyweight
    @Published var dietaryPreference: DietaryPreference = .anything
    @Published var workoutPlanSummary: String?
    @Published var dietPlanSummary: String?
}

// The main view that controls the multi-step onboarding flow
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    
    // The current step in the onboarding process
    @State private var currentStep = 0
    // The data collected from the user
    @StateObject private var onboardingData = OnboardingData()
    
    // The user's profile data from the previous step
    let profile: UserProfile

    var body: some View {
        ZStack {
            Theme.backgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack {
                // --- The progress bar is now out of 4 steps ---
                ProgressView(value: Double(currentStep) / 4.0)
                    .tint(Theme.accentColor)
                    .padding()
                
                // --- The flow is now shorter ---
                switch currentStep {
                case 0:
                    GoalTypeStepView(onboardingData: onboardingData)
                case 1:
                    LifestyleStepView(onboardingData: onboardingData)
                case 2:
                    AIPlanGenerationView(currentStep: $currentStep, onboardingData: onboardingData)
                case 3:
                    PlanReviewStepView(onboardingData: onboardingData)
                default:
                    Text("Finished")
                }
                
                Spacer()
                
                // --- Navigation Buttons ---
                HStack {
                    if currentStep > 0 && currentStep < 3 {
                        Button("Back") { withAnimation { currentStep -= 1 } }
                            .foregroundColor(Theme.secondaryTextColor)
                    }
                    Spacer()
                    // The "Next" button is disabled during AI generation
                    if currentStep < 2 {
                        Button("Next") { withAnimation { currentStep += 1 } }
                            .buttonStyle(PrimaryButtonStyle())
                    } else if currentStep == 3 {
                        Button("Save & Let's Go!") { finishOnboarding() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .accentColor(Theme.accentColor)
    }
    
    private func finishOnboarding() {
        // Create a mutable copy of the profile data passed from the previous screen
        var finalProfile = self.profile
        
        // Update it with the user's final selections
        finalProfile.goal = onboardingData.goalType.rawValue
        finalProfile.workoutDaysPerWeek = onboardingData.workoutDaysPerWeek
        
        // Save the complete, final profile to the database
        diaryViewModel.save(userProfile: finalProfile)
        
        // Log the user in and unlock the dashboard
        appState.isLoggedIn = true
        print("Onboarding complete. User is logged in.")
    }
}

// --- Views for Each Step of the Onboarding Process ---

struct GoalTypeStepView: View {
    @ObservedObject var onboardingData: OnboardingData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("What's Your Primary Goal?")
                .font(.largeTitle).bold().foregroundColor(Theme.textColor)
            
            ForEach(GoalType.allCases) { goal in
                SelectionCard(title: goal.rawValue, isSelected: onboardingData.goalType == goal) {
                    onboardingData.goalType = goal
                }
            }
            // A simple text field for a custom goal
            TextField("Or enter a custom goal (e.g., Run a 5K)", text: $onboardingData.customGoal)
                .modifier(ThemedTextFieldStyle())
            Spacer()
        }
        .padding()
    }
}

struct LifestyleStepView: View {
    @ObservedObject var onboardingData: OnboardingData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("Your Lifestyle & Preferences")
                .font(.largeTitle).bold().foregroundColor(Theme.textColor)
            
            // Workout Days
            VStack(alignment: .leading) {
                Text("How many days per week can you work out?").foregroundColor(Theme.textColor)
                Picker("Workout Days", selection: $onboardingData.workoutDaysPerWeek) {
                    ForEach(1...7, id: \.self) { day in Text("\(day) days").tag(day) }
                }.pickerStyle(.segmented)
            }
            
            // Equipment
            VStack(alignment: .leading) {
                Text("What equipment do you have access to?").foregroundColor(Theme.textColor)
                Picker("Equipment", selection: $onboardingData.equipment) {
                    ForEach(Equipment.allCases) { item in Text(item.rawValue).tag(item) }
                }.pickerStyle(.segmented)
            }
            
            // Dietary Preference
            VStack(alignment: .leading) {
                Text("Do you have any dietary preferences?").foregroundColor(Theme.textColor)
                Picker("Diet", selection: $onboardingData.dietaryPreference) {
                    ForEach(DietaryPreference.allCases) { item in Text(item.rawValue).tag(item) }
                }.pickerStyle(.segmented)
            }
            Spacer()
        }
        .padding()
    }
}

struct AIPlanGenerationView: View {
    @Binding var currentStep: Int
    @ObservedObject var onboardingData: OnboardingData
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView().progressViewStyle(CircularProgressViewStyle()).scaleEffect(2)
            Text("Generating Your Plan...").font(.largeTitle).bold().foregroundColor(Theme.textColor)
            Text("Our AI is creating a personalized plan...").multilineTextAlignment(.center).foregroundColor(.gray)
            Spacer()
        }
        .padding()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                onboardingData.workoutPlanSummary = "Your AI plan includes \(onboardingData.workoutDaysPerWeek) workouts..."
                onboardingData.dietPlanSummary = "Your AI diet plan is for a \(onboardingData.dietaryPreference.rawValue) diet..."
                withAnimation { currentStep += 1 }
            }
        }
    }
}

struct PlanReviewStepView: View {
    @ObservedObject var onboardingData: OnboardingData
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Your AI-Generated Plan is Ready!").font(.largeTitle).bold().foregroundColor(Theme.textColor)
            if let summary = onboardingData.workoutPlanSummary {
                InfoCardView(iconName: "figure.walk.circle.fill", iconColor: .blue, title: "Workout Plan", text: summary)
            }
            if let summary = onboardingData.dietPlanSummary {
                InfoCardView(iconName: "fork.knife.circle.fill", iconColor: .orange, title: "Diet Plan", text: summary)
            }
            Spacer()
        }.padding()
    }
}

// --- Reusable UI Components ---
struct SelectionCard: View {
    let title: String, isSelected: Bool, action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title).font(.headline).bold()
                Spacer()
                if isSelected { Image(systemName: "checkmark.circle.fill").font(.title) }
            }
            .foregroundColor(isSelected ? .white : Theme.textColor)
            .padding()
            .background(isSelected ? AnyShapeStyle(Theme.accentColor.gradient) : AnyShapeStyle(Theme.secondaryBackgroundColor))
            .cornerRadius(15)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline).bold().foregroundColor(.white).padding().frame(maxWidth: .infinity)
            .background(Theme.accentColor.gradient).cornerRadius(15)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// --- THIS IS THE FIX: The duplicate ThemedTextFieldStyle has been removed ---
// This file will now use the shared definition from ProfileSetupView.swift

struct InfoCardView: View {
    let iconName: String, iconColor: Color, title: String, text: String
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: iconName).font(.title).foregroundColor(iconColor).frame(width: 30)
            VStack(alignment: .leading) {
                Text(title).font(.headline).bold().foregroundColor(Theme.textColor)
                Text(text).font(.subheadline).foregroundColor(Theme.secondaryTextColor)
            }
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading).background(Theme.secondaryBackgroundColor).cornerRadius(15)
    }
}


#Preview {
    let profile = UserProfile(name: "Suhail", dob: Date(), height: 175, weight: 70, goal: "Not Set", workoutDaysPerWeek: 3)
    OnboardingView(profile: profile)
        .preferredColorScheme(.light)
        .environmentObject(AppState())
        .environmentObject(DiaryViewModel(isForPreview: true))
}

