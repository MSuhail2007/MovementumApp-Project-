import SwiftUI
import FirebaseAuth

struct ProfileSetupView: View {
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    @EnvironmentObject var appState: AppState
    
    // --- State variables to hold the user's input ---
    @State private var name: String = ""
    @State private var dob = Date()
    @State private var height: String = "" // In cm
    @State private var weight: String = "" // In kg
    
    // --- Computed Properties for BMI Calculation ---
    private var heightInMeters: Double { (Double(height) ?? 0) / 100 }
    private var weightInKg: Double { Double(weight) ?? 0 }
    private var bmi: Double {
        guard heightInMeters > 0, weightInKg > 0 else { return 0 }
        return weightInKg / (heightInMeters * heightInMeters)
    }
    private var bmiCategory: (String, Color) {
        switch bmi {
        case ..<18.5: return ("Underweight", .blue)
        case 18.5..<24.9: return ("Healthy Weight", .green)
        case 25..<29.9: return ("Overweight", .orange)
        default: return ("Obesity", .red)
        }
    }
    private var isFormValid: Bool { !name.isEmpty && !height.isEmpty && !weight.isEmpty }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundColor.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Tell Us About Yourself")
                            .font(.largeTitle).bold()
                            .foregroundColor(Theme.textColor)
                        
                        Text("This helps us create a personalized plan for you.")
                            .font(.headline)
                            .foregroundColor(Theme.secondaryTextColor)
                            .padding(.bottom, 20)
                        
                        // --- Input Fields ---
                        TextField("Your Name", text: $name)
                            .modifier(ThemedTextFieldStyle())
                        
                        DatePicker("Date of Birth", selection: $dob, displayedComponents: .date)
                            .padding()
                            .background(Theme.secondaryBackgroundColor)
                            .cornerRadius(10)
                        
                        HStack {
                            TextField("Height (cm)", text: $height)
                                .modifier(ThemedTextFieldStyle())
                                .keyboardType(.decimalPad)
                            
                            TextField("Weight (kg)", text: $weight)
                                .modifier(ThemedTextFieldStyle())
                                .keyboardType(.decimalPad)
                        }
                        
                        if bmi > 0 {
                            BMICardView(bmi: bmi, category: bmiCategory)
                        }
                        
                        Spacer()
                        
                        // --- The "Continue" button now navigates to the new OnboardingView ---
                        NavigationLink(destination: OnboardingView(profile: createProfile())) {
                            Text("Continue")
                                .font(.headline)
                                .foregroundColor(isFormValid ? .white : Theme.secondaryTextColor)
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                        }
                        .frame(height: 55)
                        .background(isFormValid ? AnyShapeStyle(Theme.accentColor.gradient) : AnyShapeStyle(Theme.secondaryBackgroundColor))
                        .cornerRadius(15)
                        .disabled(!isFormValid)
                        
                        Button("Log Out & Start Over", action: logOut)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)
                    }
                    .padding()
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                if let profile = diaryViewModel.userProfile, !profile.name.isEmpty {
                    self.name = profile.name
                }
            }
        }
        .accentColor(Theme.accentColor)
    }
    
    private func createProfile() -> UserProfile {
        return UserProfile(
            name: self.name,
            dob: self.dob,
            height: Double(self.height) ?? 0,
            weight: Double(self.weight) ?? 0,
            goal: "Not Set",
            workoutDaysPerWeek: 3
        )
    }
    
    private func logOut() {
        do {
            try Auth.auth().signOut()
        } catch let signOutError as NSError {
            print("Error signing out: %@", signOutError)
        }
    }
}

// --- THIS IS THE FIX: Full implementation for all helper views ---
struct ThemedTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Theme.secondaryBackgroundColor)
            .cornerRadius(10)
            .foregroundColor(Theme.textColor)
    }
}

struct BMICardView: View {
    let bmi: Double
    let category: (String, Color)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your BMI")
                .font(.headline)
                .foregroundColor(Theme.textColor)
            HStack {
                Text(String(format: "%.1f", bmi))
                    .font(.largeTitle).bold()
                    .foregroundColor(category.1)
                
                Text(category.0)
                    .font(.title2).bold()
                    .foregroundColor(category.1)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.secondaryBackgroundColor)
        .cornerRadius(10)
    }
}


#Preview {
    ProfileSetupView()
        .preferredColorScheme(.light)
        .environmentObject(DiaryViewModel())
        .environmentObject(AppState())
}

