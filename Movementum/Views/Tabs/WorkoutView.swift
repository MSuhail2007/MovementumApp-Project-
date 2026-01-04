import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var diaryViewModel: DiaryViewModel

    enum WorkoutMode: String, CaseIterable, Identifiable {
        case ai = "AI Workout"
        case custom = "Your Workout"
        var id: String { rawValue }
    }

    @State private var selectedMode: WorkoutMode = .ai
    @State private var aiWorkouts: [Workout]? = nil
    @State private var isLoadingAI: Bool = false

    // --- This now generates the full weekly schedule using the simple model ---
    private var weeklySchedule: [(day: WorkoutDay, workout: Workout)] {
        guard let profile = diaryViewModel.userProfile else { return [] }
        let allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var schedule: [(WorkoutDay, Workout)] = []
        for i in 0..<7 {
            let workoutDay = WorkoutDay(name: allDays[i], dayIndex: i)
            // Use the centralized WorkoutLibrary to generate workouts based on the onboarding goal
            let workout = WorkoutLibrary.shared.generateWorkout(for: profile.goal, dayIndex: i, daysPerWeek: profile.workoutDaysPerWeek)
            schedule.append((workoutDay, workout))
        }
        return schedule
    }

    @State private var programStartDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    @State private var showingCreateRoutine = false

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
            GeometryReader { geometry in
                ZStack {
                    Theme.backgroundColor.edgesIgnoringSafeArea(.all)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 30) {

                            // Header
                            VStack(alignment: .leading) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("Training Program")
                                            .font(.largeTitle).bold().foregroundColor(Theme.textColor)
                                        Text("Your personalized plan for Week \(currentWeek)")
                                            .font(.headline).foregroundColor(Theme.secondaryTextColor)
                                    }
                                    Spacer()
                                    // Quick access to create a custom routine
//                                    Button(action: { showingCreateRoutine = true }) {
//                                        Image(systemName: "plus")
//                                            .padding(10)
//                                            .background(.ultraThinMaterial)
//                                            .clipShape(Circle())
//                                    }
                                }

                                // Mode picker (AI vs Your)
                                Picker("Mode", selection: $selectedMode) {
                                    ForEach(WorkoutMode.allCases) { mode in
                                        Text(mode.rawValue).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .padding(.top, 12)
                            }
                            .padding(.horizontal)

                            // Conditional content based on mode
                            if selectedMode == .ai {
                                if isLoadingAI {
                                    HStack { Spacer(); ProgressView("Generating AI workouts...").padding(); Spacer() }
                                } else if let aiWorkouts = aiWorkouts {
                                    // AI-generated carousel
                                    ScrollViewReader { scrollViewProxy in
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 0) {
                                                ForEach(0..<aiWorkouts.count, id: \.self) { index in
                                                    let workout = aiWorkouts[index]

                                                    GeometryReader { cardGeometry in
                                                        let frame = cardGeometry.frame(in: .global)
                                                        let scale = scaleValue(for: frame, in: geometry)
                                                        let rotation = rotationValue(for: frame, in: geometry)

                                                        CarouselCardView(
                                                            workoutDay: WorkoutDay(name: ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][index], dayIndex: index),
                                                            workout: workout,
                                                            isToday: index == todayIndex,
                                                            isCompleted: isWorkoutCompleted(workout: workout, on: dateForDayIndex(index))
                                                        )
                                                        .scaleEffect(scale)
                                                        .rotation3DEffect(rotation, axis: (x: 0, y: 1, z: 0))
                                                    }
                                                    // Use a fixed card width so multiple weekday cards are visible in the horizontal scroller
                                                    .frame(width: 260)
                                                    .id(index)
                                                }
                                            }
                                            .scrollTargetLayout()
                                            .background(Theme.backgroundColor)
                                        }
                                        .scrollTargetBehavior(.viewAligned)
                                        .scrollContentBackground(.hidden)
                                        .background(Theme.backgroundColor)
                                        // force compositing/clipping to avoid blending artifacts from shadows/backgrounds
                                        .compositingGroup()
                                        .clipped()
                                        .padding(.horizontal, 20)
                                        .frame(height: 340)
                                         .onAppear {
                                             scrollViewProxy.scrollTo(todayIndex, anchor: .center)
                                         }
                                     }
                                 } else {
                                    // No cached AI workouts yet — trigger loading
                                    HStack { Spacer(); Button("Generate AI Workouts") { Task { await loadAIWorkouts() } }.buttonStyle(.borderedProminent); Spacer() }
                                }

                            } else {
                                // Your Workout mode: show user-created routines
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Your Routines")
                                            .font(.title2).bold().foregroundColor(Theme.textColor)
                                        Spacer()
                                        Button(action: { showingCreateRoutine = true }) {
                                            Label("New", systemImage: "plus.circle")
                                                .labelStyle(.iconOnly)
                                                .foregroundColor(Theme.accentColor)
                                        }
                                    }
                                    .padding(.horizontal)

                                    if diaryViewModel.userRoutines.isEmpty {
                                        InfoCardView(iconName: "sparkles", iconColor: .gray, title: "Create your own routine", text: "Build and save custom workout routines you can reuse anytime.")
                                            .padding(.horizontal)
                                    } else {
                                        VStack(spacing: 10) {
                                            ForEach(diaryViewModel.userRoutines) { routine in
                                                NavigationLink(destination: WorkoutDetailView(workout: Workout(name: routine.name, goalCategory: "Custom", difficulty: "Custom", isLowImpact: false, duration: routine.duration, allowedModes: ["Home","Gym","Dumbbell Only"], exercises: routine.exercises))) {
                                                    HStack {
                                                        VStack(alignment: .leading) {
                                                            Text(routine.name).font(.headline).foregroundColor(Theme.textColor)
                                                            Text(routine.duration).font(.subheadline).foregroundColor(Theme.secondaryTextColor)
                                                        }
                                                        Spacer()
                                                        Image(systemName: "chevron.right").foregroundColor(Theme.secondaryTextColor)
                                                    }
                                                    .padding()
                                                    .background(Theme.secondaryBackgroundColor)
                                                    .cornerRadius(12)
                                                    .padding(.horizontal)
                                                }
                                                .contextMenu {
                                                    Button(role: .destructive) {
                                                        diaryViewModel.removeRoutine(routine)
                                                    } label: {
                                                        Label("Delete", systemImage: "trash")
                                                    }
                                                }
                                                .transition(.move(edge: .bottom).combined(with: .opacity))
                                            }
                                        }
                                        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: diaryViewModel.userRoutines)
                                     }
                                 }
                             }

                             // The Workout History Section (always visible)
                             VStack(alignment: .leading) {
                                 Text("History")
                                     .font(.title2).bold().foregroundColor(Theme.textColor)

                                 if diaryViewModel.workoutLogs.isEmpty {
                                     InfoCardView(iconName: "list.star", iconColor: .gray, title: "No History Yet", text: "Your completed workouts will appear here.")
                                 } else {
                                    ForEach(diaryViewModel.workoutLogs.suffix(3).reversed()) { log in
                                        HistoryRowView(log: log)
                                            .transition(AnyTransition.move(edge: .trailing).combined(with: .opacity))
                                    }
                                     .animation(.easeIn(duration: 0.25), value: diaryViewModel.workoutLogs)
                                 }
                             }
                             .background(Theme.backgroundColor)
                              .padding(.horizontal)

                             Spacer()
                         }
                         .background(Theme.backgroundColor)
                         .padding(.top, 20)
                     }
                 }
                 .navigationBarHidden(true)
             }
            .accentColor(Color.green)
            .sheet(isPresented: $showingCreateRoutine) {
                CreateRoutineView()
                    .environmentObject(diaryViewModel)
            }
            .task {
                // Load AI workouts automatically on first appear when AI mode is selected
                if selectedMode == .ai && aiWorkouts == nil {
                    await loadAIWorkouts()
                }
            }
            .onChange(of: selectedMode) { _old, new in
                if new == .ai {
                    Task { await loadAIWorkouts() }
                }
            }
        }
    }

    // MARK: - helpers
    private func dateForDayIndex(_ dayIndex: Int) -> Date {
        let today = Date()
        let todayIndex = (Calendar.current.component(.weekday, from: today) + 5) % 7
        let dayDifference = dayIndex - todayIndex
        return Calendar.current.date(byAdding: .day, value: dayDifference, to: today)!
    }

    private func isWorkoutCompleted(workout: Workout, on date: Date) -> Bool {
        diaryViewModel.workoutLogs.contains { log in
            Calendar.current.isDate(log.date, inSameDayAs: date) && log.name == workout.name
        }
    }

    private func scaleValue(for frame: CGRect, in geometry: GeometryProxy) -> CGFloat {
        guard geometry.size.width > 0 else { return 0.8 }
        let distance = abs(geometry.frame(in: .global).midX - frame.midX)
        return max(1.0 - (distance / (geometry.size.width * 2.0)), 0.85)
    }

    private func rotationValue(for frame: CGRect, in geometry: GeometryProxy) -> Angle {
        guard geometry.size.width > 0 else { return .zero }
        let rotation = Angle.degrees(Double(frame.midX - geometry.frame(in: .global).midX) / 20)
        return rotation
    }

    // Move AI loader to main struct to ensure calls resolve correctly
    private func loadAIWorkouts() async {
         guard aiWorkouts == nil else { return }
         isLoadingAI = true
         defer { isLoadingAI = false }

         func restWorkout() -> Workout {
             Workout(name: "Rest Day", goalCategory: "Rest", difficulty: "Rest", isLowImpact: true, duration: "", allowedModes: [], exercises: [])
         }

         // If user has profile, build a week with N workout days and rest for others
         if let profile = diaryViewModel.userProfile {
             let daysPerWeek = max(0, min(7, profile.workoutDaysPerWeek))

             // Choose workout indices evenly across the week
             var workoutIndices = Set<Int>()
             if daysPerWeek > 0 {
                 let step = Double(7) / Double(daysPerWeek)
                 for k in 0..<daysPerWeek {
                     let position = Int(round(Double(k) * step))
                     workoutIndices.insert(min(max(0, position), 6))
                 }
                 // If rounding caused duplicates, fill the set incrementally
                 var fill = 0
                 while workoutIndices.count < daysPerWeek {
                     workoutIndices.insert(fill % 7)
                     fill += 1
                 }
             }

             // Build the week array
             // Use the WorkoutLibrary helper which returns exactly `daysPerWeek` randomized workout days
             var week: [Workout] = WorkoutLibrary.shared.generateWeeklySchedule(for: profile)

             // Try to improve each planned workout by matching user's mode/difficulty using the repository + recommender
             let age: Int = {
                 let comps = Calendar.current.dateComponents([.year], from: profile.dob, to: Date())
                 return comps.year ?? 30
             }()
             let recommendations = WorkoutRecommender.shared.suggestWorkouts(for: profile, age: age, allWorkouts: WorkoutRepository.shared.allWorkouts)

             if !recommendations.isEmpty {
                 for i in 0..<week.count {
                     let w = week[i]
                     guard w.goalCategory != "Rest" else { continue }
                     // if the generated workout doesn't support the user's mode, try to find a recommendation that does
                     if !w.allowedModes.contains(where: { $0.caseInsensitiveCompare(profile.workoutMode) == .orderedSame }) {
                         if let alt = recommendations.first(where: { $0.allowedModes.contains(where: { $0.caseInsensitiveCompare(profile.workoutMode) == .orderedSame }) }) {
                             week[i] = alt
                         }
                     }
                 }
             }

             // Ensure aiWorkouts is exactly 7 items (one per day)
             self.aiWorkouts = week.enumerated().map { idx, w in
                 if w.goalCategory == "Rest" { return w }
                 // prepend a small label so users know it's planned for them
                 return Workout(name: "Planned: \(w.name)", goalCategory: w.goalCategory, difficulty: w.difficulty, isLowImpact: w.isLowImpact, duration: w.duration, allowedModes: w.allowedModes, exercises: w.exercises)
             }

         } else {
             // No profile: default to 3 workouts per week spread across 7 days
             let generated = (0..<7).map { i in WorkoutLibrary.shared.generateWorkout(for: nil as String?, dayIndex: i, daysPerWeek: 3) }
             self.aiWorkouts = generated.map { w in
                 Workout(name: "AI: \(w.name)", goalCategory: w.goalCategory, difficulty: w.difficulty, isLowImpact: w.isLowImpact, duration: w.duration, allowedModes: w.allowedModes, exercises: w.exercises)
             }
         }
     }
}

