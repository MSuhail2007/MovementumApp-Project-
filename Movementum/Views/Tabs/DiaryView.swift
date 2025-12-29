import SwiftUI
import PhotosUI
import GoogleGenerativeAI // Re-added the Google AI library

// An Identifiable struct to safely pass the meal type to the sheet.
struct MealSheetIdentifier: Identifiable {
    let id: String
}

struct DiaryView: View {
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    
    @State private var selectedDate = Date()
    @State private var selectedMealIdentifier: MealSheetIdentifier?
    @State private var scanningMealType: String? // Added state to remember which meal initiated the scan
    
    // --- SCANNER FUNCTIONALITY ---
    @State private var selectedImage: UIImage?
    @State private var isGalleryPickerShowing = false
    @State private var isCameraPickerShowing = false
    @State private var isAnalyzing = false
    @State private var nutritionInfo: NutritionInfo?
    @State private var analysisError: AnalysisError?
    
    // --- The app now uses the Gemini service ---
    private let geminiService = GeminiService()
    private let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snacks"]

    var body: some View {
        NavigationView {
            ZStack {
                Theme.backgroundColor.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // --- Removed the Scanner Buttons HStack here as per instructions ---
                    
                    // --- The Compact Date Selector ---
                    CompactDateSelectorView(selectedDate: $selectedDate)
                    
                    // --- List of Diary Entries ---
                    List {
                        let workoutLogs = diaryViewModel.fetchWorkoutLogs(for: selectedDate)
                        if !workoutLogs.isEmpty {
                            Section(header: headerView(title: "Workouts", icon: "figure.walk.circle.fill")) {
                                ForEach(workoutLogs) { log in
                                    WorkoutLogRowView(log: log)
                                }
                            }
                        }
                        
                        ForEach(mealTypes, id: \.self) { mealType in
                            let entriesForMeal = diaryViewModel.fetchEntries(for: selectedDate, mealType: mealType)
                            Section(header: mealHeaderView(mealType: mealType, entries: entriesForMeal)) {
                                if entriesForMeal.isEmpty {
                                    Text("No entries yet.")
                                        .foregroundColor(Theme.secondaryTextColor)
                                } else {
                                    ForEach(entriesForMeal) { entry in
                                        FoodEntryRow(entry: entry)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .background(Theme.backgroundColor)
                    .scrollContentBackground(.hidden)
                }
                
                // The loading overlay for the scanner
                if isAnalyzing {
                    Color.black.opacity(0.7).edgesIgnoringSafeArea(.all)
                    VStack {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: Theme.textColor)).scaleEffect(2)
                        Text("Analyzing").foregroundColor(Theme.textColor).font(.title2).bold().padding(.top)
                    }
                }
            }
            .navigationTitle("Diary & Scanner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Diary & Scanner").bold().foregroundColor(Theme.textColor)
                }
            }
        }
        // --- All the necessary sheet modifiers ---
        .sheet(isPresented: $isGalleryPickerShowing) { ImagePicker(selectedImage: $selectedImage) }
        .fullScreenCover(isPresented: $isCameraPickerShowing) { CameraPicker(selectedImage: $selectedImage).ignoresSafeArea() }
        .sheet(item: $nutritionInfo) { info in
            NutritionInfoView(info: info, preselectedMealType: scanningMealType).environmentObject(diaryViewModel)
        }
        .alert(item: $analysisError) { error in
            Alert(title: Text(error.errorDescription ?? "Error"), message: Text(error.recoverySuggestion ?? "An unknown error occurred."), dismissButton: .default(Text("OK")))
        }
        .sheet(item: $selectedMealIdentifier) { identifier in
            AddMealView(date: selectedDate, mealType: identifier.id).environmentObject(diaryViewModel)
        }
        .onChange(of: selectedImage) {
            if selectedImage != nil { analyzeSelectedImage() }
        }
    }
    
