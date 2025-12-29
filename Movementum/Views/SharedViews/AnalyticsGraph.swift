import SwiftUI
import Charts // We use Apple's powerful Charts framework

// The main view for rendering the new, smooth line graph
struct AnalyticsGraph: View {
    let data: [DailyAnalyticsData]
    let color: Color
    // The graph now knows which time range is selected
    let timeRange: AnalyticsTimeRange
    
    @State private var animatedData: [DailyAnalyticsData] = []

    var body: some View {
        Chart(animatedData) { dataPoint in
            // The Area and Line marks now plot against the actual Date value
            AreaMark(
                x: .value("Date", dataPoint.date, unit: .day),
                y: .value("Value", dataPoint.value)
            )
            .foregroundStyle(LinearGradient(gradient: Gradient(colors: [color.opacity(0.6), .clear]), startPoint: .top, endPoint: .bottom))
            .interpolationMethod(.catmullRom)

            LineMark(
                x: .value("Date", dataPoint.date, unit: .day),
                y: .value("Value", dataPoint.value)
            )
            .foregroundStyle(color)
            .interpolationMethod(.catmullRom)
            // We can add a symbol back for this animation to emphasize the "pop-in"
            .symbol(Circle().strokeBorder(lineWidth: 2))
        }
        // --- Axis Styling ---
        .chartYAxis { yAxisMarks }
        .chartXAxis { xAxisMarks }
        .chartYScale(domain: 0...((data.map { $0.value }.max() ?? 1) * 1.25))
        .onAppear {
            // Initial animation when the view first appears
            animateGraph()
        }
        .onChange(of: data) {
            // Re-animate the graph whenever the data changes
            animateGraph()
        }
    }
    
    // A helper property for the Y-Axis styling (unchanged)
    @AxisContentBuilder
    private var yAxisMarks: some AxisContent {
        AxisMarks(position: .leading) { value in
            AxisGridLine().foregroundStyle(Theme.secondaryTextColor.opacity(0.3))
            AxisValueLabel {
                if let intValue = value.as(Int.self) {
                    Text("\(intValue)").font(.caption).foregroundColor(Theme.secondaryTextColor)
                }
            }
        }
    }
    
    // The X-Axis now uses the abbreviated format
    @AxisContentBuilder
    private var xAxisMarks: some AxisContent {
        if timeRange == .weekly {
            // This now uses .abbreviated to show "Mon", "Tue", etc.
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                    .foregroundStyle(Theme.textColor)
            }
        } else {
            // For the monthly view, we show a label for every 7 days (e.g., "Sep 4", "Sep 11").
            AxisMarks(values: .stride(by: .day, count: 7)) { value in
                AxisGridLine().foregroundStyle(Color.clear)
                // This format shows both the month and the day number
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                    .foregroundStyle(Theme.textColor)
            }
        }
    }
    
    // --- THIS IS THE NEW "POINT-BY-POINT POP-IN" ANIMATION LOGIC ---
    private func animateGraph() {
        // Start with an empty graph
        animatedData = []
        
        // Loop through the data points and add them one by one with a delay
        for (index, dataPoint) in data.enumerated() {
            // Using a slightly different spring animation creates a more energetic "pop"
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.05)) {
                animatedData.append(dataPoint)
            }
        }
    }
}
