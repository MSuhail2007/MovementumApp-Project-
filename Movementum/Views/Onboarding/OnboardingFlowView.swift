import SwiftUI
import HealthKit
import Combine

// --- A "brain" to hold all the data collected during onboarding ---
class OnboardingViewModel: ObservableObject {
    @Published var primaryGoal: GoalType = .bodyRecomposition
    @Published var weightLossTarget: String = "1-5 kg"
    @Published var strengthFocus: String = "Build Muscle Mass"
    @Published var workoutDaysPerWeek: Int = 3
    @Published var dailyStepsTarget: Int = 10000
    // New onboarding fields
    @Published var difficultyLevel: String = "Beginner"
    @Published var workoutMode: String = "Home" // options: Home, Gym, Dumbbell Only
}

// The main view that controls the entire multi-step onboarding flow
struct OnboardingFlowView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    @EnvironmentObject var healthManager: HealthStoreManager
    
    let userName: String
    let dob: Date
    
    @State private var currentStep = 0
    @StateObject private var viewModel = OnboardingViewModel()
    
    var totalSteps: Int { 9 }
    
    var body: some View {
        ZStack {
            Theme.backgroundColor.edgesIgnoringSafeArea(.all)
            
            // --- The Step Views (Centered Content) ---
            VStack {
                ProgressView(value: Double(currentStep + 1) / Double(totalSteps))
                    .progressViewStyle(.linear)
                    .tint(Theme.accent)
                    .padding(.horizontal)

                Spacer()

                Group {
                    if currentStep == 0 {
                        GoalStepView(userName: userName, viewModel: viewModel)
                    } else if currentStep == 1 {
                        TargetStepView(viewModel: viewModel)
                    } else if currentStep == 2 {
                        DifficultyStepView(viewModel: viewModel)
                    } else if currentStep == 3 {
                        ModeStepView(viewModel: viewModel)
                    } else if currentStep == 4 {
                        FrequencyStepView(viewModel: viewModel)
                    } else if currentStep == 5 {
                        StepsTargetStepView(viewModel: viewModel)
                    } else if currentStep == 6 {
                        HealthKitStepView()
                    } else if currentStep == 7 {
                        LoadingStepView(text: "Your plan is getting ready...")
                    } else if currentStep == 8 {
                        PlanReadyStepView()
                    }
                }
                .transition(.opacity.animation(.easeInOut))
                
                Spacer()
            }
            
            // --- Navigation (Bottom Button) ---
            VStack {
                Spacer()
                
                if currentStep < 6 {
                    OnboardingButton(title: "Continue") {
                        withAnimation { currentStep += 1 }
                    }
                } else if currentStep == 6 {
                    OnboardingButton(title: "Link to Health App") {
                        healthManager.requestAuthorization {
                            withAnimation { currentStep += 1 }
                        }
                    }
                } else if currentStep == 8 {
                    OnboardingButton(title: "Let's Go!") {
                        finishOnboarding()
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                // This is now the ONLY back button.
                if currentStep > 0 && currentStep < 8 {
                    GlassBackButton {
                        withAnimation { currentStep -= 1 }
                    }
                }
            }
        }
        .onChange(of: currentStep) { newValue in
             if newValue == 7 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation { currentStep += 1 }
                }
            }
        }
    }
    
    private func finishOnboarding() {
        let profile = UserProfile(
            name: userName,
            dob: healthManager.dateOfBirth ?? self.dob,
            height: healthManager.latestHeight ?? 0,
            weight: healthManager.latestWeight ?? 0,
            goal: viewModel.primaryGoal.rawValue,
            workoutDaysPerWeek: viewModel.workoutDaysPerWeek,
            dailyStepsTarget: viewModel.dailyStepsTarget,
            difficultyLevel: viewModel.difficultyLevel,
            workoutMode: viewModel.workoutMode
        )
        diaryViewModel.save(userProfile: profile)
        appState.isLoggedIn = true
    }
}


// MARK: - Onboarding Step Views (Full Implementations)

struct GoalStepView: View {
    let userName: String
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Hello, \(userName)")
                .font(.largeTitle).bold()
                .foregroundColor(Theme.textColor)
            
            // --- FIX: Using the improved, more engaging subtitle ---
            Text("Let's build a better you. What's our focus?")
                .font(.headline)
                .foregroundColor(Theme.secondaryTextColor)
                .multilineTextAlignment(.center)
            
            Picker("Primary Goal", selection: $viewModel.primaryGoal) {
                ForEach(GoalType.allCases) { goal in
                    Text(goal.rawValue).tag(goal)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
        }
        .padding()
    }
}