    // --- This function now calls the Gemini service ---
    private func analyzeSelectedImage() {
        guard let image = selectedImage else { return }
        isAnalyzing = true
        Task {
            let result = await geminiService.analyze(image: image)
            isAnalyzing = false
            switch result {
            case .success(let info):
                self.selectedImage = nil
                self.nutritionInfo = info
                // Keep current scanningMealType unchanged on success
            case .failure(let error):
                self.scanningMealType = nil
                self.analysisError = error
            }
        }
    }
    
    private func headerView(title: String, icon: String) -> some View {
        HStack { Image(systemName: icon); Text(title) }.foregroundColor(Theme.textColor).font(.headline)
    }
    
    private func mealHeaderView(mealType: String, entries: [FoodEntry]) -> some View {
        HStack(spacing: 12) {
            Text(mealType)
            Spacer()
            if Calendar.current.isDateInToday(selectedDate) {
                // Per-meal scan buttons
                Button(action: {
                    self.scanningMealType = mealType
                    self.isCameraPickerShowing = true
                }) {
                    Image(systemName: "camera.fill")
                }
                .accessibilityLabel("Take Photo for \(mealType)")
                .foregroundColor(Theme.accentColor)

                Button(action: {
                    self.scanningMealType = mealType
                    self.isGalleryPickerShowing = true
                }) {
                    Image(systemName: "photo.fill.on.rectangle.fill")
                }
                .accessibilityLabel("Scan Photo for \(mealType)")
                .foregroundColor(Theme.accentColor)

                Button(action: { self.selectedMealIdentifier = MealSheetIdentifier(id: mealType) }) {
                    Image(systemName: "plus.circle.fill")
                }
                .accessibilityLabel("Add entry to \(mealType)")
                .foregroundColor(Theme.accentColor)
            }
        }
        .foregroundColor(Theme.textColor)
        .font(.headline)
    }
}

// --- ALL HELPER VIEWS AND STRUCTS ARE NOW IN THIS FILE ---

// --- Helper Views for the Compact Date Selector ---
struct CompactDateSelectorView: View {
    @Binding var selectedDate: Date
    
    private var dateRange: [Date] {
        (0..<7).map { day in
            Calendar.current.date(byAdding: .day, value: -day, to: Date())!
        }.reversed()
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(dateRange, id: \.self) { date in
                    DateButton(
                        date: date,
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    ) {
                        withAnimation(.spring()) {
                            selectedDate = date
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

struct DateButton: View {
    let date: Date
    let isSelected: Bool
    let action: () -> Void
    
    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter(); formatter.dateFormat = "EEE"; return formatter
    }
    private var numberFormatter: DateFormatter {
        let formatter = DateFormatter(); formatter.dateFormat = "d"; return formatter
    }
    
    private var label: String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        return dayFormatter.string(from: date)
    }
    
    var body: some View {
        Button(action: action) {
            VStack {
                Text(label.uppercased())
                    .font(.caption).bold()
                
                Text(numberFormatter.string(from: date))
                    .font(.title2).bold()
            }
            .foregroundColor(isSelected ? .white : Theme.textColor)
            .frame(width: 60, height: 70)
            .background(isSelected ? AnyShapeStyle(Theme.accentColor.gradient) : AnyShapeStyle(Theme.secondaryBackgroundColor))
            .cornerRadius(15)
        }
    }
}

struct ScannerButton: View {
    let iconName: String, title: String, action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: iconName).font(.largeTitle)
                Text(title).font(.headline)
            }
            .foregroundColor(Theme.accentColor)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(Theme.secondaryBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }
}

struct WorkoutLogRowView: View {
    let log: WorkoutLog
    var body: some View {
        HStack {
            Image(systemName: "flame.fill").foregroundColor(Theme.calorieColor)
            VStack(alignment: .leading) {
                Text(log.name).font(.headline)
                Text(log.duration).font(.subheadline).foregroundColor(Theme.secondaryTextColor)
            }
        }
    }
}

struct FoodEntryRow: View {
    let entry: FoodEntry
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(entry.name).font(.headline)
                Text("Protein: \(String(format: "%.1f", entry.protein))g").font(.subheadline).foregroundColor(Theme.secondaryTextColor)
            }
            Spacer()
            Text("\(entry.calories) kcal").fontWeight(.medium)
        }
    }
}

