import SwiftUI

// --- A data model for our workout days ---
struct WorkoutDay: Identifiable, Equatable {
    let id = UUID()
    let name: String // e.g., "Mon"
    let dayIndex: Int // 0 for Monday, 1 for Tuesday, etc.
}

struct WorkoutView: View {
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    
    // --- This now generates the full weekly schedule ---
    private var weeklySchedule: [(day: WorkoutDay, workout: Workout)] {
        guard let profile = diaryViewModel.userProfile else { return [] }
        let allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var schedule: [(WorkoutDay, Workout)] = []
        for i in 0..<7 {
            let workoutDay = WorkoutDay(name: allDays[i], dayIndex: i)
            let workout = fetchWorkout(for: profile.goal, week: currentWeek, dayIndex: i)
            schedule.append((workoutDay, workout))
        }
        return schedule
    }
    
    @State private var programStartDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    
    private var currentWeek: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear], from: programStartDate, to: Date())
        return (components.weekOfYear ?? 0) + 1
    }
    
    private var todayIndex: Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }

    var body: some View {
        NavigationView {
            // --- We use a GeometryReader for modern screen sizing ---
            GeometryReader { geometry in
                ZStack {
                    Theme.backgroundColor.edgesIgnoringSafeArea(.all)
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 30) {
                            
                            // --- Header ---
                            VStack(alignment: .leading) {
                                Text("Training Program")
                                    .font(.largeTitle).bold().foregroundColor(Theme.textColor)
                                Text("Your personalized plan for Week \(currentWeek)")
                                    .font(.headline).foregroundColor(Theme.secondaryTextColor)
                            }
                            .padding(.horizontal)
                            
                            // --- The Workout Carousel with Peeking Cards ---
                            ScrollViewReader { scrollViewProxy in
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 0) {
                                        ForEach(0..<weeklySchedule.count, id: \.self) { index in
                                            let item = weeklySchedule[index]
                                            
                                            GeometryReader { cardGeometry in
                                                let frame = cardGeometry.frame(in: .global)
                                                // We now pass the main geometry to the helper functions
                                                let scale = scaleValue(for: frame, in: geometry)
                                                let rotation = rotationValue(for: frame, in: geometry)

                                                WorkoutCarouselCard(
                                                    workoutDay: item.day,
                                                    workout: item.workout,
                                                    isToday: item.day.dayIndex == todayIndex
                                                )
                                                .scaleEffect(scale)
                                                .rotation3DEffect(rotation, axis: (x: 0, y: 1, z: 0))
                                            }
                                            // The card width is now based on the GeometryReader
                                            .frame(width: geometry.size.width - 80)
                                            .id(index)
                                        }
                                    }
                                    .scrollTargetLayout()
                                }
                                .scrollTargetBehavior(.viewAligned)
                                .safeAreaPadding(.horizontal, 40)
                                .frame(height: 420)
                                .onAppear {
                                    scrollViewProxy.scrollTo(todayIndex, anchor: .center)
                                }
                            }
                            
                            // --- The Workout History Section ---
                            VStack(alignment: .leading) {
                                Text("History")
                                    .font(.title2).bold().foregroundColor(Theme.textColor)
                                
                                if diaryViewModel.workoutLogs.isEmpty {
                                    InfoCardView(
                                        iconName: "list.star",
                                        iconColor: .gray,
                                        title: "No History Yet",
                                        text: "Your completed workouts will appear here."
                                    )
                                } else {
                                    ForEach(diaryViewModel.workoutLogs.suffix(3).reversed()) { log in
                                        HistoryRowView(log: log)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            Spacer()
                        }
                        .padding(.top, 20)
                    }
                }
                .navigationBarHidden(true)
            }
            .accentColor(Theme.accentColor)
        }
    }
    
    // --- Helper functions have been updated to use the GeometryReader ---
    private func scaleValue(for frame: CGRect, in geometry: GeometryProxy) -> CGFloat {
        // Guard against division by zero
        guard geometry.size.width > 0 else { return 0.8 }
        let distance = abs(geometry.frame(in: .global).midX - frame.midX)
        return max(1.0 - (distance / (geometry.size.width)), 0.8)
    }
    
    private func rotationValue(for frame: CGRect, in geometry: GeometryProxy) -> Angle {
        guard geometry.size.width > 0 else { return .zero }
        let rotation = Angle.degrees(Double(frame.midX - geometry.frame(in: .global).midX) / 20)
        return rotation
    }
    
    // --- The workout "brain" now uses all workout variables ---
    private func fetchWorkout(for goal: String?, week: Int, dayIndex: Int) -> Workout {
        let restDay = Workout(name: "Rest Day", duration: "N/A", exercises: [])
        let fullBodyMobility = Workout(name: "Full Body Mobility", duration: "20 Mins", exercises: [
            Exercise(name: "Cat-Cow Stretch", sets: 2, reps: "10 reps", animationName: "cat_cow"),
            Exercise(name: "Glute Bridges", sets: 3, reps: "15 reps", animationName: "glute_bridge")
        ])
        let upperBodyA = Workout(name: "Upper Body Strength A", duration: "45 Mins", exercises: [
            Exercise(name: "Bench Press", sets: 3, reps: "8-12 reps", animationName: "bench_press"),
            Exercise(name: "Pull Ups", sets: 3, reps: "To failure", animationName: "pull_up"),
            Exercise(name: "Dumbbell Rows", sets: 3, reps: "10 reps", animationName: "dumbbell_row")
        ])
        let lowerBodyA = Workout(name: "Lower Body Power A", duration: "45 Mins", exercises: [
            Exercise(name: "Squats", sets: 3, reps: "8-12 reps", animationName: "squat"),
            Exercise(name: "Romanian Deadlifts", sets: 3, reps: "10 reps", animationName: "romanian_deadlift"),
            Exercise(name: "Leg Press", sets: 3, reps: "10-12 reps", animationName: "leg_press")
        ])
        let fullBody = Workout(name: "Full Body Strength", duration: "50 Mins", exercises: [
             Exercise(name: "Overhead Press", sets: 3, reps: "8-12 reps", animationName: "overhead_press"),
             Exercise(name: "Lunges", sets: 3, reps: "12 reps/leg", animationName: "lunge"),
             Exercise(name: "Plank", sets: 3, reps: "45 seconds", animationName: "plank")
        ])
        
        let daysPerWeek = diaryViewModel.userProfile?.workoutDaysPerWeek ?? 3
        
        if daysPerWeek >= 5 {
            let schedule = [upperBodyA, lowerBodyA, fullBody, upperBodyA, lowerBodyA, restDay, fullBodyMobility]
            return schedule[dayIndex]
        } else { // Default to 3-day split
            let schedule = [upperBodyA, restDay, lowerBodyA, restDay, fullBody, restDay, fullBodyMobility]
            return schedule[dayIndex]
        }
    }
}

