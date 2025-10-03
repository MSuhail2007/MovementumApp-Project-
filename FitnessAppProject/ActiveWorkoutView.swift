import SwiftUI
import Combine

struct ActiveWorkoutView: View {
    let workout: Workout
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    
    // --- STATE MANAGEMENT ---
    @State private var currentExerciseIndex = 0
    // NEW: State to track the current set for an exercise
    @State private var currentSet = 1
    
    @State private var isResting = false
    @State private var restTimeRemaining = 60
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // --- COMPUTED PROPERTIES ---
    private var currentExercise: Exercise { workout.exercises[currentExerciseIndex] }
    private var isLastSet: Bool { currentSet == currentExercise.sets }
    private var isLastExercise: Bool { currentExerciseIndex == workout.exercises.count - 1 }
    private var workoutProgress: Double { Double(currentExerciseIndex) / Double(workout.exercises.count) }

    var body: some View {
        ZStack {
            Theme.backgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack {
                // --- TOP BAR: Progress and Exit Button ---
                HStack {
                    Text("\(currentExerciseIndex + 1) / \(workout.exercises.count)")
                        .font(.headline)
                        .foregroundColor(Theme.secondaryTextColor)
                    
                    CustomProgressView(progress: workoutProgress, color: Theme.accentColor)
                        .frame(height: 8)
                    
                    Button("Exit") { dismiss() }
                        .foregroundColor(Theme.accentColor)
                }
                .padding(.horizontal)
                
                // --- MAIN CONTENT: Switches between Exercise and Rest Timer ---
                if isResting {
                    // Rest Timer View is unchanged
                    RestTimerView(timeRemaining: $restTimeRemaining, nextExerciseName: workout.exercises[safe: currentExerciseIndex + 1]?.name, skipAction: advanceToNextExercise)
                } else {
                    // The exercise display now includes the new set tracker
                    ExerciseDisplayView(exercise: currentExercise, currentSet: currentSet)
                }
                
                // --- BOTTOM BUTTON ---
                if !isResting {
                    Button(action: completeSet) {
                        Text(isLastSet ? "Finish Exercise" : "Complete Set")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 55)
                            .background(Theme.accentColor)
                            .cornerRadius(15)
                    }
                    .padding()
                }
            }
        }
        .onReceive(timer) { _ in
            if isResting && restTimeRemaining > 0 {
                restTimeRemaining -= 1
            } else if isResting && restTimeRemaining == 0 {
                advanceToNextExercise()
            }
        }
    }
    
    // --- UPDATED ACTION LOGIC ---
    private func completeSet() {
        if isLastSet {
            // If it's the last set of the exercise
            if isLastExercise {
                // And it's also the last exercise of the workout
                finishWorkout()
            } else {
                // Start the rest period before the next exercise
                isResting = true
                restTimeRemaining = 60
            }
        } else {
            // If it's not the last set, just advance to the next set
            currentSet += 1
        }
    }
    
    private func advanceToNextExercise() {
        isResting = false
        if !isLastExercise {
            currentExerciseIndex += 1
            currentSet = 1 // Reset the set counter for the new exercise
        }
    }
    
    private func finishWorkout() {
        let newLog = WorkoutLog(name: workout.name, duration: workout.duration, date: Date())
        diaryViewModel.add(workoutLog: newLog)
        dismiss()
    }
}

// --- UPDATED: This view now shows a "Set Tracker" ring instead of an image ---
struct ExerciseDisplayView: View {
    let exercise: Exercise
    let currentSet: Int
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // The new "Set Tracker" ring
            ZStack {
                Circle()
                    .stroke(Theme.secondaryBackgroundColor, lineWidth: 20)
                
                Circle()
                    .trim(from: 0, to: CGFloat(currentSet) / CGFloat(exercise.sets))
                    .stroke(Theme.accentColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut, value: currentSet)
                
                VStack {
                    Text("Set")
                        .font(.title).bold()
                        .foregroundColor(Theme.secondaryTextColor)
                    Text("\(currentSet)")
                        .font(.system(size: 60, weight: .bold))
                }
                .foregroundColor(Theme.textColor)
            }
            .frame(width: 200, height: 200)
            
            VStack {
                Text(exercise.name)
                    .font(.largeTitle).bold()
                    .foregroundColor(Theme.textColor)
                    .multilineTextAlignment(.center)
                
                Text("\(exercise.sets) sets of \(exercise.reps)")
                    .font(.title2).fontWeight(.semibold)
                    .foregroundColor(Theme.secondaryTextColor)
            }
            
            Spacer()
        }
        .padding(.horizontal)
    }
}

// A custom-built progress bar
struct CustomProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().foregroundColor(color.opacity(0.2))
                Capsule()
                    .frame(width: geometry.size.width * CGFloat(min(self.progress, 1.0)))
                    .foregroundColor(color)
                    .animation(.linear, value: progress)
            }
        }
    }
}

// The rest timer view
struct RestTimerView: View {
    @Binding var timeRemaining: Int
    let nextExerciseName: String?
    let skipAction: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("REST").font(.largeTitle).bold().foregroundColor(Theme.secondaryTextColor)
            Text("\(timeRemaining)").font(.system(size: 80, weight: .bold)).foregroundColor(Theme.textColor)
            if let nextExercise = nextExerciseName {
                Text("Next Up: \(nextExercise)").font(.headline).foregroundColor(Theme.accentColor)
            }
            Button("Skip Rest") { skipAction() }.foregroundColor(Theme.secondaryTextColor).padding(.top, 20)
            Spacer()
        }
    }
}

// Helper to safely access array elements
extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    let sampleWorkout = Workout(name: "Upper Body Strength", duration: "45 Minutes", exercises: [
        Exercise(name: "Bench Press", sets: 3, reps: "8-12", animationName: "bench_press"),
        Exercise(name: "Pull Ups", sets: 3, reps: "To failure", animationName: "pull_up")
    ])
    
    return ActiveWorkoutView(workout: sampleWorkout)
        .environmentObject(DiaryViewModel(isForPreview: true))
}

