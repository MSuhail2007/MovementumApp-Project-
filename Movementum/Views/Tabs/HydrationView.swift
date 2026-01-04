import SwiftUI

struct HydrationView: View {
    @EnvironmentObject var healthManager: HealthStoreManager
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("waterIntakeGoal") private var waterIntakeGoal: Int = 2500
    
    @State private var selectedAmount: Double = 300
    @State private var isLogging = false
    @State private var showErrorAlert = false
    @State private var errorMessage: String?
    
    private var progressFraction: Double {
        guard waterIntakeGoal > 0 else { return 0 }
        return min(1.0, healthManager.dailyWaterIntake / Double(waterIntakeGoal))
    }
    
    private let amountOptions: [Double] = [100, 200, 300, 400, 500]
    
    var body: some View {
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Button(action: { presentationMode.wrappedValue.dismiss() }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(Theme.textColor)
                                .padding()
                                .glassEffect()
                                
                        }
                        Spacer()
                        Text("Hydration")
                            .font(.headline)
                            .foregroundColor(Theme.textColor)
                        Spacer()
                        // Placeholder to keep title centered
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 36, height: 36)
                    }
                    .padding(.horizontal)

                    // Circular progress
                    ZStack {
                        Circle()
                            .stroke(Theme.pillBorder, lineWidth: 18)
                            .frame(width: 220, height: 220)
                        Circle()
                            .trim(from: 0, to: progressFraction)
                            .stroke(LinearGradient(colors: [Color.blue, Color.blue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 220, height: 220)
                            .animation(.easeOut(duration: 0.4), value: healthManager.dailyWaterIntake)

                        VStack(spacing: 6) {
                            Text("Drink Target")
                                .font(.caption)
                                .foregroundColor(Theme.secondaryTextColor)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(healthManager.dailyWaterIntake))")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(Color.blue)
                                Text("/\(waterIntakeGoal)ml")
                                    .font(.subheadline)
                                    .foregroundColor(Theme.secondaryTextColor)
                            }
                        }
                    }
                    .padding(.top)

                    // Amount selector
                    // Slider-based amount selector (replaces buttons)
                    VStack(spacing: 12) {
                        // Large numeric display similar to provided design
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(Int(selectedAmount))")
                                .font(.system(size: 64, weight: .bold))
                                .foregroundColor(Color.blue)
                            Text("ml")
                                .font(.title3)
                                .foregroundColor(Theme.secondaryTextColor)
                        }

                        // Visual track background with the system Slider overlaid
                        ZStack {
                            Capsule()
                                .fill(Theme.secondaryBackgroundColor)
                                .frame(height: 10)
                            Slider(value: $selectedAmount, in: 50...1000, step: 50)
                                .accentColor(Color.white)
                        }
                        .padding(.horizontal)
                    }

                    // Log button
                    Button(action: logSelectedAmount) {
                        HStack {
                            if isLogging {
                                ProgressView()
                                    // The tint will be automatic
                            }
                            Text("Add")
                                .bold()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 25))
                        .padding(.horizontal)
                    }
                    .disabled(isLogging)

                    // Today's record list
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Today's Record")
                            .font(.headline)
                            .foregroundColor(Theme.textColor)
                            .padding(.horizontal)

                        if healthManager.waterLogEntries.isEmpty {
                            Text("No water logged yet.")
                                .foregroundColor(Theme.secondaryTextColor)
                                .font(.caption)
                                .padding(.horizontal)
                        } else {
                            ForEach(healthManager.waterLogEntries) { entry in
                                HStack {
                                    // Compact numeric badge replacing the cup icon
                                    VStack(spacing: 2) {
                                        Text("\(Int(entry.amountML))")
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(Theme.textColor)
                                        Text("ml")
                                            .font(.caption2)
                                            .foregroundColor(Theme.secondaryTextColor)
                                    }
                                    .padding(8)
                                    .background(Color.blue.gradient)
                                    .cornerRadius(20)
                                    
                                    VStack(alignment: .leading) {
                                        Text(entry.date, style: .time)
                                            .font(.body)
                                            .foregroundColor(Theme.textColor)
                                        Text("Logged")
                                            .font(.caption)
                                            .foregroundColor(Theme.secondaryTextColor)
                                    }
                                    Spacer()
                                    Button(action: {
                                        delete(entry: entry)
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(Theme.accent)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .glassEffect()
                            }
                        }
                    }
                    .padding(.top, max(geo.safeAreaInsets.top, 12) + 8)
                    .padding(.bottom, geo.safeAreaInsets.bottom)
                }
            }
         }
         .onAppear {
             healthManager.fetchTodaysWater()
             healthManager.fetchTodaysWaterSamples()
         }
        // Hide the default navigation back button (there was a smaller system back button + our custom chevron).
         .navigationBarBackButtonHidden(true)
         .alert("Error", isPresented: $showErrorAlert) {
             Button("OK") {}
         } message: {
             Text(errorMessage ?? "Something went wrong")
         }
     }
    
    // Small subview extracted to reduce type-check complexity inside the ForEach
    struct AmountOptionButton: View {
        let amount: Double
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: 6) {
                    Text("\(Int(amount))")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? Theme.textColor : Theme.textColor)
                    Text("ml")
                        .font(.caption2)
                        .foregroundColor(Theme.secondaryTextColor)
                }
                .padding(12)
                .frame(minWidth: 64)
                .background(
                    // Use AnyShapeStyle so both branches are the same type
                    isSelected ? AnyShapeStyle(Theme.accent.gradient) : AnyShapeStyle(Theme.secondaryBackgroundColor.opacity(0.4))
                )
                .foregroundColor(isSelected ? Theme.textColor : Theme.textColor)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.pillBorder.opacity(isSelected ? 0.06 : 0.02), lineWidth: 0.5)
                )
            }
        }
    }
    
    // MARK: - Actions
    private func logSelectedAmount() {
        isLogging = true
        healthManager.logWater(amountML: selectedAmount) { error in
            isLogging = false
            if let error = error {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            } else {
                // success — refresh list
                healthManager.fetchTodaysWaterSamples()
            }
        }
    }
    
    private func delete(entry: HealthStoreManager.WaterLogEntry) {
        healthManager.deleteWaterEntry(entry) { error in
            if let error = error {
                errorMessage = error.localizedDescription
                showErrorAlert = true
            } else {
                // removed — list refreshed by manager
            }
        }
    }
}

struct HydrationView_Previews: PreviewProvider {
    static var previews: some View {
        HydrationView()
            .environmentObject(HealthStoreManager())
            .preferredColorScheme(.dark)
    }
}
