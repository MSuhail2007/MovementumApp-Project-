// Replaced with diary UI that supports adding meals (calories/protein/fat/carbs/quantity) and writes nutrients to HealthKit.
import SwiftUI
import UIKit



struct DiaryView: View {
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    @EnvironmentObject var healthManager: HealthStoreManager

    @State private var selectedDate: Date = Date()
    @State private var isPresentingAddMeal = false
    @State private var selectedMealType: String = "Breakfast"

    // Scanner / image picker state
    @State private var isShowingImagePicker = false
    @State private var imagePickerSource: UIImagePickerController.SourceType = .camera
    @State private var pickedImage: UIImage? = nil
    @State private var isAnalyzing = false
    @State private var scannedNutrition: NutritionInfo? = nil
    @State private var isShowingScannedResult = false
    @State private var scannedError: String? = nil

    private var today: Date { Date() }
    private var todayStart: Date { Calendar.current.startOfDay(for: today) }
    private func isToday(_ date: Date) -> Bool { Calendar.current.isDate(date, inSameDayAs: today) }
    private func isFuture(_ date: Date) -> Bool { Calendar.current.startOfDay(for: date) > todayStart }

    private var weekDates: [Date] {
        ( -3 ... 3 ).compactMap { offset in
            Calendar.current.date(byAdding: .day, value: offset, to: selectedDate)
        }
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.backgroundGradient.edgesIgnoringSafeArea(.all)

                ScrollView {
                    VStack(spacing: 18) {
                        // Week selector
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(weekDates, id: \ .self) { date in
                                    DateChip(date: date, isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate)) {
                                        withAnimation { selectedDate = date }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 18)
                        }

                        // Single future-date banner (only once)
                        if isFuture(selectedDate) {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .foregroundColor(Theme.accentColor)
                                Text("You can't add entries for future dates. Come back on the selected day to log meals.")
                                    .foregroundColor(Theme.secondaryTextColor)
                                    .font(.subheadline)
                                Spacer()
                            }
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(14)
                            .padding(.horizontal, 16)
                        }

                        // Meal sections
                        VStack(spacing: 20) {
                            MealSection(title: "Breakfast",
                                        entries: diaryViewModel.fetchEntries(for: selectedDate, mealType: "Breakfast"),
                                        onAdd: { openAddForm(meal: "Breakfast") },
                                        onDelete: { id in diaryViewModel.remove(entryID: id) },
                                        canAdd: isToday(selectedDate),
                                        onCamera: { openCamera(meal: "Breakfast") },
                                        onGallery: { openGallery(meal: "Breakfast") },
                                        selectedDate: selectedDate)

                            MealSection(title: "Lunch",
                                        entries: diaryViewModel.fetchEntries(for: selectedDate, mealType: "Lunch"),
                                        onAdd: { openAddForm(meal: "Lunch") },
                                        onDelete: { id in diaryViewModel.remove(entryID: id) },
                                        canAdd: isToday(selectedDate),
                                        onCamera: { openCamera(meal: "Lunch") },
                                        onGallery: { openGallery(meal: "Lunch") },
                                        selectedDate: selectedDate)

                            MealSection(title: "Dinner",
                                        entries: diaryViewModel.fetchEntries(for: selectedDate, mealType: "Dinner"),
                                        onAdd: { openAddForm(meal: "Dinner") },
                                        onDelete: { id in diaryViewModel.remove(entryID: id) },
                                        canAdd: isToday(selectedDate),
                                        onCamera: { openCamera(meal: "Dinner") },
                                        onGallery: { openGallery(meal: "Dinner") },
                                        selectedDate: selectedDate)

                            MealSection(title: "Snacks",
                                        entries: diaryViewModel.fetchEntries(for: selectedDate, mealType: "Snacks"),
                                        onAdd: { openAddForm(meal: "Snacks") },
                                        onDelete: { id in diaryViewModel.remove(entryID: id) },
                                        canAdd: isToday(selectedDate),
                                        onCamera: { openCamera(meal: "Snacks") },
                                        onGallery: { openGallery(meal: "Snacks") },
                                        selectedDate: selectedDate)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 32)
                    }
                }

                // Progress overlay while analyzing
                if isAnalyzing {
                    Color.black.opacity(0.25).edgesIgnoringSafeArea(.all)
                    ProgressView("Analyzing image...")
                        .padding()
                        .background(Theme.surface)
                        .cornerRadius(12)
                        .shadow(radius: 8)
                }
            }
            .navigationBarTitle("Diary & Scanner", displayMode: .inline)
            .sheet(isPresented: $isPresentingAddMeal) {
                AddMealView(date: selectedDate, mealType: selectedMealType)
                    .environmentObject(diaryViewModel)
                    .environmentObject(healthManager)
            }
            .sheet(isPresented: $isShowingImagePicker, onDismiss: didDismissImagePicker) {
                ImagePicker(sourceType: imagePickerSource, selectedImage: $pickedImage, isPresented: $isShowingImagePicker)
            }
            .sheet(isPresented: $isShowingScannedResult) {
                if let info = scannedNutrition {
                    ScannedResultView(image: pickedImage, initialInfo: info, mealType: selectedMealType, date: selectedDate) { newEntry in
                        diaryViewModel.add(entry: newEntry)
                        healthManager.saveFoodEntry(newEntry) { error in
                            if let err = error { print("HealthKit save error: \(err)") }
                        }
                        isShowingScannedResult = false
                    }
                    .environmentObject(diaryViewModel)
                } else {
                    Text("No scanned data")
                }
            }
            .alert("Scan failed", isPresented: Binding<Bool>(get: { scannedError != nil }, set: { if !$0 { scannedError = nil } })) {
                Button("Retry") {
                    // retry the last scan by re-invoking the pipeline
                    Task { await retryLastScan() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(scannedError ?? "Unknown error")
            }
        }
    }

    // MARK: - Actions
    private func openAddForm(meal: String) {
        guard isToday(selectedDate) else { return }
        selectedMealType = meal
        isPresentingAddMeal = true
    }

    private func openCamera(meal: String) {
        guard isToday(selectedDate) else { return }
        selectedMealType = meal
        imagePickerSource = .camera
        isShowingImagePicker = true
    }

    private func openGallery(meal: String) {
        guard isToday(selectedDate) else { return }
        selectedMealType = meal
        imagePickerSource = .photoLibrary
        isShowingImagePicker = true
    }

    private func didDismissImagePicker() {
        guard let img = pickedImage else { return }
        scannedNutrition = nil
        scannedError = nil
        isAnalyzing = true

        Task {
            let result = await GeminiService().analyze(image: img)
            await MainActor.run {
                isAnalyzing = false
                switch result {
                case .success(let info):
                    scannedNutrition = info
                    isShowingScannedResult = true
                case .failure(let err):
                    scannedError = err.localizedDescription
                }
            }
        }
    }

    // Retry helper: re-run the pipeline on the last picked image
    private func retryLastScan() async {
        guard let img = pickedImage else { return }
        await MainActor.run { scannedError = nil; isAnalyzing = true }
        let result = await GeminiService().analyzeUsingOCR(image: img)
        await MainActor.run {
            isAnalyzing = false
            switch result {
            case .success(let info):
                scannedNutrition = info
                isShowingScannedResult = true
            case .failure:
                // still failed; show message
                scannedError = "Retry failed. Try 'Use OCR-only' or check your network/API key."
            }
        }
    }
}