struct AddMealView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    let date: Date, mealType: String
    
    // --- THIS IS THE FIX ---
    // Each @State variable is now declared on its own separate line.
    @State private var foodName: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.backgroundColor.edgesIgnoringSafeArea(.all)
                Form {
                    Section(header: Text("Meal Details").foregroundColor(Theme.secondaryTextColor)) {
                        TextField("Food Name", text: $foodName)
                        TextField("Calories (kcal)", text: $calories).keyboardType(.numberPad)
                        TextField("Protein (g)", text: $protein).keyboardType(.decimalPad)
                    }.listRowBackground(Theme.secondaryBackgroundColor)
                }.scrollContentBackground(.hidden)
            }
            .navigationTitle("Add \(mealType)").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text("Add \(mealType)").bold().foregroundColor(Theme.textColor) }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(Theme.accentColor) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveMeal(); dismiss() }
                    .disabled(foodName.isEmpty || calories.isEmpty || protein.isEmpty).foregroundColor(Theme.accentColor)
                }
            }
        }
    }
    private func saveMeal() {
        let entry = FoodEntry(name: foodName, calories: Int(calories) ?? 0, protein: Double(protein) ?? 0.0, mealType: mealType, date: date)
        diaryViewModel.add(entry: entry)
    }
}

struct NutritionInfoView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    let info: NutritionInfo
    let preselectedMealType: String? // Added property as per instructions
    @State private var wasAdded = false
    @State private var isMealTypeSelectorShowing = false
    var body: some View {
        NavigationView {
            ZStack {
                Theme.backgroundColor.edgesIgnoringSafeArea(.all)
                VStack(spacing: 24) {
                    Text(info.dishName).font(.largeTitle).fontWeight(.bold).multilineTextAlignment(.center).foregroundColor(Theme.textColor)
                    VStack(spacing: 16) {
                        NutritionRow(label: "Calories", value: "\(info.calories)", icon: "flame.fill", color: Theme.calorieColor)
                        NutritionRow(label: "Protein", value: "\(String(format: "%.1f", info.protein)) g", icon: "bolt.heart.fill", color: .red)
                        NutritionRow(label: "Fat", value: "\(String(format: "%.1f", info.fat)) g", icon: "drop.fill", color: .yellow)
                    }.padding().background(Theme.secondaryBackgroundColor).cornerRadius(16)
                    Spacer()
                    Button(action: {
                        if let meal = preselectedMealType {
                            addEntryToDiary(mealType: meal)
                        } else {
                            isMealTypeSelectorShowing = true
                        }
                    }) {
                        let title = wasAdded ? "Added to Diary!" : (preselectedMealType != nil ? "Add to Today's \(preselectedMealType!)" : "Add to Today's Diary")
                        Label(title, systemImage: wasAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                            .modifier(ActionButtonStyle())
                    }
                    .disabled(wasAdded)
                    Button(wasAdded ? "Close" : "Done") {
                        dismiss()
                    }
                    .padding(.top, 8)
                    .foregroundColor(Theme.accentColor)
                }.padding()
            }
            .navigationTitle("Nutrition Facts").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text("Nutrition Facts").bold().foregroundColor(Theme.textColor) }
            }
            .confirmationDialog("Add to which meal?", isPresented: $isMealTypeSelectorShowing, titleVisibility: .visible) {
                Button("Breakfast") { addEntryToDiary(mealType: "Breakfast") }
                Button("Lunch") { addEntryToDiary(mealType: "Lunch") }
                Button("Dinner") { addEntryToDiary(mealType: "Dinner") }
                Button("Snacks") { addEntryToDiary(mealType: "Snacks") }
            }
        }
        .onDisappear {
            // cleared in parent via sheet dismissal
        }
    }
    func addEntryToDiary(mealType: String) {
        let entry = FoodEntry(name: info.dishName, calories: info.calories, protein: info.protein, fat: info.fat, carbs: 0.0, mealType: mealType, date: Date())
        diaryViewModel.add(entry: entry)
        wasAdded = true
    }
}

