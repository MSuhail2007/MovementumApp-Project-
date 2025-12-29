import SwiftUI

struct EditStepsView: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("dailyStepsGoal") private var dailyStepsGoal: Int = 10000
    @State private var tempSteps: Int = 10000

    // Formatter for the TextField
    private let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    var body: some View {
        VStack(spacing: 18) {
            // Minimal top bar: only a glass-styled close button
            HStack {
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(Theme.textColor)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding(.trailing, 16)
            }

            // Main card
            VStack(spacing: 16) {
                // Title & subtitle
                VStack(alignment: .center, spacing: 4) {
                    Text("Daily Steps").font(.headline).foregroundColor(Theme.secondaryTextColor)
                    Text("Set a target that keeps you moving").font(.caption).foregroundColor(Theme.secondaryTextColor)
                }

                // Big value
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(tempSteps.formatted(.number))")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textColor)
                    Text("steps").font(.title3).foregroundColor(Theme.secondaryTextColor)
                }

                // Slider for quick adjustment
                VStack {
                    Slider(value: Binding(get: {
                        Double(tempSteps)
                    }, set: { new in
                        let v = Int(new)
                        tempSteps = v
                        dailyStepsGoal = max(0, v)
                    }), in: 1000...100000, step: 500)
                    .tint(Theme.accentColor)
                    .padding(.horizontal, 6)
                    
                    HStack {
                        Text("1k").foregroundColor(Theme.secondaryTextColor).font(.caption)
                        Spacer()
                        Text("200k").foregroundColor(Theme.secondaryTextColor).font(.caption)
                    }
                }

                // Controls row: minus, textfield, plus
                HStack(spacing: 40) {
                    Button(action: { let v = max(0, tempSteps - 500); tempSteps = v; dailyStepsGoal = v }) {
                        Image(systemName: "minus")
                            .foregroundColor(Theme.textColor)
                            .frame(width: 56, height: 56)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }

                    Spacer()

                    Button(action: { let v = tempSteps + 500; tempSteps = v; dailyStepsGoal = v }) {
                        Image(systemName: "plus")
                            .foregroundColor(Theme.textColor)
                            .frame(width: 56, height: 56)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(18)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
            .padding(.horizontal)

            Spacer()

            // Bottom action
            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Text("Save & Close")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.accentColor)
                    .cornerRadius(12)
                    .padding(.horizontal)
            }
            .padding(.bottom, 30)
        }
        .onAppear { tempSteps = dailyStepsGoal }
        .navigationBarHidden(true)
    }
}

#Preview {
    EditStepsView()
        .preferredColorScheme(.dark)
        .environmentObject(DiaryViewModel(isForPreview: true))
}
