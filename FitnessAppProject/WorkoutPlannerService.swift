import Foundation
import GoogleGenerativeAI

// A simple struct to decode the AI's JSON response
struct AIExerciseSelection: Codable {
    let selectedExercises: [String]
}

// This service is the "AI Brain" for creating workout plans.
struct WorkoutPlannerService {
    
    /// Asks the Gemini API to select a specified number of exercises from a provided library.
    /// - Parameters:
    ///   - library: An array of `Exercise` objects that the AI is allowed to choose from.
    ///   - goal: The user's primary goal (e.g., "Build Muscle").
    ///   - count: The number of exercises the AI should select.
    /// - Returns: An array of `Exercise` objects selected by the AI, or an empty array if an error occurs.
    func selectExercises(from library: [Exercise], for goal: String, count: Int) async -> [Exercise] {
        // --- 1. Set up the Gemini Model ---
        // IMPORTANT: You will need to add your Gemini API key here.
        let apiKey = "AIzaSyAqIf3zb--UXEs6J8vSHrkyhTVxKp4rWMc"
        guard apiKey != "YOUR_GEMINI_API_KEY" else {
            print("Error: API Key for WorkoutPlannerService is not set.")
            return []
        }
        let model = GenerativeModel(name: "gemini-1.5-flash-latest", apiKey: apiKey)
        
        // --- 2. Create a list of available exercise names for the prompt ---
        let availableExerciseNames = library.map { $0.name }
        
        // --- 3. Create a very specific prompt for the AI ---
        // We tell it exactly what to do and what format to respond in.
        let prompt = """
        You are a certified fitness planner. Your task is to select \(count) exercises from the following list that are best suited for a user whose goal is to '\(goal)'.
        
        Available Exercises: \(availableExerciseNames.joined(separator: ", "))
        
        Respond ONLY with a valid JSON object that matches this structure:
        {"selectedExercises": [String]}
        
        For example: {"selectedExercises": ["Bench Press", "Squats", "Plank"]}
        Do not include any other text, markdown, or explanations.
        """
        
        // --- 4. Call the API and process the response ---
        do {
            let response = try await model.generateContent(prompt)
            
            guard let rawText = response.text else {
                print("AI response was empty.")
                return []
            }
            
            // Clean the response to find the JSON
            guard let firstBrace = rawText.firstIndex(of: "{"),
                  let lastBrace = rawText.lastIndex(of: "}") else {
                print("Could not find JSON in AI response: \(rawText)")
                return []
            }
            let jsonString = String(rawText[firstBrace...lastBrace])
            
            // Decode the JSON into our struct
            guard let jsonData = jsonString.data(using: .utf8) else { return [] }
            let selection = try JSONDecoder().decode(AIExerciseSelection.self, from: jsonData)
            
            // --- 5. Find the full Exercise objects that match the names the AI selected ---
            let selectedExerciseNames = selection.selectedExercises
            let finalExercises = library.filter { selectedExerciseNames.contains($0.name) }
            
            print("AI successfully selected exercises: \(selectedExerciseNames)")
            return finalExercises
            
        } catch {
            print("An error occurred while generating the workout with AI: \(error)")
            return [] // Return an empty array on failure
        }
    }
}
