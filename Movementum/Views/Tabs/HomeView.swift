import SwiftUI
import Charts
import Combine

struct HomeView: View {
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    @EnvironmentObject var healthManager: HealthStoreManager
    @Environment(\.dismiss) var dismiss

    @State private var isShowingHydration = false
    @State private var selectedSegment: Int = 0
    @State private var selectedBarIndex: Int? = nil

    // Use Theme accent instead of local color
    private let accent = Theme.accent

    // Today's totals
    private var todayEntries: [FoodEntry] { diaryViewModel.fetchEntries(for: Date()) }
    private var totalCaloriesToday: Int { todayEntries.reduce(0) { $0 + $1.calories } }
    private var totalProteinToday: Double { todayEntries.reduce(0) { $0 + $1.protein } }
    private var totalFatToday: Double { todayEntries.reduce(0) { $0 + $1.fat } }
    private var totalCarbsToday: Double { todayEntries.reduce(0) { $0 + $1.carbs } }

    // Goals (derived)
    private var calorieGoal: Int { Int(diaryViewModel.calculatedCalorieGoal) }
    private var proteinGoal: Double { diaryViewModel.calculatedProteinGoal }
    private var carbsGoal: Double { (diaryViewModel.calculatedCalorieGoal * 0.5) / 4.0 }
    private var fatGoal: Double { (diaryViewModel.calculatedCalorieGoal * 0.3) / 9.0 }

    var body: some View {
        NavigationView {
            ZStack {
                // Background now uses Theme.backgroundGradient which resolves to pure black/white
                Theme.backgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    // Top navigation (back - title - hydration)
                    HStack {
                        Text("HI! READY TO SMASH ")
                            .font(.title2).bold()
                            .foregroundColor(Theme.textColor)
                        Spacer()
                        Button(action: { isShowingHydration = true }) {
                            Circle()
                                .fill(Theme.surface)
                                .frame(width: 44, height: 44)
                                .overlay(Image(systemName: "drop.fill").foregroundColor(Theme.textColor))
                                .shadow(color: Theme.softShadow, radius: 6, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            // Analytics card
                            BlackAnalyticsCard(totalCalories: totalCaloriesToday,
                                               calorieGoal: calorieGoal,
                                               carbs: totalCarbsToday,
                                               fat: totalFatToday,
                                               protein: totalProteinToday,
                                               carbsGoal: carbsGoal,
                                               fatGoal: fatGoal,
                                               proteinGoal: proteinGoal,
                                               accent: accent)
                                .padding(.horizontal, 16)

                            // Section header
                            HStack {
                                Text("Over view")
                                    .font(.headline)
                                    .foregroundColor(Theme.textColor)
                                
                            }
                            .padding(.horizontal, 16)

                            // 2x2 grid of metric cards
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                                BlackMetricCard(title: "Sleep", subtitle: "Sleeping", value: healthManager.sleepDurationString, accent: Color.blue, detailText: "Sleeping and energy restored")
                                BlackMetricCard(title: "Heart", subtitle: "Resting BPM", value: healthManager.restingHeartRate > 0 ? String(format: "%.0f bpm", healthManager.restingHeartRate) : "--", accent: Color.red, detailText: "Your heart rate is normal")
                                BlackMetricCard(title: "Walks", subtitle: "Today", value: String(format: "%.0f", healthManager.dailySteps), accent: Color.green, detailText: "Steps taken today")
                                BlackMetricCard(title: "Workout", subtitle: "Today", value: diaryViewModel.fetchWorkoutLogs(for: Date()).last?.duration ?? "--", accent: Color.purple, detailText: "Latest workout")
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 80) // Reduced padding so content sits above floating tab bar
                        }
                    }
                }

                // Navigation to hydration
                //NavigationLink(destination: HydrationView(), isActive: $isShowingHydration) { EmptyView() }
            }
            .onAppear { healthManager.requestAuthorization { } }
            .sheet(isPresented: $isShowingHydration) { HydrationView() }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - White analytics card matching the image
struct BlackAnalyticsCard: View {
    let totalCalories: Int
    let calorieGoal: Int
    let carbs: Double
    let fat: Double
    let protein: Double
    let carbsGoal: Double
    let fatGoal: Double
    let proteinGoal: Double
    let accent: Color

    // Safe progress calculation
    private var progress: Double {
        calorieGoal > 0 ? min(Double(totalCalories) / Double(calorieGoal), 1.0) : 0
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // 1. The "Black Board" Background
                RoundedRectangle(cornerRadius: 24)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Theme.pillBorder, lineWidth: 1) // Subtle edge definition
                    )
                    .shadow(color: Theme.cardShadow, radius: 10, x: 0, y: 5)

                VStack(spacing: 20) {
                    // 2. Main Calorie Ring
                    ZStack {
                        // Background Track
                        Circle()
                            .stroke(Theme.pillBorder, lineWidth: 18)
                            .frame(width: 180, height: 180)

                        // Progress Ring
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                AngularGradient(
                                    gradient: Gradient(colors: [Theme.accent, Theme.accentDark]),
                                    center: .center
                                ),
                                style: StrokeStyle(lineWidth: 18, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 180, height: 180)
                            .shadow(color: Theme.accent.opacity(0.3), radius: 10, x: 0, y: 0) // Glow effect

                        // Center Text
                        VStack(spacing: 4) {
                            Text("\(totalCalories)")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundColor(Theme.textColor)
                            
                            Text("KCAL DONE")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Theme.secondaryTextColor)
                                .tracking(1.0) // Spaced out letters
                        }
                    }
                    .padding(.top, 25)

                    // 3. Macro Bars
                    HStack(spacing: 20) {
                        MacroBarBlack(
                            label: "Carbs",
                            value: carbs,
                            goal: carbsGoal,
                            unit: "g",
                            color: Color.cyan
                        )
                        
                        MacroBarBlack(
                            label: "Fat",
                            value: fat,
                            goal: fatGoal,
                            unit: "g",
                            color: Color.yellow
                        )
                        
                        MacroBarBlack(
                            label: "Protein",
                            value: protein,
                            goal: proteinGoal,
                            unit: "g",
                            color: Color.white
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 25)
                }
            }
            .frame(height: 380)
        }
    }
}

