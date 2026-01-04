import SwiftUI

struct WorkoutDetailView: View {
    let workout: Workout
    
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    // --- Get access to the presentation mode to dismiss the view ---
    @Environment(\.dismiss) var dismiss
    
    @State private var isWorkoutActive = false

    // --- A helper to check if the workout is now complete ---
    private var isWorkoutCompletedToday: Bool {
        diaryViewModel.workoutLogs.contains { log in
            Calendar.current.isDate(log.date, inSameDayAs: Date()) && log.name == workout.name
        }
    }

    var body: some View {
        ZStack {
            Theme.backgroundColor.edgesIgnoringSafeArea(.all)

            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    workoutHeader
                    Divider().background(Theme.secondaryTextColor.opacity(0.5))
                    exerciseList
                    Spacer()
                }
                .padding()
            }
            
            VStack {
                Spacer()
                Button(action: {
                    self.isWorkoutActive = true
                }) {
                    Text("Start Workout")
                        .font(.headline)
                        .foregroundColor(Theme.textColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .background(Color.green)
                        .cornerRadius(25)
                        .glassEffect()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .accentColor(Theme.accentColor)
        .fullScreenCover(isPresented: $isWorkoutActive) {
            ActiveWorkoutView(workout: workout)
                .environmentObject(diaryViewModel)
        }
        // --- THIS IS THE FIX ---
        // This watches for when the workout session is dismissed. If the workout
        // is now complete, it automatically dismisses this detail view.
        .onChange(of: isWorkoutActive) {
            if !isWorkoutActive && isWorkoutCompletedToday {
                dismiss()
            }
        }
    }

    private var workoutHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(workout.name)
                .font(.largeTitle).bold()
                .foregroundColor(Theme.textColor)
            
            HStack(spacing: 20) {
                Label(workout.duration, systemImage: "clock.fill")
                Label("\(workout.exercises.count) Exercises", systemImage: "list.bullet.rectangle.fill")
            }
            .font(.subheadline)
            .foregroundColor(Theme.secondaryTextColor)
        }
    }
    
    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Exercises")
                .font(.title2).bold()
                .foregroundColor(Theme.textColor)
            
            ForEach(workout.exercises) { exercise in
                ExerciseRowView(exercise: exercise)
            }
        }
    }
}

// All helper views are unchanged
struct ExerciseRowView: View {
    let exercise: Exercise
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundColor(Theme.textColor)
                Text("\(exercise.sets) sets of \(exercise.reps)")
                    .font(.subheadline)
                    .foregroundColor(Theme.secondaryTextColor)
            }
            Spacer()
            // We can add a button here later to show a video or instructions
            Image(systemName: "info.circle")
                .font(.title2)
                .foregroundColor(Color.blue)
        }
        .padding()
        .glassEffect()
    }
}


// --- Preview Provider ---
#Preview {
    // --- THIS IS THE FIX ---
    // The missing 'type' argument has been added to each Exercise.
    let sampleWorkout = Workout(name: "Upper Body Strength", goalCategory: "Muscle Gain", difficulty: "Beginner", isLowImpact: false, duration: "45 Minutes", allowedModes: ["Gym","Dumbbell Only"], exercises: [
        Exercise(name: "Bench Press", sets: 3, reps: "8-12 reps", restTime: 90, type: .upperBody, animationName: "bench_press"),
        Exercise(name: "Pull Ups", sets: 3, reps: "To failure", restTime: 90, type: .upperBody, animationName: "pull_up"),
        Exercise(name: "Dumbbell Rows", sets: 3, reps: "10-12 reps", restTime: 90, type: .upperBody, animationName: "dumbbell_row"),
        Exercise(name: "Overhead Press", sets: 3, reps: "8-12 reps", restTime: 90, type: .upperBody, animationName: "overhead_press")
    ])
    
    NavigationView {
        WorkoutDetailView(workout: sampleWorkout)
            .preferredColorScheme(.dark)
            .environmentObject(DiaryViewModel(isForPreview: true))
    }
}