// --- The redesigned carousel card ---
struct WorkoutCarouselCard: View {
    let workoutDay: WorkoutDay
    let workout: Workout
    let isToday: Bool
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter(); formatter.dateFormat = "d"; return formatter
    }
    
    private var dateForThisCard: Date {
        let today = Date()
        let todayIndex = (Calendar.current.component(.weekday, from: today) + 5) % 7
        let dayDifference = workoutDay.dayIndex - todayIndex
        return Calendar.current.date(byAdding: .day, value: dayDifference, to: today)!
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            if isToday {
                Text("Today's Plan")
                    .font(.headline).bold()
                    .foregroundColor(Theme.accentColor)
                    .padding(.bottom, 5)
            } else {
                Text(" ").font(.headline).padding(.bottom, 5)
            }
            
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 30)
                    .fill(isToday ? Theme.accentColor.opacity(0.15) : Theme.secondaryTextColor.opacity(0.1))

                RoundedRectangle(cornerRadius: 30)
                    .fill(.ultraThinMaterial)
                
                VStack(alignment: .leading, spacing: 15) {
                    HStack {
                        VStack {
                            Text(dayFormatter.string(from: dateForThisCard)).font(.largeTitle).bold()
                            Text(workoutDay.name.uppercased()).font(.headline).foregroundColor(Theme.secondaryTextColor)
                        }
                        Spacer()
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading) {
                        Text(workout.name).font(.title).bold()
                        Text(workout.duration).font(.subheadline).foregroundColor(Theme.secondaryTextColor)
                    }
                    
                    if workout.name != "Rest Day" {
                        NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                            Label("Start Workout", systemImage: "play.fill")
                                .font(.headline).bold()
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(isToday ? AnyShapeStyle(Theme.accentColor.gradient) : AnyShapeStyle(Color.gray.opacity(0.5)))
                                .clipShape(Capsule())
                        }
                        .disabled(!isToday)
                    }
                }
                .padding(25)
            }
        }
    }
}

// --- Helper Views with a consistent "glass" style ---
struct HistoryRowView: View {
    let log: WorkoutLog
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").foregroundColor(Theme.accentColor).font(.title2)
            VStack(alignment: .leading) {
                Text("Training completed").font(.headline).foregroundColor(Theme.textColor)
                Text(log.name).font(.subheadline).foregroundColor(Theme.secondaryTextColor)
            }
            Spacer()
            Image(systemName: "ellipsis").foregroundColor(Theme.secondaryTextColor)
        }
        .padding().background(.ultraThinMaterial).cornerRadius(15)
    }
}

// --- THIS IS THE FIX: The duplicate InfoCardView has been removed ---
// This file will now use the shared InfoCardView defined in another file.


#Preview {
    WorkoutView().preferredColorScheme(.dark).environmentObject(DiaryViewModel(isForPreview: true))
}

