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
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Routine Title").font(.headline)
                        TextField("e.g. Full Body Blast", text: $routineName)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estimated Duration").font(.headline)
                        TextField("e.g. 30 Minutes", text: $durationText)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add Exercise").font(.headline)

                        TextField("Exercise name", text: $exerciseName)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Stepper("Sets: \(exerciseSets)", value: $exerciseSets, in: 1...10)
                            Spacer()
                            TextField("Reps (e.g. 8-12)", text: $exerciseReps)
                                .frame(width: 120)
                                .textFieldStyle(.roundedBorder)
                        }

                        Picker("Type", selection: $exerciseType) {
                            ForEach(ExerciseType.allCases, id: \.self) { type in
                                Text(type.rawValue.capitalized).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        Button(action: addExercise) {
                            Label("Add Exercise", systemImage: "plus.circle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .glassEffect()
                                .background(Theme.accent)
                                .foregroundColor(Theme.textColor)
                                .cornerRadius(30)
                        }
                        .disabled(exerciseName.trimmingCharacters(in: .whitespaces).isEmpty)

                    }

                    if !exercises.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Exercises")
                                .font(.headline)

                            ForEach(exercises) { ex in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(ex.name).font(.subheadline).bold()
                                        Text("\(ex.sets)x \(ex.reps)").font(.caption).foregroundColor(Theme.secondaryTextColor)
                                    }
                                    Spacer()
                                    Button(role: .destructive) {
                                        if let idx = exercises.firstIndex(of: ex) {
                                            exercises.remove(at: idx)
                                        }
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                                .padding()
                                .background(Theme.secondaryBackgroundColor)
                                .cornerRadius(10)
                            }
                        }
                    }

                    Spacer()
                }
                .padding()
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

    private func addExercise() {
        let trimmed = exerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        // Provide a default rest time when creating an Exercise from the UI
        let ex = Exercise(name: trimmed, sets: exerciseSets, reps: exerciseReps, restTime: 60, type: exerciseType, animationName: "")
        exercises.append(ex)

        // reset fields
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

#Preview {
    CreateRoutineView().environmentObject(DiaryViewModel(isForPreview: true)).preferredColorScheme(.dark)
}
