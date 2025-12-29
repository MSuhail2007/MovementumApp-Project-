import SwiftUI

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    
    // State variables to hold the edited information
    @State private var name: String
    @State private var dob: Date
    @State private var height: String
    @State private var weight: String
    @State private var selectedGoal: String
    
    private let goals = [
        "Weight Loss",
        "Strength Gain",
        "Endurance",
        "Mobility",
        "General Fitness"
    ]
    
    // This special initializer pre-fills the form with the user's current data
    init(profile: UserProfile) {
        _name = State(initialValue: profile.name)
        _dob = State(initialValue: profile.dob)
        _height = State(initialValue: String(profile.height))
        _weight = State(initialValue: String(profile.weight))
        _selectedGoal = State(initialValue: profile.goal)
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.backgroundColor.edgesIgnoringSafeArea(.all)
                
                Form {
                    Section(header: Text("Personal Details").foregroundColor(Theme.secondaryTextColor)) {
                        TextField("Your Name", text: $name)
                        DatePicker("Date of Birth", selection: $dob, displayedComponents: .date)
                    }
                    .listRowBackground(Theme.secondaryBackgroundColor)
                    
                    Section(header: Text("Physical Stats").foregroundColor(Theme.secondaryTextColor)) {
                        HStack {
                            TextField("Height", text: $height).keyboardType(.decimalPad)
                            Text("cm").foregroundColor(Theme.secondaryTextColor)
                        }
                        HStack {
                            TextField("Weight", text: $weight).keyboardType(.decimalPad)
                            Text("kg").foregroundColor(Theme.secondaryTextColor)
                        }
                    }
                    .listRowBackground(Theme.secondaryBackgroundColor)

                    Section(header: Text("Primary Goal").foregroundColor(Theme.secondaryTextColor)) {
                        Picker("Goal", selection: $selectedGoal) {
                            ForEach(goals, id: \.self) { Text($0) }
                        }
                    }
                    .listRowBackground(Theme.secondaryBackgroundColor)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                 ToolbarItem(placement: .principal) {
                    Text("Edit Profile").bold().foregroundColor(Theme.textColor)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(Theme.accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveProfile).foregroundColor(Theme.accent)
                }
            }
        }
    }
    
    private func saveProfile() {
        // --- THIS IS THE FIX ---
        // We now include the user's existing dailyStepsTarget when saving.
        let updatedProfile = UserProfile(
            name: name,
            dob: dob,
            height: Double(height) ?? 0,
            weight: Double(weight) ?? 0,
            goal: selectedGoal,
            workoutDaysPerWeek: diaryViewModel.userProfile?.workoutDaysPerWeek ?? 3,
            dailyStepsTarget: diaryViewModel.userProfile?.dailyStepsTarget ?? 10000,
            difficultyLevel: diaryViewModel.userProfile?.difficultyLevel ?? "Beginner",
            workoutMode: diaryViewModel.userProfile?.workoutMode ?? "Home"
        )
        diaryViewModel.save(userProfile: updatedProfile)
        dismiss()
    }
}

#Preview {
    // --- THIS IS THE FIX ---
    // The sampleProfile now includes the missing dailyStepsTarget argument.
    let sampleProfile = UserProfile(
        name: "Suhail",
        dob: Date(),
        height: 175,
        weight: 70,
        goal: "Build Muscle",
        workoutDaysPerWeek: 3,
        dailyStepsTarget: 10000,
        difficultyLevel: "Beginner",
        workoutMode: "Home"
    )
    
    EditProfileView(profile: sampleProfile)
        .environmentObject(DiaryViewModel(isForPreview: true))
}