// MARK: - Date Chip
struct DateChip: View {
    let date: Date
    let isSelected: Bool
    let onSelect: () -> Void

    private var dayOfWeek: String {
        let df = DateFormatter()
        df.dateFormat = "EEE"
        return df.string(from: date).uppercased()
    }
    private var dayNumber: String {
        let df = DateFormatter()
        df.dateFormat = "d"
        return df.string(from: date)
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(dayOfWeek).font(.caption).foregroundColor(isSelected ? .white : Theme.secondaryTextColor)
            Text(dayNumber).font(.title2).fontWeight(.bold).foregroundColor(isSelected ? .white : Theme.textColor)
        }
        .frame(width: 68, height: 68)
        .background(Group { if isSelected { Theme.accentGradient } else { Theme.pillBackground } })
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.clear : Theme.pillBorder, lineWidth: 1)
        )
        .shadow(color: isSelected ? Theme.cardShadow.opacity(0.25) : Color.clear, radius: 6, x: 0, y: 6)
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - Meal Section (keeps layout)
struct MealSection: View {
    let title: String
    let entries: [FoodEntry]
    let onAdd: () -> Void
    let onDelete: (UUID) -> Void
    let canAdd: Bool
    let onCamera: () -> Void
    let onGallery: () -> Void
    let selectedDate: Date

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title).font(.headline).foregroundColor(Theme.textColor)
                Spacer()
                HStack(spacing: 12) {
                    Button(action: onCamera) {
                        Image(systemName: "camera.fill")
                            .foregroundColor(canAdd ? Theme.accentColor : Theme.secondaryTextColor.opacity(0.5))
                            .padding(8)
                            .background(Theme.surface)
                            .cornerRadius(8)
                    }
                    .disabled(!canAdd)

                    Button(action: onGallery) {
                        Image(systemName: "photo.on.rectangle")
                            .foregroundColor(canAdd ? Theme.accentColor : Theme.secondaryTextColor.opacity(0.5))
                            .padding(8)
                            .background(Theme.surface)
                            .cornerRadius(8)
                    }
                    .disabled(!canAdd)

                    Button(action: onAdd) {
                        Image(systemName: "plus")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(canAdd ? Theme.accentColor : Theme.pillBackground)
                            .cornerRadius(10)
                    }
                    .disabled(!canAdd)
                }
            }

            if entries.isEmpty {
                HStack {
                    Text("No entries yet.")
                        .foregroundColor(Theme.secondaryTextColor)
                        .padding(.vertical, 18)
                        .padding(.horizontal, 20)
                    Spacer()
                }
                .background(Theme.surface)
                .cornerRadius(20)
                .shadow(color: Theme.softShadow.opacity(0.06), radius: 6, x: 0, y: 4)
            } else {
                VStack(spacing: 8) {
                    ForEach(entries) { entry in
                        FoodEntryRow(entry: entry)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Theme.surface)
                            .cornerRadius(14)
                            .contextMenu {
                                Button(role: .destructive) { onDelete(entry.id) } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
            }
        }
    }
}