struct TargetStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text(viewModel.primaryGoal == .weightLoss ? "Weight loss target?" : "What's your strength focus?")
                .font(.largeTitle).bold()
                .foregroundColor(Theme.textColor)
                .multilineTextAlignment(.center)
            
            if viewModel.primaryGoal == .weightLoss {
                Picker("Weight Loss", selection: $viewModel.weightLossTarget) {
                    ForEach(["1-5 kg", "5-10 kg", "10-15 kg", "15-20 kg", "20-25 kg", "25-30 kg"], id: \.self) { Text($0) }
                }.pickerStyle(.wheel).labelsHidden()
            } else {
                Picker("Strength Focus", selection: $viewModel.strengthFocus) {
                    ForEach(["Build Muscle Mass", "Increase Max Lifts", "Improve Definition"], id: \.self) { Text($0) }
                }.pickerStyle(.wheel).labelsHidden()
            }
        }
        .padding()
    }
}

struct DifficultyStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let options = ["Beginner", "Intermediate", "Advanced"]
    var body: some View {
        VStack(spacing: 20) {
            Text("Current level?")
                .font(.largeTitle).bold()
                .foregroundColor(Theme.textColor)
            Picker("Difficulty", selection: $viewModel.difficultyLevel) {
                ForEach(options, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
            .padding()
        }
        .padding()
    }
}

struct ModeStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    let options = ["Home", "Gym", "Dumbbell Only"]
    var body: some View {
        VStack(spacing: 20) {
            Text("Work out space?")
                .font(.largeTitle).bold()
                .foregroundColor(Theme.textColor)
            Picker("Mode", selection: $viewModel.workoutMode) {
                ForEach(options, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
            .padding()
        }
        .padding()
    }
}

struct FrequencyStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("How many days per week can you work out?")
                .font(.largeTitle).bold()
                .foregroundColor(Theme.textColor)
                .multilineTextAlignment(.center)
            
            CustomStepper(value: $viewModel.workoutDaysPerWeek, range: 1...7, label: "days")
        }
        .padding()
    }
}

struct StepsTargetStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Daily steps target")
                .font(.largeTitle).bold()
                .foregroundColor(Theme.textColor)
                .multilineTextAlignment(.center)
            
            CustomStepper(value: $viewModel.dailyStepsTarget, range: 1000...30000, step: 500, label: "steps")
        }
        .padding()
    }
}

struct HealthKitStepView: View {
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "link.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.accent)
            
            Text("Link to Apple Health")
                .font(.largeTitle).bold()
                .foregroundColor(Theme.textColor)
            
            Text("Your data is safe and secure. It is not shared with any third-party software.")
                .font(.headline)
                .foregroundColor(Theme.secondaryTextColor)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct LoadingStepView: View {
    let text: String
    var body: some View {
        VStack(spacing: 20) {
            ProgressView().progressViewStyle(.circular)
            Text(text).foregroundColor(Theme.textColor)
        }
    }
}

struct PlanReadyStepView: View {
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundColor(Theme.accent)
            
            Text("Your plan is ready!")
                .font(.largeTitle).bold()
                .foregroundColor(Theme.textColor)
        }
        .padding()
    }
}


// MARK: - Reusable UI Components

struct GlassBackButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left")
                .font(.headline) // Adjusted font for better fit
                .foregroundColor(Theme.textColor)
                .frame(width: 44, height: 44) // Set a fixed 44x44 square frame
           
                .clipShape(Circle()) // Clips the square frame into a perfect circle
        }
    }
}

// --- FIX: OnboardingButton now has a built-in glass effect for consistency ---
struct OnboardingButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline).bold()
                .foregroundColor(Theme.textColor)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial) // Glass background
                .clipShape(Capsule())
                .glassEffect()
                .overlay(
                    Capsule().stroke(Theme.pillBorder, lineWidth: 1) // Subtle border
                )
        }
        .padding(.horizontal, 40)
        .padding(.bottom)
    }
}

struct CustomStepper: View {
    @Binding var value: Int
    var range: ClosedRange<Int>
    var step: Int = 1
    let label: String
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: { if value > range.lowerBound { value -= step } }) {
                Image(systemName: "minus.circle.fill")
            }
            .disabled(value <= range.lowerBound)
            
            Text("\(value) \(label)")
                .font(.system(size: 40, weight: .bold))
                .frame(minWidth: 150)
            
            Button(action: { if value < range.upperBound { value += step } }) {
                Image(systemName: "plus.circle.fill")
            }
            .disabled(value >= range.upperBound)
        }
        .font(.largeTitle)
        .foregroundColor(Theme.accentColor)
    }
}

#Preview {
    let appState = AppState()
    let diaryViewModel = DiaryViewModel(isForPreview: true)
    let healthManager = HealthStoreManager()
    let sampleDOB = Calendar.current.date(from: DateComponents(year: 1995, month: 8, day: 15)) ?? Date()

    return NavigationView {
        OnboardingFlowView(userName: "Alex", dob: sampleDOB)
            .environmentObject(appState)
            .environmentObject(diaryViewModel)
            .environmentObject(healthManager)
    }
    .preferredColorScheme(.dark)
}
