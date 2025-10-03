import SwiftUI
import FirebaseAuth

// --- Enums to manage the state of the analytics filters ---
enum AnalyticsMetric: String, CaseIterable, Identifiable {
    case calories = "Kcal"
    case protein = "Protein"
    case workouts = "Workouts"
    var id: String { self.rawValue }
}

enum AnalyticsTimeRange: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    var id: String { self.rawValue }
}


struct ProfileView: View {
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    @EnvironmentObject var appState: AppState
    
    @State private var isShowingSettingsView = false
    
    // --- State variables to control the analytics filters ---
    @State private var selectedMetric: AnalyticsMetric = .calories
    @State private var selectedTimeRange: AnalyticsTimeRange = .weekly

    // This property prepares the data for the graph
    private var analyticsData: [DailyAnalyticsData] {
        var data: [DailyAnalyticsData] = []
        let numberOfDays = selectedTimeRange == .weekly ? 7 : 30
        
        for i in (0..<numberOfDays).reversed() {
            if let date = Calendar.current.date(byAdding: .day, value: -i, to: Date()) {
                var dailyValue: Double = 0
                switch selectedMetric {
                case .calories:
                    dailyValue = diaryViewModel.fetchEntries(for: date).reduce(0) { $0 + Double($1.calories) }
                case .protein:
                    dailyValue = diaryViewModel.fetchEntries(for: date).reduce(0) { $0 + $1.protein }
                case .workouts:
                    dailyValue = Double(diaryViewModel.fetchWorkoutLogs(for: date).count)
                }
                data.append(DailyAnalyticsData(date: date, value: dailyValue))
            }
        }
        return data
    }
    
    private var averageValue: Double {
        let total = analyticsData.reduce(0) { $0 + $1.value }
        let count = analyticsData.filter { $0.value > 0 }.count
        return total > 0 ? total / Double(count) : 0
    }
    
    private var graphColor: Color {
        switch selectedMetric {
        case .calories: return Theme.calorieColor
        case .protein: return .red
        case .workouts: return .blue
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.backgroundColor.edgesIgnoringSafeArea(.all)
                
                if let profile = diaryViewModel.userProfile {
                    profileContent(for: profile)
                } else {
                    ProgressView().progressViewStyle(CircularProgressViewStyle())
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { isShowingSettingsView = true }) {
                        Image(systemName: "gearshape.fill")
                    }
                    .foregroundColor(Theme.accentColor)
                }
                ToolbarItem(placement: .principal) {
                    Text("Profile").bold().foregroundColor(Theme.textColor)
                }
            }
            .sheet(isPresented: $isShowingSettingsView) {
                SettingsView()
            }
        }
    }
    
    private func profileContent(for profile: UserProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                
                ProfileHeaderView(profile: profile)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    StatCard(iconName: "birthday.cake.fill", value: "\(calculateAge(from: profile.dob))", label: "Years")
                    StatCard(iconName: "ruler.fill", value: "\(Int(profile.height))", label: "cm")
                    StatCard(iconName: "scalemass.fill", value: "\(String(format: "%.1f", profile.weight))", label: "kg")
                }
                .padding(.horizontal)
                
                GoalCardView(goal: profile.goal)
                    .padding(.horizontal)
                
                VStack(alignment: .leading) {
                    GraphHeaderView(
                        averageValue: averageValue,
                        selectedMetric: $selectedMetric,
                        selectedTimeRange: $selectedTimeRange,
                        color: graphColor
                    )
                    
                    AnalyticsGraph(data: analyticsData, color: graphColor, timeRange: selectedTimeRange)
                        .frame(height: 150)
                }
                .padding()
                .background(Theme.secondaryBackgroundColor)
                .cornerRadius(20)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 20)
        }
    }
    
    private func calculateAge(from dob: Date) -> Int {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: dob, to: Date())
        return ageComponents.year ?? 0
    }
}

// --- THIS IS THE FIX: Full implementation for all helper views ---

struct ProfileHeaderView: View {
    let profile: UserProfile
    
    private var initials: String {
        profile.name.components(separatedBy: " ").map { $0.first! }.map(String.init).joined()
    }
    
    private var goalColor: Color {
        // We need GoalType here to check against the string
        enum TempGoalType: String {
            case strengthGain = "Strength Gain"
            case weightLoss = "Weight Loss"
        }
        
        if profile.goal == TempGoalType.strengthGain.rawValue {
            return .red
        } else if profile.goal == TempGoalType.weightLoss.rawValue {
            return .orange
        } else {
            return Theme.accentColor
        }
    }
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle().fill(goalColor.gradient)
                Text(initials).font(.largeTitle).fontWeight(.bold).foregroundColor(.white)
            }
            .frame(width: 80, height: 80)
            
            VStack(alignment: .leading) {
                Text(profile.name).font(.largeTitle).bold().foregroundColor(Theme.textColor)
                Text("EvolveFit Member").font(.subheadline).foregroundColor(Theme.secondaryTextColor)
            }
            Spacer()
        }
        .padding(.horizontal)
    }
}

struct StatCard: View {
    let iconName: String, value: String, label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName).font(.title).foregroundColor(Theme.accentColor)
            Text(value).font(.title2).bold().foregroundColor(Theme.textColor)
            Text(label).font(.caption).foregroundColor(Theme.secondaryTextColor)
        }
        .padding().frame(maxWidth: .infinity).background(Theme.secondaryBackgroundColor).cornerRadius(15)
    }
}

struct GoalCardView: View {
    let goal: String
    var body: some View {
        VStack(alignment: .leading) {
            Text("Your Primary Goal").font(.headline).foregroundColor(Theme.secondaryTextColor)
            Text(goal).font(.title2).bold().foregroundColor(Theme.textColor)
        }.frame(maxWidth: .infinity, alignment: .leading).padding().background(Theme.secondaryBackgroundColor).cornerRadius(15)
    }
}

struct GraphHeaderView: View {
    let averageValue: Double
    @Binding var selectedMetric: AnalyticsMetric
    @Binding var selectedTimeRange: AnalyticsTimeRange
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(selectedTimeRange.rawValue) Average")
                    .font(.headline).foregroundColor(Theme.secondaryTextColor)
                Spacer()
                Menu {
                    ForEach(AnalyticsMetric.allCases) { metric in Button(metric.rawValue) { selectedMetric = metric } }
                } label: { FilterButtonLabel(title: selectedMetric.rawValue) }
                Menu {
                    ForEach(AnalyticsTimeRange.allCases) { range in Button(range.rawValue) { selectedTimeRange = range } }
                } label: { FilterButtonLabel(title: selectedTimeRange.rawValue) }
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text(selectedMetric == .workouts ? "\(Int(averageValue))" : "\(String(format: "%.1f", averageValue))")
                    .font(.system(size: 48, weight: .bold)).foregroundColor(color)
                Text(selectedMetric.rawValue).font(.title2).bold().foregroundColor(color)
                Spacer()
            }
        }
    }
}

struct FilterButtonLabel: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
            Image(systemName: "chevron.down")
        }
        .font(.subheadline).bold()
        .foregroundColor(Theme.secondaryTextColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.backgroundColor.opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(Theme.secondaryTextColor.opacity(0.5), lineWidth: 1)
        )
    }
}

#Preview {
    let previewViewModel = DiaryViewModel(isForPreview: true)
    
    return ProfileView()
        .preferredColorScheme(.light)
        .environmentObject(previewViewModel)
        .environmentObject(AppState())
}

