import SwiftUI

struct CreateRoutineView: View {
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    @Environment(\.dismiss) var dismiss

    @State private var routineName: String = ""
    @State private var durationText: String = "30 Minutes"

    // Exercise builder fields
    @State private var exerciseName: String = ""
    @State private var exerciseSets: Int = 3
    @State private var exerciseReps: String = "10"
    @State private var exerciseType: ExerciseType = .upperBody

    @State private var exercises: [Exercise] = []
    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                
                // 1. Scrollable Top Section
                ScrollView {
                    VStack(spacing: 20) {
                        routineDetailsSection
                        Divider()
                        addedExercisesList
                    }
                    .padding()
                }

                // 2. Fixed Bottom Section
                addNewExerciseForm
            }
            .navigationTitle("Create Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveRoutine() }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    // MARK: - Extracted Views

    private var routineDetailsSection: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Routine Title").font(.headline)
                TextField("e.g. Full Body Blast", text: $routineName)
                    .padding()
                    .glassEffect()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Estimated Duration").font(.headline)
                TextField("e.g. 30 Minutes", text: $durationText)
                    .padding()
                    .glassEffect()
            }
        }
    }

    private var addedExercisesList: some View {
        Group {
            if !exercises.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Added Exercises")
                        .font(.headline)
                        .foregroundColor(.gray)

                    ForEach(exercises) { ex in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(ex.name).font(.subheadline).bold()
                                
                                // 👇 FIXED LINE: Safely unwrap optional type
                                Text("\(ex.sets)x \(ex.reps) • \((ex.type?.rawValue ?? "General").capitalized)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                if let idx = exercises.firstIndex(of: ex) {
                                    exercises.remove(at: idx)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(20)
                    }
                }
            } else {
                Text("No exercises added yet")
                    .foregroundColor(.gray)
                    .padding(.top, 20)
            }
        }
    }

    private var addNewExerciseForm: some View {
        VStack(spacing: 12) {
            Divider()
            
            Text("Add New Exercise").font(.caption).bold().frame(maxWidth: .infinity, alignment: .leading)
            
            TextField("Exercise name", text: $exerciseName)
                .padding()
                .glassEffect()

            HStack {
                Stepper("Sets: \(exerciseSets)", value: $exerciseSets, in: 1...10)
                Spacer()
                TextField("Reps", text: $exerciseReps)
                    .frame(width: 80)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.roundedBorder)
            }

            Picker("Type", selection: $exerciseType) {
                ForEach(ExerciseType.allCases, id: \.self) { type in
                    Text(type.rawValue.capitalized).tag(type)
                }
            }
            .pickerStyle(.segmented)

            Button(action: addExercise) {
                Label("Add to Routine", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.green : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(25)
            }
            .disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(25, corners: [.topLeft, .topRight])
        .shadow(radius: 10)
    }

    // MARK: - Functions

    private func addExercise() {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        // Ensure Exercise handles the type correctly
        let ex = Exercise(
            name: trimmed,
            sets: exerciseSets,
            reps: exerciseReps,
            restTime: 60,
            type: exerciseType,
            animationName: ""
        )
        exercises.append(ex)

        exerciseName = ""
        exerciseSets = 3
        exerciseReps = "10"
        exerciseType = .upperBody
    }

    private func saveRoutine() {
        let trimmedName = routineName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            alertMessage = "Please enter a routine title."
            showAlert = true
            return
        }
        guard !exercises.isEmpty else {
            alertMessage = "Please add at least one exercise to the routine."
            showAlert = true
            return
        }
        let routine = UserRoutine(name: trimmedName, duration: durationText, exercises: exercises, createdAt: Date())
        diaryViewModel.add(routine: routine)
        dismiss()
    }
}

// MARK: - Helpers

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    CreateRoutineView()
        .environmentObject(DiaryViewModel(isForPreview: true))
        .preferredColorScheme(.dark)
}
