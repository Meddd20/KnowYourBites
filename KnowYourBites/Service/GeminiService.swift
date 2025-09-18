//
//  GeminiService.swift
//  KnowYourBites
//
//  Created by Medhiko Biraja on 16/09/25.
//

import Foundation
import FirebaseAI
import UIKit
import SwiftUI

final class GeminiService {
    private let model: GenerativeModel

    init() {
        let ai = FirebaseAI.firebaseAI(backend: .googleAI())
        let genCfg = GenerationConfig(responseMIMEType: "application/json")
        self.model = ai.generativeModel(modelName: "gemini-2.5-flash",
                                        generationConfig: genCfg)
    }

    private func loadValidatePrompt() -> String? {
        guard let url = Bundle.main.url(forResource: "ValidatePrompt", withExtension: "md"),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return content
    }
    
    private func loadSummaryPrompt() -> String? {
        guard let url = Bundle.main.url(forResource: "SummaryPrompt", withExtension: "md"),
              let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return content
    }

    private func stripFences(_ s: String) -> String {
        s.replacingOccurrences(of: "```json", with: "")
         .replacingOccurrences(of: "```", with: "")
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func validateOCRText(_ ocrText: String) async -> ValidateResult? {
        guard var prompt = loadValidatePrompt() else {
            return nil
        }
        prompt = prompt.replacingOccurrences(of: "{{OCR_TEXT}}", with: ocrText)

        do {
            let resp = try await model.generateContent(prompt)
            let raw = resp.text ?? ""
            let jsonString = stripFences(raw)

            let data = Data(jsonString.utf8)
            let decoder = JSONDecoder()

            let result = try decoder.decode(ValidateResult.self, from: data)
            return result
        } catch {
            print("LLM/decode error:", error)
            return nil
        }
    }
    
    func generateSummary(_ composition: String, _ nutrition: String, productImage: UIImage) async -> SummaryResult? {
        guard let prompt = loadSummaryPrompt() else {
            return nil
        }
        
        let filledPrompt = prompt
            .replacingOccurrences(of: "{{OCR_COMPOSITION}}", with: composition)
            .replacingOccurrences(of: "{{OCR_NUTRITION}}", with: nutrition)
                
        guard let imageData = productImage.jpegData(compressionQuality: 0.85) else { return nil }
                
        do {
            let content = ModelContent(
                role: "user",
                parts: [
                    TextPart(filledPrompt),
                    InlineDataPart(data: imageData, mimeType: "image/jpeg")
                ]
            )
            
            let response = try await model.generateContent([content])
            let raw = response.text ?? ""
            print("this is raw\(raw)")
            let jsonString = stripFences(raw)
            
            let data = Data(jsonString.utf8)
            let decoder = JSONDecoder()
            let result = try decoder.decode(SummaryResult.self, from: data)
            return result
        } catch {
            print("LLM/decode error:", error)
            return nil
        }
    }
}
