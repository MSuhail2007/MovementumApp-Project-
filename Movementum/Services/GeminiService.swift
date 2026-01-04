import Foundation
import UIKit
import GoogleGenerativeAI
import Vision

enum AnalysisError: Error, LocalizedError {
    case apiKeyNotSet
    case responseTextMissing
    case jsonParsingError(String)
    case apiError(String)
    case ocrFailed

    var errorDescription: String? {
        switch self {
        case .apiKeyNotSet: return "Gemini API key not set"
        case .responseTextMissing: return "Empty response from Gemini"
        case .jsonParsingError(let s): return "Failed to parse JSON: \(s)"
        case .apiError(let s): return "API error: \(s)"
        case .ocrFailed: return "Failed to extract text from image"
        }
    }
}

struct GeminiService {
    // Helper: generate content with a few retries and exponential backoff
    private func generateWithRetry(model: GenerativeModel, prompt: String, image: UIImage? = nil) async throws -> String {
        let maxAttempts = 3
        var attempt = 0
        while attempt < maxAttempts {
            attempt += 1
            do {
                if let img = image {
                    let response = try await model.generateContent(prompt, img)
                    if let text = response.text { return text }
                } else {
                    let response = try await model.generateContent(prompt)
                    if let text = response.text { return text }
                }
                throw AnalysisError.responseTextMissing
            } catch {
                // If last attempt, rethrow the error
                if attempt >= maxAttempts {
                    throw error
                }
                // short exponential backoff
                let delayMs = UInt64(250 * Int(pow(2.0, Double(attempt - 1))))
                try? await Task.sleep(nanoseconds: delayMs * 1_000_000)
            }
        }
        throw AnalysisError.apiError("Retries exhausted")
    }

    // Heuristic extraction: look for calories/protein/fat numbers in raw OCR text
    private func heuristicFromText(_ text: String) -> NutritionInfo? {
        // Try to extract calories (first integer >=20 and <=3000)
        func firstInt(in s: String) -> Int? {
            let pattern = "\\b(\\d{2,4})\\b"
            if let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                if let m = re.firstMatch(in: s, options: [], range: NSRange(s.startIndex..., in: s)) {
                    if let r = Range(m.range(at: 1), in: s) {
                        return Int(s[r])
                    }
                }
            }
            return nil
        }

