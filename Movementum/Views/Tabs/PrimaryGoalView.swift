import SwiftUI

struct PrimaryGoalView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    @AppStorage("dailyStepsGoal") private var dailyStepsGoal: Int = 10000

    @State private var selectedGoal: String = "General Fitness"
    @State private var customGoal: String = ""

    private let suggestions = [ "Weight Loss", "Strength Gain", "Endurance", "Flexibility"]

    var body: some View {
        VStack(spacing: 18) {
            // Top close button
            HStack {
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(Theme.textColor)
                        .padding()
                        .glassEffect()
                        .glassEffect()
                        
                        
                
                }
                .padding(.trailing, 16)
            }

            // Eye-catching header
            VStack(spacing: 8) {
                Text("Primary Goal")
                    .font(.largeTitle).bold().foregroundColor(Theme.textColor)
                Text("Choose or type your main goal")
                    .font(.subheadline)
                    .foregroundColor(Theme.secondaryTextColor)
            }
            .padding(.horizontal)

            // Card with choices
            VStack(spacing: 12) {
                // Current selection
                Text(selectedGoal)
                    .font(.title2).bold().foregroundColor(Theme.accentColor)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial))

                // Suggested goals
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(suggestions, id: \.self) { s in
                        Button(action: { selectedGoal = s; customGoal = "" }) {
                            Text(s)
                                .font(.subheadline).bold()
                                .foregroundColor(selectedGoal == s ? .white : Theme.textColor)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(
                                    ZStack {
                                        if selectedGoal == s {
                                            Theme.accentColor
                                        } else {
                                            RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                                        }
                                    }
                                )
                                .cornerRadius(12)
                        }
                    }
                }

                // Custom goal input
                VStack(alignment: .leading, spacing: 6) {
                   
                   
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial))
            .cornerRadius(18)
            .padding(.horizontal)

            Spacer()

            Button(action: saveAndClose) {
                Text("Save Goal")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .glassEffect()
                    .background(.green)
                    .cornerRadius(25)
                    .padding(.horizontal)
            }
            .padding(.bottom, 30)
        }
        .onAppear(perform: loadCurrentGoal)
        .navigationBarHidden(true)
    }

    private func loadCurrentGoal() {
        if let profile = diaryViewModel.userProfile {
            selectedGoal = profile.goal
        } else {
            selectedGoal = "General Fitness"
        }
    }

    private func saveAndClose() {
        if var profile = diaryViewModel.userProfile {
            profile.goal = selectedGoal
            diaryViewModel.save(userProfile: profile)
        } else {
            // Create a minimal profile if none exists
            let newProfile = UserProfile(name: "User", dob: Date(), height: 0, weight: 0, goal: selectedGoal, workoutDaysPerWeek: 3, dailyStepsTarget: dailyStepsGoal, difficultyLevel: "Beginner", workoutMode: "Home")
            diaryViewModel.save(userProfile: newProfile)
        }
        presentationMode.wrappedValue.dismiss()
    }
}

#Preview {
    PrimaryGoalView()
        .preferredColorScheme(.dark)
        .environmentObject(DiaryViewModel(isForPreview: true))
}
