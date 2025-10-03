import SwiftUI
import PhotosUI
import GoogleGenerativeAI

// An Identifiable struct to safely pass the meal type to the sheet.
struct MealSheetIdentifier: Identifiable {
    let id: String
}

struct DiaryView: View {
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    
    @State private var selectedDate = Date()
    @State private var selectedMealIdentifier: MealSheetIdentifier?
    
    // --- SCANNER FUNCTIONALITY IS NOW HERE ---
    @State private var selectedImage: UIImage?
    @State private var isGalleryPickerShowing = false
    @State private var isCameraPickerShowing = false
    @State private var isAnalyzing = false
    @State private var nutritionInfo: NutritionInfo?
    @State private var analysisError: AnalysisError?
    
    private let geminiService = GeminiService()
    private let mealTypes = ["Breakfast", "Lunch", "Dinner", "Snacks"]

    var body: some View {
        NavigationView {
            ZStack {
                Theme.backgroundColor.edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 20) {
                    // --- The New Scanner Buttons ---
                    HStack(spacing: 20) {
                        ScannerButton(iconName: "camera.fill", title: "Take Photo") {
                            isCameraPickerShowing = true
                        }
                        ScannerButton(iconName: "photo.fill.on.rectangle.fill", title: "Scan Photo") {
                            isGalleryPickerShowing = true
                        }
                    }
                    .padding(.horizontal)
                    
                    // --- List of Diary Entries for the Selected Date ---
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
                
                // The new loading overlay for the scanner
                if isAnalyzing {
                    Color.black.opacity(0.7).edgesIgnoringSafeArea(.all)
                    VStack {
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)).scaleEffect(2)
                        Text("Analyzing Food...").foregroundColor(Theme.textColor).font(.title2).bold().padding(.top)
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
            NutritionInfoView(info: info).environmentObject(diaryViewModel)
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
            case .failure(let error):
                self.analysisError = error
            }
        }
    }
    
    private func headerView(title: String, icon: String) -> some View {
        HStack { Image(systemName: icon); Text(title) }.foregroundColor(Theme.textColor).font(.headline)
    }

    private func mealHeaderView(mealType: String, entries: [FoodEntry]) -> some View {
        HStack {
            Text(mealType)
            Spacer()
            Button(action: { self.selectedMealIdentifier = MealSheetIdentifier(id: mealType) }) {
                Image(systemName: "plus.circle.fill").foregroundColor(Theme.accentColor)
            }
        }.foregroundColor(Theme.textColor).font(.headline)
    }
}

// --- ALL HELPER VIEWS AND STRUCTS ARE NOW IN THIS FILE ---

// --- Helper Views for Diary & Scanner ---
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
    // Each @State variable must be declared on its own line.
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
                    Button(action: { isMealTypeSelectorShowing = true }) {
                        Label(wasAdded ? "Added to Diary!" : "Add to Today's Diary", systemImage: wasAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                            .modifier(ActionButtonStyle())
                    }.disabled(wasAdded)
                    Button(wasAdded ? "Close" : "Done") { dismiss() }.padding(.top, 8).foregroundColor(Theme.accentColor)
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
    }
    func addEntryToDiary(mealType: String) {
        let entry = FoodEntry(name: info.dishName, calories: info.calories, protein: info.protein, mealType: mealType, date: Date())
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

// --- Gemini API Service ---
struct GeminiService {
    func analyze(image: UIImage) async -> Result<NutritionInfo, AnalysisError> {
        let apiKey = "AIzaSyAqIf3zb--UXEs6J8vSHrkyhTVxKp4rWMc" // ⚠️ PASTE YOUR KEY HERE
        if apiKey == "YOUR_GEMINI_API_KEY" { return .failure(.apiKeyNotSet) }
        let model = GenerativeModel(name: "gemini-1.5-flash-latest", apiKey: apiKey)
        let prompt = """
        Analyze the dish... Respond ONLY with a valid JSON object...
        {"dishName": String, "calories": Int, "protein": Double, "fat": Double}.
        """
        do {
            let response = try await model.generateContent(prompt, image)
            guard let rawText = response.text else { return .failure(.responseTextMissing) }
            guard let firstBrace = rawText.firstIndex(of: "{"), let lastBrace = rawText.lastIndex(of: "}") else { return .failure(.jsonParsingError(rawText)) }
            let jsonString = String(rawText[firstBrace...lastBrace])
            guard let jsonData = jsonString.data(using: .utf8) else { return .failure(.jsonParsingError(jsonString)) }
            let info = try JSONDecoder().decode(NutritionInfo.self, from: jsonData)
            return .success(info)
        } catch { return .failure(.apiError(error.localizedDescription)) }
    }
}

// --- Data Models & Errors ---
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
        case .apiKeyNotSet: return "Please replace 'YOUR_GEMINI_API_KEY' with your actual Gemini API key."
        case .apiError(let msg): return "The request failed. Check your internet connection.\n\nDetails: \(msg)"
        case .jsonParsingError(let raw): return "Could not understand the data received from the server.\n\nRaw Response: \(raw)"
        case .responseTextMissing: return "The API returned an empty response. Please try again."
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