// --- Helper Views ---
struct CarouselCardView: View {
    let workoutDay: WorkoutDay
    let workout: Workout
    let isToday: Bool
    let isCompleted: Bool
    @EnvironmentObject var diaryViewModel: DiaryViewModel

    // Local state to trigger the Lottie/fallback animation when a workout is completed
    @State private var playCompletionAnimation: Bool = false

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter(); formatter.dateFormat = "d"; return formatter
    }

    // Short weekday formatter for top-left day label
    private var weekdayFormatter: DateFormatter {
        let formatter = DateFormatter(); formatter.dateFormat = "E"; return formatter
    }

    private var dateForThisCard: Date {
        let today = Date()
        let todayIndex = (Calendar.current.component(.weekday, from: today) + 5) % 7
        let dayDifference = workoutDay.dayIndex - todayIndex
        return Calendar.current.date(byAdding: .day, value: dayDifference, to: today)!
    }

    var body: some View {
        ZStack {
            // Card background with layered rounded rectangles for depth
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    isToday
                        ? AnyShapeStyle(LinearGradient(colors: [Theme.accentColor.opacity(0.18), Theme.accentColor.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(Theme.secondaryBackgroundColor)
                )
                 .shadow(color: Color.black.opacity(0.14), radius: isToday ? 10 : 6, x: 0, y: 4)

            VStack(spacing: 8) {
                // Header strip with weekday and date (smaller)
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(weekdayFormatter.string(from: dateForThisCard))
                            .font(.caption2).bold()
                            .foregroundColor(Theme.secondaryTextColor)
                        Text(dayFormatter.string(from: dateForThisCard))
                            .font(.headline).bold()
                            .foregroundColor(Theme.textColor)
                    }
                    .padding(.leading, 14)

                    Spacer()

                    // Small tag for today's plan or planned label
                    if isToday {
                        Text("Today")
                            .font(.caption2).bold()
                            .padding(.vertical, 5).padding(.horizontal, 10)
                            .background(Theme.accentColor)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .padding(.trailing, 12)
                    } else {
                        Text("Planned")
                            .font(.caption2).bold()
                            .padding(.vertical, 5).padding(.horizontal, 10)
                            .background(Color.white.opacity(0.04))
                            .foregroundColor(Theme.secondaryTextColor)
                            .clipShape(Capsule())
                            .padding(.trailing, 12)
                    }
                }
                .padding(.top, 12)

                // Title and compact subtitle area
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.headline).bold()
                        .foregroundColor(Theme.textColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    HStack(spacing: 8) {
                        Label(workout.duration, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(Theme.secondaryTextColor)
                        Text("•")
                            .foregroundColor(Theme.secondaryTextColor)
                        Text(workout.difficulty)
                            .font(.caption).bold()
                            .foregroundColor(Theme.secondaryTextColor)
                        Spacer()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 2)

                // Small metadata row: show up to 2 exercise names as preview
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Exercises")
                            .font(.caption2).bold()
                            .foregroundColor(Theme.secondaryTextColor)
                        // show first two exercise names if available
                        ForEach(Array(workout.exercises.prefix(2).enumerated()), id: \.offset) { _, ex in
                            Text("• \(ex.name)")
                                .font(.caption)
                                .foregroundColor(Theme.secondaryTextColor)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "bolt.fill").foregroundColor(Theme.accentColor)
                            Text("\(workout.exercises.count)")
                                .font(.caption)
                                .foregroundColor(Theme.secondaryTextColor)
                        }

                        Text(workout.isLowImpact ? "Low impact" : "Standard")
                            .font(.caption2)
                            .foregroundColor(Theme.secondaryTextColor)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)

                Spacer()

                // Action button area (smaller)
                if isCompleted {
                    Text("Completed")
                        .font(.subheadline).bold()
                        .foregroundColor(.white)
                        .frame(height: 40)
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.6))
                        .cornerRadius(10)
                        .padding(.horizontal, 14)
                } else {
                    NavigationLink(destination: ActiveWorkoutView(workout: workout)) {
                        Text(isToday ? "Start" : "View")
                            .font(.subheadline).bold()
                            .foregroundColor(.white)
                            .frame(height: 44)
                            .frame(maxWidth: .infinity)
                            .background(LinearGradient(colors: [Theme.accentColor, Theme.accentColor.opacity(0.85)], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(12)
                            .padding(.horizontal, 14)
                    }
                }

                // Lottie completion animation (smaller)
                if isCompleted {
                    LottieView(filename: "success_check", play: $playCompletionAnimation)
                        .frame(width: 72, height: 72)
                        .allowsHitTesting(false)
                        .padding(.bottom, 6)
                }

                Spacer().frame(height: 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 260, height: 340)
        .padding(.vertical, 6)
    }
}

struct HistoryRowView: View {
    let log: WorkoutLog

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(log.name)
                    .font(.headline)
                    .foregroundColor(Theme.textColor)
                Text("\(log.duration) - \(dateFormatter.string(from: log.date))")
                    .font(.subheadline)
                    .foregroundColor(Theme.secondaryTextColor)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(Theme.accentColor)
        }
        .padding()
        .background(Theme.secondaryBackgroundColor)
        .cornerRadius(12)
    }
}

// MARK: - Preview
#Preview {
    WorkoutView().preferredColorScheme(.dark).environmentObject(DiaryViewModel(isForPreview: true))
}