struct FoodEntryRow: View {
    let entry: FoodEntry
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(entry.name).font(.headline).foregroundColor(Theme.textColor)
                Text(entry.mealType).font(.subheadline).foregroundColor(Theme.secondaryTextColor)
                HStack(spacing: 12) {
                    Text("Cal: \(entry.calories) kcal").font(.caption).foregroundColor(Theme.secondaryTextColor)
                    Text("P: \(String(format: "%.1f", entry.protein))g").font(.caption).foregroundColor(Theme.secondaryTextColor)
                    Text("F: \(String(format: "%.1f", entry.fat))g").font(.caption).foregroundColor(Theme.secondaryTextColor)
                    Text("C: \(String(format: "%.1f", entry.carbs))g").font(.caption).foregroundColor(Theme.secondaryTextColor)
                    Text("Qty: \(String(format: "%.1f", entry.quantity))").font(.caption).foregroundColor(Theme.secondaryTextColor)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct AddMealView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var diaryViewModel: DiaryViewModel
    @EnvironmentObject var healthManager: HealthStoreManager
    let date: Date, mealType: String

    @State private var foodName: String = ""
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var fat: String = ""
    @State private var carbs: String = ""
    @State private var quantity: String = "1.0"

    var body: some View {
        NavigationView {
            ZStack {
                Theme.backgroundColor.edgesIgnoringSafeArea(.all)
                Form {
                    Section(header: Text("Meal Details").foregroundColor(Theme.secondaryTextColor)) {
                        TextField("Food Name", text: $foodName)
                        TextField("Calories (kcal)", text: $calories).keyboardType(.numberPad)
                        TextField("Protein (g)", text: $protein).keyboardType(.decimalPad)
                        TextField("Fat (g)", text: $fat).keyboardType(.decimalPad)
                        TextField("Carbohydrates (g)", text: $carbs).keyboardType(.decimalPad)
                        TextField("Quantity (g or servings)", text: $quantity).keyboardType(.decimalPad)
                    }
                    .listRowBackground(Theme.secondaryBackgroundColor)
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add \(mealType)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundColor(Theme.accentColor) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveMeal(); dismiss() }
                        .disabled(foodName.isEmpty || calories.isEmpty)
                        .foregroundColor(Theme.accentColor)
                }
            }
        }
    }

