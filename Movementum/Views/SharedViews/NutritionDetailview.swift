import SwiftUI

// An enum to specify which nutrient we are viewing. This makes the view reusable.
enum NutritionType {
    case calories
    case protein
    
    var title: String {
        switch self {
        case .calories: return "Calories"
        case .protein: return "Protein"
        }
    }
    
    var unit: String {
        switch self {
        case .calories: return "kcal"
        case .protein: return "g"
        }
    }
}

struct NutritionDetailView: View {
    // This view receives the list of foods for the day and the type of nutrient to display.
    let entries: [FoodEntry]
    let type: NutritionType
    
    // A computed property to calculate the total value for the displayed nutrient
    private var totalValue: Double {
        entries.reduce(0) { sum, entry in
            switch type {
            case .calories: return sum + Double(entry.calories)
            case .protein: return sum + entry.protein
            }
        }
    }

    var body: some View {
        ZStack {
            // Use the new adaptive background color
            Theme.backgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack {
                List {
                    Section(header: Text("Today's Entries").foregroundColor(Theme.secondaryTextColor)) {
                        if entries.isEmpty {
                            Text("No entries have been logged for today yet.")
                                .foregroundColor(Theme.secondaryTextColor)
                        } else {
                            // Loop through each food entry and display its details
                            ForEach(entries) { entry in
                                HStack {
                                    Text(entry.name)
                                        .foregroundColor(Theme.textColor)
                                    Spacer()
                                    // Display the correct value and unit based on the type
                                    switch type {
                                    case .calories:
                                        Text("\(entry.calories) \(type.unit)")
                                            .foregroundColor(Theme.secondaryTextColor)
                                    case .protein:
                                        Text("\(String(format: "%.1f", entry.protein)) \(type.unit)")
                                            .foregroundColor(Theme.secondaryTextColor)
                                    }
                                }
                            }
                        }
                    }
                    .listRowBackground(Theme.secondaryBackgroundColor)
                    
                    // A separate section to display the total
                    Section {
                         HStack {
                            Text("Total")
                                .font(.headline)
                                .foregroundColor(Theme.textColor)
                            Spacer()
                            switch type {
                            case .calories:
                                Text("\(Int(totalValue)) \(type.unit)")
                                    .font(.headline)
                                    .foregroundColor(Theme.accentColor)
                            case .protein:
                                Text("\(String(format: "%.1f", totalValue)) \(type.unit)")
                                    .font(.headline)
                                    .foregroundColor(Theme.accentColor)
                            }
                        }
                    }
                    .listRowBackground(Theme.secondaryBackgroundColor)
                }
                .scrollContentBackground(.hidden)
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Today's \(type.title)")
        .navigationBarTitleDisplayMode(.inline)
        // The .colorScheme(.dark) modifier has been removed to allow automatic adaptation.
    }
}


#Preview {
    let previewViewModel = DiaryViewModel(isForPreview: true)
    
    // This preview now correctly shows the light theme
    return NavigationView {
        NutritionDetailView(entries: previewViewModel.fetchEntries(for: Date()), type: .calories)
            .preferredColorScheme(.light)
    }
}