        func firstDouble(after keywords: [String], in s: String) -> Double? {
            // search for keyword followed by number, or number followed by g
            for kw in keywords {
                let pattern = "\\(\\d{1,3}(?:\\.\\d+)?\\)\\s*(?:g|gm|grams)?"
                if let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    if let m = re.firstMatch(in: s, options: [], range: NSRange(s.startIndex..., in: s)) {
                        if let r = Range(m.range(at: 1), in: s) {
                            return Double(s[r])
                        }
                    }
                }
            }
            // fallback: find any "12.3 g" pattern
            if let re = try? NSRegularExpression(pattern: "\\b(\\d{1,3}(?:\\.\\d+)?)\\s*g\\b", options: .caseInsensitive) {
                if let m = re.firstMatch(in: s, options: [], range: NSRange(s.startIndex..., in: s)), let r = Range(m.range(at: 1), in: s) {
                    return Double(s[r])
                }
            }
            return nil
        }

        let cleaned = text.replacingOccurrences(of: "\\r", with: "\n")
        let lines = cleaned.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let dishName = lines.first ?? "Scanned Food"

        if let cals = firstInt(in: text), cals >= 20 && cals <= 5000 {
            let protein = firstDouble(after: ["protein", "prot"], in: text) ?? 0.0
            let fat = firstDouble(after: ["fat", "fats"], in: text) ?? 0.0
            return NutritionInfo(dishName: dishName, calories: cals, protein: protein, fat: fat)
        }
        return nil
    }

    func analyze(image: UIImage) async -> Result<NutritionInfo, AnalysisError> {
        // --- UPDATED: Retrieve API Key from Environment Variable ---
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !apiKey.isEmpty else {
            print("⚠️ Critical: GEMINI_API_KEY not found in Environment Variables (Scheme).")
            return .failure(.apiKeyNotSet)
        }

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
            let rawText = try await generateWithRetry(model: model, prompt: prompt, image: image)
            if let firstBrace = rawText.firstIndex(of: "{"), let lastBrace = rawText.lastIndex(of: "}") {
                let jsonString = String(rawText[firstBrace...lastBrace])
                if let jsonData = jsonString.data(using: .utf8) {
                    do {
                        let nutritionInfo = try JSONDecoder().decode(NutritionInfo.self, from: jsonData)
                        return .success(nutritionInfo)
                    } catch {
                        // parsing failed — include rawText in error to aid debugging
                        print("Gemini analyze: JSON decode failed. rawText=\n\(rawText)")
                        return .failure(.jsonParsingError("Failed to decode JSON. Raw: \(rawText.prefix(400))"))
                    }
                } else {
                    return .failure(.jsonParsingError("Could not convert model text to data. Raw: \(rawText.prefix(400))"))
                }
            } else {
                // No JSON braces found — return error with model text snippet for debugging
                print("Gemini analyze: no JSON braces in model response: \(rawText)")
                return .failure(.jsonParsingError(String(rawText.prefix(400))))
            }
        } catch let err as AnalysisError {
            return .failure(err)
        } catch {
            return .failure(.apiError(error.localizedDescription))
        }
    }

    // New: OCR (Vision) -> Gemini (text) pipeline
    func analyzeUsingOCR(image: UIImage) async -> Result<NutritionInfo, AnalysisError> {
        // Perform OCR using Vision
        guard let cgImage = image.cgImage ?? CIContext().createCGImage(CIImage(image: image)!, from: CIImage(image: image)!.extent) else {
            return .failure(.ocrFailed)
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return .failure(.ocrFailed)
        }

        // request.results is [VNObservation]? — compactMap each item to VNRecognizedTextObservation
        let resultsArray = request.results ?? []
        let lines = resultsArray.compactMap { ($0 as? VNRecognizedTextObservation)?.topCandidates(1).first?.string }
        let ocrText = lines.joined(separator: "\n")
        if ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .failure(.ocrFailed)
        }

        // --- UPDATED: Retrieve API Key from Environment Variable ---
        guard let apiKey = ProcessInfo.processInfo.environment["GEMINI_API_KEY"], !apiKey.isEmpty else {
            print("⚠️ Critical: GEMINI_API_KEY not found in Environment Variables (Scheme).")
            return .failure(.apiKeyNotSet)
        }

        let model = GenerativeModel(name: "gemini-2.5-flash", apiKey: apiKey)

        // We give the OCR text and ask the model to respond with strict JSON
        let prompt = """
        I will provide extracted text from an image (raw OCR). The text may contain menu names, labels, or other printed details.
        Analyze the OCR text and determine the main dish name and a best-estimate of its nutrition content.
        Respond ONLY with a single JSON object matching this structure:
        {"dishName": String, "calories": Int, "protein": Double, "fat": Double}

        Here is the OCR'd text (do not hallucinate beyond what is reasonable):
        ---BEGIN OCR---
        \(ocrText)
        ---END OCR---

        Provide only the JSON object, no commentary.
        """

        do {
            let rawText = try await generateWithRetry(model: model, prompt: prompt)
            if let firstBrace = rawText.firstIndex(of: "{"), let lastBrace = rawText.lastIndex(of: "}") {
                let jsonString = String(rawText[firstBrace...lastBrace])
                if let jsonData = jsonString.data(using: .utf8) {
                    do {
                        let nutritionInfo = try JSONDecoder().decode(NutritionInfo.self, from: jsonData)
                        return .success(nutritionInfo)
                    } catch {
                        print("Gemini OCR: JSON decode failed. rawText=\n\(rawText)")
                        return .failure(.jsonParsingError("Failed to decode JSON. Raw: \(rawText.prefix(400))"))
                    }
                } else {
                    return .failure(.jsonParsingError("Could not convert model text to data. Raw: \(rawText.prefix(400))"))
                }
            } else {
                // If model didn't return JSON, try simple heuristic extraction from OCR text before failing
                if let heuristic = heuristicFromText(ocrText) {
                    return .success(heuristic)
                }
                print("Gemini OCR: no JSON braces in model response: \(rawText)")
                return .failure(.jsonParsingError(String(rawText.prefix(400))))
            }
        } catch let err as AnalysisError {
            return .failure(err)
        } catch {
            return .failure(.apiError(error.localizedDescription))
        }
    }

    // Try OCR + local heuristic only (no Gemini call). Useful as last-resort fallback or offline mode.
    func analyzeHeuristicOnly(image: UIImage) async -> Result<NutritionInfo, AnalysisError> {
        // Perform OCR using Vision
        guard let cgImage = image.cgImage ?? CIContext().createCGImage(CIImage(image: image)!, from: CIImage(image: image)!.extent) else {
            return .failure(.ocrFailed)
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return .failure(.ocrFailed)
        }

        let resultsArray = request.results ?? []
        let lines = resultsArray.compactMap { ($0 as? VNRecognizedTextObservation)?.topCandidates(1).first?.string }
        let ocrText = lines.joined(separator: "\n")
        if ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .failure(.ocrFailed)
        }

        if let heuristic = heuristicFromText(ocrText) {
            return .success(heuristic)
        }
        return .failure(.ocrFailed)
    }
}
