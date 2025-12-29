//
//  AIService.swift
//  FitnessAppProject
//
//  Created by Mohammed suhail on 24/08/2025.
//

import Foundation
import FoundationModels

@MainActor
class AIService{
    internal init(session: LanguageModelSession){
        self.session = session
    }
    private var  session: LanguageModelSession
    
    func getResponse(for message: String)async -> String{
        do{
            let response = try await session.respond(to: message)
            return response.content
        } catch{
            return "Error: \(error.localizedDescription)"
        }
    }
}