// Sub-component for the Macro Bars tailored for the Black theme
struct MacroBarBlack: View {
    let label: String
    let value: Double
    let goal: Double
    let unit: String
    let color: Color
    
    private var progress: Double {
        goal > 0 ? min(value / goal, 1.0) : 0
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Label
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(Theme.secondaryTextColor)
            
            // Vertical Bar
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    // Track
                    Capsule()
                        .fill(Theme.pillBorder)
                        .frame(width: 8)
                    
                    // Fill
                    Capsule()
                        .fill(color)
                        .frame(width: 8, height: geo.size.height * progress)
                        .shadow(color: color.opacity(0.5), radius: 4, x: 0, y: 0) // Neon glow
                }
                .frame(width: 8)
                .frame(maxWidth: .infinity) // Center in the HStack space
            }
            .frame(height: 50)
            
            // Value
            Text("\(Int(value))\(unit)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Theme.textColor)
        }
    }
}
struct MacroBarWhite: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.subheadline).foregroundColor(Theme.textColor)
            Text("\(Int(value))\(unit)").font(.headline).foregroundColor(Theme.textColor)
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.pillBorder).frame(height: 8)
                Capsule().fill(color).frame(width: CGFloat(max(0, min(1, fraction))) * 80, height: 8)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Metric card (white)
