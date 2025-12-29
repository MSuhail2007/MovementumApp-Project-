import SwiftUI

// --- This file now contains all the shared, reusable helper views ---

// A reusable style for our text fields
struct ThemedTextFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Theme.secondaryBackgroundColor)
            .cornerRadius(10)
            .foregroundColor(Theme.textColor)
    }
}

// A view for the BMI card display
struct BMICardView: View {
    let bmi: Double
    let category: (String, Color)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your BMI")
                .font(.headline)
                .foregroundColor(Theme.textColor)
            HStack {
                Text(String(format: "%.1f", bmi))
                    .font(.largeTitle).bold()
                    .foregroundColor(category.1)
                
                Text(category.0)
                    .font(.title2).bold()
                    .foregroundColor(category.1)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.secondaryBackgroundColor)
        .cornerRadius(10)
    }
}

// A generic card for displaying information
struct InfoCardView: View {
    let iconName: String
    let iconColor: Color
    let title: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: iconName)
                .font(.largeTitle)
                .foregroundColor(iconColor)
                .padding(.trailing, 10)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline).bold()
                    .foregroundColor(Theme.textColor)
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(Theme.secondaryTextColor)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.secondaryBackgroundColor.opacity(0.5))
        .cornerRadius(20)
    }
}