    private func saveMeal() {
        let entry = FoodEntry(name: foodName,
                              calories: Int(calories) ?? 0,
                              protein: Double(protein) ?? 0.0,
                              fat: Double(fat) ?? 0.0,
                              carbs: Double(carbs) ?? 0.0,
                              quantity: Double(quantity) ?? 1.0,
                              mealType: mealType,
                              date: date)
        diaryViewModel.add(entry: entry)
        healthManager.saveFoodEntry(entry) { error in
            if let err = error {
                print("Failed to save food entry to HealthKit: \(err)")
            } else {
                print("Saved food entry to HealthKit")
            }
        }
    }
}

// Simple NutritionInfo used by GeminiService and scanner flows
struct NutritionInfo: Identifiable, Codable {
    var id = UUID()
    let dishName: String
    let calories: Int
    let protein: Double
    let fat: Double
}

// Minimal ImagePicker
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = false
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let img = info[.originalImage] as? UIImage { parent.selectedImage = img }
            parent.isPresented = false
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.isPresented = false }
    }
}

// Scanned result editor view
struct ScannedResultView: View {
    @Environment(\.dismiss) var dismiss
    @State var image: UIImage?
    @State var name: String
    @State var calories: String
    @State var protein: String
    @State var fat: String
    let mealType: String
    let date: Date
    let onAdd: (FoodEntry) -> Void

    init(image: UIImage?, initialInfo: NutritionInfo, mealType: String, date: Date, onAdd: @escaping (FoodEntry) -> Void) {
        self._image = State(initialValue: image)
        self._name = State(initialValue: initialInfo.dishName)
        self._calories = State(initialValue: "\(initialInfo.calories)")
        self._protein = State(initialValue: "\(initialInfo.protein)")
        self._fat = State(initialValue: "\(initialInfo.fat)")
        self.mealType = mealType
        self.date = date
        self.onAdd = onAdd
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                if let ui = image { Image(uiImage: ui).resizable().scaledToFit().frame(maxHeight: 240).cornerRadius(12) }
                Form {
                    TextField("Name", text: $name)
                    TextField("Calories", text: $calories).keyboardType(.numberPad)
                    TextField("Protein (g)", text: $protein).keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fat).keyboardType(.decimalPad)
                }
            }
            .navigationTitle("Scanned Result")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let entry = FoodEntry(name: name,
                                              calories: Int(calories) ?? 0,
                                              protein: Double(protein) ?? 0.0,
                                              fat: Double(fat) ?? 0.0,
                                              carbs: 0.0,
                                              quantity: 1.0,
                                              mealType: mealType,
                                              date: date)
                        onAdd(entry)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || calories.isEmpty)
                }
            }
        }
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "E\ndd"
    return formatter
}()
