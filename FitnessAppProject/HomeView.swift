import SwiftUI
import Charts

// --- Data Models for the Redesigned Dashboard ---
struct DailyMetric: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let iconName: String
    let progress: Double
    let goal: Double
    let unit: String
    let color: Color
}

struct HomeView: View {
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    @StateObject private var healthManager = HealthStoreManager()
    
    // --- DAILY GOALS & PROGRESS ---
    private let calorieGoal: Double = 2000
    private let proteinGoal: Double = 100
    private let waterGoal: Double = 8
    private let stepGoal: Double = 10000
    
    private var dailyMetrics: [DailyMetric] {
        let totalCaloriesToday = diaryViewModel.fetchEntries(for: Date()).reduce(0) { $0 + Double($1.calories) }
        let totalProteinToday = diaryViewModel.fetchEntries(for: Date()).reduce(0) { $0 + $1.protein }
        
        return [
            .init(name: "Steps", iconName: "figure.walk.circle.fill", progress: healthManager.dailySteps, goal: stepGoal, unit: "steps", color: .blue),
            .init(name: "Calorie Intake", iconName: "flame.circle.fill", progress: totalCaloriesToday, goal: calorieGoal, unit: "kcal", color: .cyan),
            .init(name: "Protein Intake", iconName: "bolt.circle.fill", progress: totalProteinToday, goal: proteinGoal, unit: "g", color: .purple),
            .init(name: "Water Intake", iconName: "drop.circle.fill", progress: healthManager.dailyWaterIntake, goal: waterGoal, unit: "glasses", color: .green)
        ]
    }
    
    // This now calculates a Readiness Score from live HealthKit data
    private var readinessScore: Double {
        let hrvScore = min(healthManager.hrv / 70.0, 1.0) * 50 // Normalized to a typical healthy range
        let rhrScore = (1 - min((healthManager.restingHeartRate - 40) / 50, 1.0)) * 50 // Normalized
        let score = hrvScore + rhrScore
        return max(0, min(100, score))
    }
    
    // --- THIS IS THE FIX: Full implementation for weeklyCalorieData ---
    private var weeklyCalorieData: [DailyAnalyticsData] {
        var data: [DailyAnalyticsData] = []
        for i in (0..<7).reversed() {
            if let date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) {
                let totalCalories = diaryViewModel.fetchEntries(for: date).reduce(0) { $0 + Double($1.calories) }
                data.append(DailyAnalyticsData(date: date, value: totalCalories))
            }
        }
        return data
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.backgroundColor.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 25) {
                        
                        greetingView.padding(.horizontal)
                        
                        // --- The Main Dashboard Card ---
                        VStack {
                            HStack(spacing: 20) {
                                ConcentricProgressView(metrics: dailyMetrics)
                                    .frame(width: 150, height: 150)
                                
                                VStack(spacing: 15) {
                                    ForEach(dailyMetrics) { metric in
                                        MetricProgressRow(metric: metric)
                                    }
                                }
                            }
                            AnalyticsGraph(data: weeklyCalorieData, color: .blue, timeRange: .weekly)
                                .frame(height: 60)
                                .padding(.top, 10)
                        }
                        .padding()
                        .background(Theme.secondaryBackgroundColor)
                        .cornerRadius(20)
                        .padding(.horizontal)
                        
                        // --- The "Recovery" Section ---
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Your Recovery")
                                .font(.title2).bold()
                                .foregroundColor(Theme.textColor)
                            
                            // This view is now powered by live, functional data
                            RecoveryView(
                                readinessScore: readinessScore,
                                restingHeartRate: Int(healthManager.restingHeartRate),
                                hrv: Int(healthManager.hrv),
                                sleepDuration: healthManager.sleepDurationString
                            )
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                healthManager.requestAuthorization()
            }
        }
        .accentColor(Theme.accentColor)
    }
    
    // --- THIS IS THE FIX: Full implementation for greetingView ---
    private var greetingView: some View {
        VStack(alignment: .leading) {
            Text("Welcome Back,")
                .font(.headline)
                .foregroundColor(Theme.secondaryTextColor)
            Text(diaryViewModel.userProfile?.name ?? "User")
                .font(.largeTitle).bold()
                .foregroundColor(Theme.textColor)
            
            if let goal = diaryViewModel.userProfile?.goal {
                Text("Your focus is: \(goal)")
                    .font(.subheadline)
                    .foregroundColor(Theme.accentColor)
                    .bold()
                    .padding(.top, 1)
            }
        }
    }
}

