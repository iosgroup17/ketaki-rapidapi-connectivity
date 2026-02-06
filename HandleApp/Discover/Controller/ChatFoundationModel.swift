//
//  chatFoundationModel.swift
//  HandleApp
//
//  Created by SDC-USER on 03/02/26.
//

import Foundation
import FoundationModels

// 1. The Input Model
// This bundles the specific choices the user made during the Chat flow.
struct GenerationRequest {
    let idea: String
    let tone: String
    let platform: String
    let refinementInstruction: String? // Optional: for Step 4 (Refinement)
}


// MARK: - 3. The Generation Actor
actor PostGenerationModel {
    
    // Singleton for easy access
    static let shared = PostGenerationModel()
    
    // Holds the active AI session
    private var session: LanguageModelSession?
    
    private init() {}
    
    // MARK: - Session Management
    
    /// Connects to the device's System Intelligence. Reuses existing session if available.
    private func ensureSession() async throws -> LanguageModelSession {
        if let existingSession = session {
            return existingSession
        }
        
        let model = SystemLanguageModel.default
        let newSession = LanguageModelSession(model: model)
        self.session = newSession
        return newSession
    }
    
    // MARK: - Generation Logic
        
    /// Generates the post and returns the structured EditorDraftData
    func generatePost(profile: UserProfile, request: GenerationRequest) async throws -> EditorDraftData {
        
#if targetEnvironment(simulator)
        // Simulator Mock (Since local models don't run on Simulator)
        try await Task.sleep(nanoseconds: 2 * 1_000_000_000)
        return EditorDraftData(
            platformName: request.platform,
            platformIconName: "doc.text",
            caption: "[Simulator Mock]: Based on '\(request.idea)', here is a \(request.tone) post for \(request.platform).",
            images: ["A professional workspace"],
            hashtags: ["#Simulator", "#SwiftUI"],
            postingTimes: ["10:00 AM"]
        )
        
#else
        
        // 1. Get Session
        let session = try await ensureSession()
        
        // 2. Build Prompt
        let prompt = """
        You are an expert Social Media Manager.
        
        \(profile.promptContext)
        
        TASK:
        Write a social media post based on these inputs:
        - Idea: \(request.idea)
        - Tone: \(request.tone)
        - Platform: \(request.platform)
        \(request.refinementInstruction != nil ? "- Refinement: \(request.refinementInstruction!)" : "")
        
        OUTPUT INSTRUCTIONS:
        You must output ONLY valid JSON. No markdown formatting. No introductory text.
        
        Target JSON Structure:
        {
            "platformName": "\(request.platform)",
            "platformIconName": "doc.text", // Use generic doc icon, we map specific ones in UI
            "caption": "The post content here",
            "images": ["Visual description of an image"],
            "hashtags": ["#tag1", "#tag2"],
            "postingTimes": ["Best time to post"]
        }
        """
        
        // 3. Generate
        let response = try await session.respond(to: prompt)
        
        // 4. Parse
        let cleanJSON = stripMarkdown(from: response.content)
        
        guard let data = cleanJSON.data(using: .utf8) else {
            throw ContentError.jsonParsingFailed
        }
        
        return try JSONDecoder().decode(EditorDraftData.self, from: data)
#endif
    }
        
        private func stripMarkdown(from text: String) -> String {
                var cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleanText.hasPrefix("```json") {
                    cleanText = cleanText.replacingOccurrences(of: "```json", with: "")
                } else if cleanText.hasPrefix("```") {
                    cleanText = cleanText.replacingOccurrences(of: "```", with: "")
                }
                if cleanText.hasSuffix("```") {
                    cleanText = String(cleanText.dropLast(3))
                }
                return cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
            }
}

enum ContentError: Error {
    case jsonParsingFailed
    case modelAssetsMissing
    case noJSONFound
}