struct BlackMetricCard: View {
    let title: String
    let subtitle: String
    let value: String
    let accent: Color
    let detailText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Icon
            HStack(alignment: .center) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.2)) // Slightly stronger opacity for dark mode
                        .frame(width: 40, height: 40)
                    Image(systemName: iconName(for: title))
                        .foregroundColor(accent)
                        .font(.system(size: 18, weight: .bold))
                }
                Spacer()
            }
            
            // Title & Detail
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textColor) // Text color
                
                Text(detailText)
                    .font(.caption)
                    .foregroundColor(Theme.secondaryTextColor) // Gray text for subtle detail
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Dynamic Footer Content
            HStack(alignment: .center, spacing: 12) {
                if title.lowercased() == "sleep" {
                    SleepRingBlack(durationString: value)
                        .frame(width: 50, height: 50)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(value)
                            .font(.title3)
                            .bold()
                            .foregroundColor(Theme.textColor)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(Theme.secondaryTextColor)
                    }
                } else if title.lowercased() == "heart" {
                    HeartSparklineBlack()
                        .frame(width: 60, height: 40)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(value)
                            .font(.title3)
                            .bold()
                            .foregroundColor(Theme.textColor)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(Theme.secondaryTextColor)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(value)
                            .font(.title2)
                            .bold()
                            .foregroundColor(Theme.textColor)
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(Theme.secondaryTextColor)
                    }
                }
                Spacer()
            }
        }
        .padding(16)
        .frame(height: 180) // Slightly taller to breathe
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Theme.pillBorder, lineWidth: 1) // Subtle Border
        )
        // Shadow using Theme
        .shadow(color: Theme.cardShadow, radius: 8, x: 0, y: 4)
    }

    private func iconName(for title: String) -> String {
        switch title.lowercased() {
        case "sleep": return "moon.fill"
        case "heart": return "heart.fill"
        case "walks": return "figure.walk"
        case "workout": return "dumbbell.fill"
        default: return "bolt.fill"
        }
    }
}

// Updated Sleep Ring for Black Background
struct SleepRingBlack: View {
    let durationString: String
    
    private var hours: Double {
        let s = durationString
        if s == "--" { return 0 }
        if let hRange = s.range(of: "h") {
            let prefix = s[..<hRange.lowerBound]
            let trimmed = prefix.trimmingCharacters(in: .whitespaces)
            return Double(trimmed) ?? 0
        }
        let nums = s.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        return Double(nums) ?? 0
    }
    
    private var progress: Double { min(hours/8.0, 1.0) }

    var body: some View {
        ZStack {
            // Darker track
            Circle()
                .stroke(Theme.pillBorder, lineWidth: 5)

            // Bright Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(colors: [Theme.accent, Theme.accentDark], startPoint: .top, endPoint: .bottom),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text(hours >= 1 ? "\(Int(hours))h" : "--")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.textColor)
        }
    }
}

// Updated Sparkline for Black Background
struct HeartSparklineBlack: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                let w = geo.size.width
                let h = geo.size.height
                // Simulated heartbeat path
                p.move(to: CGPoint(x: 0, y: h*0.6))
                p.addLine(to: CGPoint(x: w*0.2, y: h*0.5))
                p.addLine(to: CGPoint(x: w*0.4, y: h*0.75)) // Low dip
                p.addLine(to: CGPoint(x: w*0.5, y: h*0.2))  // High peak
                p.addLine(to: CGPoint(x: w*0.6, y: h*0.6))
                p.addLine(to: CGPoint(x: w*0.8, y: h*0.55))
                p.addLine(to: CGPoint(x: w, y: h*0.5))
            }
            .stroke(
                LinearGradient(colors: [Theme.accent.opacity(0.5), Theme.accent], startPoint: .leading, endPoint: .trailing),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
            )
            .shadow(color: Theme.accent.opacity(0.5), radius: 4, x: 0, y: 0) // Neon Glow
        }
    }
}
// MARK: - Preview
#Preview {
    HomeView()
        .preferredColorScheme(.dark)
        .environmentObject(DiaryViewModel(isForPreview: true))
        .environmentObject(HealthStoreManager())
}