// --- THIS IS THE FIX: Full implementation for all helper views ---

struct ConcentricProgressView: View {
    let metrics: [DailyMetric]
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                 Circle()
                    .stroke(Theme.backgroundColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 150 - CGFloat(index * 28), height: 150 - CGFloat(index * 28))
            }
            
            ForEach(Array(metrics.enumerated()), id: \.offset) { index, metric in
                Circle()
                    .trim(from: 0, to: isAnimating ? (metric.progress / metric.goal) : 0)
                    .stroke(metric.color.gradient, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 150 - CGFloat(index * 28), height: 150 - CGFloat(index * 28))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.8, dampingFraction: 0.8).delay(Double(index) * 0.1), value: isAnimating)
            }
        }
        .padding(14)
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
    }
}

struct MetricProgressRow: View {
    let metric: DailyMetric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                ZStack {
                    Circle().fill(metric.color.opacity(0.2))
                    Image(systemName: metric.iconName).foregroundColor(metric.color)
                }
                .frame(width: 30, height: 30)
                
                Text(metric.name)
                    .font(.headline)
                    .foregroundColor(Theme.textColor)
            }
            
            HStack {
                ProgressView(value: metric.progress, total: metric.goal)
                    .tint(metric.color)
                Text("\(Int(metric.progress)) / \(Int(metric.goal))")
                    .font(.caption)
                    .foregroundColor(Theme.secondaryTextColor)
            }
        }
    }
}

struct RecoveryView: View {
    let readinessScore: Double
    let restingHeartRate: Int
    let hrv: Int
    let sleepDuration: String
    
    private var readinessMessage: String {
        switch readinessScore {
        case 85...:
            return "You're at your peak! Your body is fully recovered and ready for a challenging workout."
        case 65..<85:
            return "You're well-rested and ready to perform. Aim for a high-intensity workout today."
        case 40..<65:
            return "You're moderately recovered. A standard workout is fine, but listen to your body."
        default:
            return "Your body needs more rest. Consider a light activity like walking or stretching today."
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                ReadinessGaugeView(score: readinessScore)
                    .frame(width: 120, height: 120)
                VStack(alignment: .leading) {
                    Text("Readiness Goal").font(.headline).bold().foregroundColor(Theme.textColor)
                    Text(readinessMessage).font(.subheadline).foregroundColor(Theme.secondaryTextColor)
                }
            }
            Divider()
            HStack {
                HealthMetricView(iconName: "heart.fill", value: "\(restingHeartRate)", label: "Resting HR", color: .red)
                Spacer()
                HealthMetricView(iconName: "waveform.path.ecg", value: "\(hrv) ms", label: "HRV", color: .blue)
                Spacer()
                HealthMetricView(iconName: "bed.double.fill", value: sleepDuration, label: "Sleep", color: .purple)
            }
        }.padding().background(Theme.secondaryBackgroundColor).cornerRadius(20)
    }
}

struct ReadinessGaugeView: View {
    let score: Double
    private var scoreColor: Color {
        switch score {
        case 0..<50: return .red
        case 50..<75: return .orange
        default: return .green
        }
    }
    
    var body: some View {
        ZStack {
            Circle().stroke(Theme.backgroundColor, lineWidth: 12)
            Circle()
                .trim(from: 0, to: score / 100)
                .stroke(scoreColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut, value: score)
            VStack {
                Text("\(Int(score))%").font(.title).bold().foregroundColor(Theme.textColor)
                Text("Ready").font(.caption).foregroundColor(Theme.secondaryTextColor)
            }
        }
    }
}

struct HealthMetricView: View {
    let iconName: String, value: String, label: String, color: Color
    
    var body: some View {
        VStack {
            ZStack {
                Circle().fill(color.opacity(0.2))
                Image(systemName: iconName).foregroundColor(color)
            }.frame(width: 40, height: 40)
            Text(value).font(.headline).bold().foregroundColor(Theme.textColor)
            Text(label).font(.caption).foregroundColor(Theme.secondaryTextColor)
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.light)
        .environmentObject(DiaryViewModel(isForPreview: true))
}

