//
//  publishReadyPostEngine.swift
//  HandleApp
//
//  Created by SDC-USER on 05/02/26.
//


import Foundation
import FoundationModels // Ensure this matches your specific AI SDK

actor OnDevicePostEngine {
    static let shared = OnDevicePostEngine()
    private var session: LanguageModelSession?
    
    private init() {}
    
    private func ensureSession() async throws -> LanguageModelSession {
        if let existing = session { return existing }
        // Adjust the model type here if needed (e.g., .nano, .fast, etc.)
        let newSession = LanguageModelSession(model: SystemLanguageModel.default)
        self.session = newSession
        return newSession
    }
    
    // MARK: - GENERATE LIST OF IDEAS
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
                        7. "caption": 80-100 chars, conversational. do not add any hashtags here.
                You MUST wrap the array of objects inside a root JSON object with the key "posts".
                
                REQUIRED JSON STRUCTURE:
                {
                  "posts": [
                    {
                      "post_heading": "Headline",
                      "platform_icon": "icon-linkedin",
                      "post_image": ["img_01"],
                      "caption": "Post text",
                      "hashtags": ["#tag1"],
                      "prediction_text": "Reasoning"
                    }
                  ]
                }
                
                IMPORTANT: Do not return just the list. Start with the open brace { and "posts": [.
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

extension OnDevicePostEngine {

    func refinePostForEditor(post: PublishReadyPost, context: UserProfile) async throws -> EditorDraftData {
        let session = try await ensureSession()
        
        // Determine platform name for context
        let platformName = post.platformIcon.contains("linkedin") ? "LinkedIn" : (post.platformIcon.contains("instagram") ? "Instagram" : "X (Twitter)")
        
        let prompt = """
        ACT AS: Expert Social Media Copywriter.
        
        CONTEXT:
        - Platform: \(platformName)
        - Audience: \(context.targetAudience.joined(separator: ", "))
        - Goal: \(context.primaryGoals.joined(separator: ", "))
        
        INPUT IDEA:
        - Hook: "\(post.postHeading)"
        - Draft: "\(post.caption)"
        
        TASK:
        Expand this idea into a final publish-ready draft.
        
        REQUIREMENTS:
        1. Caption: Professional, engaging, formatted with line breaks.
        2. Hashtags: 5-10 relevant tags.
        3. Posting Times: Suggest 2 specific times (e.g. "Tomorrow at 9:00 AM").
        4. Images: Suggest 1-3 visual ideas.
        
        OUTPUT JSON (Strictly match this schema):
        {
            "platformName": "\(platformName)",
            "platformIconName": "\(post.platformIcon)",
            "caption": "Full caption...",
            "images": ["visual description 1"],
            "hashtags": ["#tag1", "#tag2"],
            "postingTimes": ["Tomorrow at 8:00 AM", "Wednesday at 5:00 PM"]
        }
        """

        let response = try await session.respond(to: prompt)
        
        // Use your existing cleaner
        guard let jsonString = extractAndCleanJSON(from: response.content),
              let data = jsonString.data(using: .utf8) else {
            throw NSError(domain: "EditorEngine", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to extract JSON"])
        }
        
        // Decode directly into your struct
        let draft = try JSONDecoder().decode(EditorDraftData.self, from: data)
        return draft
    }
}
