//
//  publishReadyPostEngine.swift
//  HandleApp
//
//  Created by SDC-USER on 05/02/26.
//

//
//  publishReadyPostEngine.swift
//  HandleApp
//
//  Created by SDC-USER on 05/02/26.
//

import Foundation
import FoundationModels

actor OnDevicePostEngine {
    static let shared = OnDevicePostEngine()
    private var session: LanguageModelSession?
    
    private init() {}
    
    private func ensureSession() async throws -> LanguageModelSession {
        if let existing = session { return existing }
        let newSession = LanguageModelSession(model: SystemLanguageModel.default)
        self.session = newSession
        return newSession
    }

    func generatePublishReadyPosts(trendText: String, context: UserProfile) async throws -> [PublishReadyPost] {
        let session = try await ensureSession()
        
        let prompt = """
                You are an expert social media strategist for:
                \(context.professionalIdentity.joined(separator: ", "))
                
                CONTEXT:
                Industry: \(context.industry.joined(separator: ", "))
                Audience: \(context.targetAudience.joined(separator: ", "))
                Goal: \(context.primaryGoals.joined(separator: ", "))
                Preferred Tone: \(context.contentFormats.joined(separator: ", "))
                
                TRENDING TOPIC:
                \(trendText)
                
                TASK:
                Generate 6 high-performing social media content ideas.
                
                OUTPUT CONSTRAINTS:
                1. Return ONLY raw JSON.
                2. No markdown, no explanations.
                3. All keys must be quoted.
                4. "post_heading": Max 20 chars, punchy.
                5. "platform_icon": Must be exactly "icon-x", "icon-instagram", or "icon-linkedin".
                6. "post_image": Array of strings. Use placeholders "img_01" through "img_16" ONLY if visual is needed.
                7. "caption": 80-100 chars, conversational.
                
                REQUIRED JSON STRUCTURE:
                {
                  "posts": [
                    {
                      "post_heading": "Catchy Headline",
                      "platform_icon": "icon-linkedin",
                      "post_image": ["img_01"],
                      "caption": "Engaging post body here.",
                      "hashtags": ["#tag1", "#tag2"],
                      "prediction_text": "Why this works."
                    }
                  ]
                }
                """

        let response = try await session.respond(to: prompt)
        
        // 1. Extract clean JSON string
        guard let jsonString = extractAndCleanJSON(from: response.content) else {
            print("🚨 AI Output was not valid JSON:\n\(response.content)")
            throw NSError(domain: "Decoder", code: 0, userInfo: [NSLocalizedDescriptionKey: "AI Output extraction failed"])
        }
        
        guard let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "Decoder", code: 1, userInfo: [NSLocalizedDescriptionKey: "String to Data conversion failed"])
        }
        
        // 2. Debug Print (Crucial to see what the model actually gave you)
        print("🤖 Cleaned AI JSON:\n\(jsonString)")
        
        // 3. Decode
        do {
            struct ResponseWrapper: Codable { let posts: [PublishReadyPost] }
            let decoded = try JSONDecoder().decode(ResponseWrapper.self, from: data)
            return decoded.posts
        } catch {
            print("❌ Decoding Error: \(error)")
            // If decoding fails, print the raw string to debug console to see the syntax error
            print("❌ Offending JSON: \(jsonString)")
            throw error
        }
    }

    /// Robust extractor that removes Markdown and finds the outermost braces
    private func extractAndCleanJSON(from text: String) -> String? {
        // 1. Remove Markdown code block markers if present
        var cleaned = text.replacingOccurrences(of: "```json", with: "")
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        
        // 2. Find the *outermost* braces to ignore conversational filler
        guard let firstIndex = cleaned.firstIndex(of: "{"),
              let lastIndex = cleaned.lastIndex(of: "}") else {
            return nil
        }
        
        // Ensure valid range
        guard firstIndex < lastIndex else { return nil }
        
        let jsonSubstring = cleaned[firstIndex...lastIndex]
        return String(jsonSubstring)
    }
}
