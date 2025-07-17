import Foundation
import SwiftUI

struct Flashcard: Identifiable, Codable, Equatable {
    let id: UUID
    let articleId: UUID
    let question: String
    let answer: String
    let explanation: String?
    let difficulty: Difficulty
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
    
    var isFlipped: Bool = false
    var masteryLevel: Int = 0
    var lastReviewDate: Date?
    var nextReviewDate: Date?
    var isStarred: Bool = false
    
    enum Difficulty: String, Codable, CaseIterable {
        case beginner = "beginner"
        case intermediate = "intermediate" 
        case advanced = "advanced"
        
        var color: Color {
            switch self {
            case .beginner: return .green
            case .intermediate: return .orange
            case .advanced: return .red
            }
        }
        
        var xpValue: Int {
            switch self {
            case .beginner: return 10
            case .intermediate: return 20
            case .advanced: return 30
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case articleId = "article_id"
        case question
        case answer
        case explanation
        case difficulty
        case tags
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: UUID, articleId: UUID, question: String, answer: String, explanation: String?, difficulty: Difficulty, tags: [String], createdAt: Date, updatedAt: Date) {
        self.id = id
        self.articleId = articleId
        self.question = question
        self.answer = answer
        self.explanation = explanation
        self.difficulty = difficulty
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isFlipped = false
        self.masteryLevel = 0
        self.lastReviewDate = nil
        self.nextReviewDate = nil
        self.isStarred = false
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        articleId = try container.decode(UUID.self, forKey: .articleId)
        question = try container.decode(String.self, forKey: .question)
        answer = try container.decode(String.self, forKey: .answer)
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
        
        let difficultyString = try container.decode(String.self, forKey: .difficulty)
        difficulty = Difficulty(rawValue: difficultyString.lowercased()) ?? .intermediate
        
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        
        isFlipped = false
        masteryLevel = 0
        isStarred = false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(articleId, forKey: .articleId)
        try container.encode(question, forKey: .question)
        try container.encode(answer, forKey: .answer)
        try container.encodeIfPresent(explanation, forKey: .explanation)
        try container.encode(difficulty.rawValue, forKey: .difficulty)
        try container.encode(tags, forKey: .tags)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}