struct NutritionRow: View {
    let label: String, value: String, icon: String, color: Color
    var body: some View {
        HStack {
            Image(systemName: icon).font(.title2).foregroundColor(color).frame(width: 40)
            Text(label).font(.headline)
            Spacer()
            Text(value).font(.title3).fontWeight(.semibold)
        }
    }
}

struct ActionButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content.padding().frame(maxWidth: .infinity).background(Theme.accentColor).foregroundColor(.black).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous)).font(.headline).shadow(color: Theme.accentColor.opacity(0.2), radius: 2, x: 0, y: 2)
    }
}

// --- The service is now GeminiService ---
struct GeminiService {
    func analyze(image: UIImage) async -> Result<NutritionInfo, AnalysisError> {
        // --- ⚠️ PASTE YOUR NEW, FREE GEMINI API KEY HERE ---
        let apiKey = "AIzaSyBUVXxfZy39PpHlWt5eTZxs0-UjX9rvpOM"
        guard apiKey != "YOUR_GEMINI_API_KEY" else { return .failure(.apiKeyNotSet) }
        
        let model = GenerativeModel(name: "gemini-2.5-flash", apiKey: apiKey)
        let prompt = """
        Analyze the dish in this image. You are an expert nutritionist specializing in Indian, particularly South Indian and Tamil, cuisine.
        Identify the main dish using its common local name. Provide your best estimate of its nutritional content.
        Respond ONLY with a valid JSON object matching this structure:
        {"dishName": String, "calories": Int, "protein": Double, "fat": Double}.
        Do not include any markdown formatting, backticks, or any other text outside the JSON object.
        For example, if you see a dosa, respond like this: {"dishName": "Dosa with Sambar", "calories": 250, "protein": 8.5, "fat": 10.2}
        """
        
        do {
            let response = try await model.generateContent(prompt, image)
            guard let rawText = response.text else { return .failure(.responseTextMissing) }
            guard let firstBrace = rawText.firstIndex(of: "{"),
                  let lastBrace = rawText.lastIndex(of: "}") else {
                return .failure(.jsonParsingError(rawText))
            }
            let jsonString = String(rawText[firstBrace...lastBrace])
            guard let jsonData = jsonString.data(using: .utf8) else {
                return .failure(.jsonParsingError(jsonString))
            }
            let nutritionInfo = try JSONDecoder().decode(NutritionInfo.self, from: jsonData)
            return .success(nutritionInfo)
        } catch {
            return .failure(.apiError(error.localizedDescription))
        }
    }
}

// --- Data Models & Errors for the scanner ---
struct NutritionInfo: Codable, Identifiable {
    let id = UUID()
    let dishName: String, calories: Int, protein: Double, fat: Double
    private enum CodingKeys: String, CodingKey { case dishName, calories, protein, fat }
}

enum AnalysisError: Error, LocalizedError, Identifiable {
    var id: String { localizedDescription }
    case apiKeyNotSet, apiError(String), jsonParsingError(String), responseTextMissing
    var errorDescription: String? {
        switch self {
        case .apiKeyNotSet: return "API Key Not Set"
        case .apiError: return "Analysis Failed"
        case .jsonParsingError: return "Response Error"
        case .responseTextMissing: return "Empty Response"
        }
    }
    var recoverySuggestion: String? {
        switch self {
        case .apiKeyNotSet: return "Please paste your Gemini API key in DiaryView.swift."
        case .apiError(let msg): return "The request failed. Check your internet connection.\n\nDetails: \(msg)"
        case .jsonParsingError(let raw): return "Could not understand the data from the server.\n\nResponse: \(raw)"
        case .responseTextMissing: return "The API returned an empty response."
        }
    }
}

// --- UIKit Image Pickers ---
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage { parent.selectedImage = image }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.delegate = context.coordinator; picker.sourceType = .camera; return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage { parent.selectedImage = image }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}


#Preview {
    DiaryView()
        .preferredColorScheme(.dark)
        .environmentObject(DiaryViewModel(isForPreview: true))
}
