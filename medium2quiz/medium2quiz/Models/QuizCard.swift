import Foundation

enum QuizCardDifficulty: String, CaseIterable, Codable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"
}

enum QuizCardType: String, CaseIterable, Codable {
    case flashcard = "Flashcard"
    case multipleChoice = "Multiple Choice"
}

struct QuizCard: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let articleId: UUID
    let question: String
    let answer: String
    let choices: [String]?
    let type: String
    let difficulty: String
    let sourceParahraph: String?
    let cardOrder: Int?
    let isActive: Bool
    let createdAt: Date
    
    // Local properties for UI state (not persisted to quiz_cards table)
    var isStarred: Bool = false
    var isCompleted: Bool = false
    var attempts: Int = 0
    var correctAttempts: Int = 0
    var lastStudied: Date? = nil
    var masteryLevel: Double = 0.0
    var easeFactor: Double = 2.5
    var intervalDays: Int = 1
    var nextReviewDate: Date = Date()
    var reviewStage: Int = 0
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case articleId = "article_id"
        case question
        case answer
        case choices
        case type = "card_type"
        case difficulty
        case sourceParahraph = "source_paragraph"
        case cardOrder = "card_order"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        articleId = try container.decode(UUID.self, forKey: .articleId)
        question = try container.decode(String.self, forKey: .question)
        answer = try container.decode(String.self, forKey: .answer)
        choices = try container.decodeIfPresent([String].self, forKey: .choices)
        type = try container.decode(String.self, forKey: .type)
        difficulty = try container.decode(String.self, forKey: .difficulty)
        sourceParahraph = try container.decodeIfPresent(String.self, forKey: .sourceParahraph)
        cardOrder = try container.decodeIfPresent(Int.self, forKey: .cardOrder)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(articleId, forKey: .articleId)
        try container.encode(question, forKey: .question)
        try container.encode(answer, forKey: .answer)
        try container.encodeIfPresent(choices, forKey: .choices)
        try container.encode(type, forKey: .type)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encodeIfPresent(sourceParahraph, forKey: .sourceParahraph)
        try container.encodeIfPresent(cardOrder, forKey: .cardOrder)
        try container.encode(isActive, forKey: .isActive)
        try container.encode(createdAt, forKey: .createdAt)
    }
    
    init(userId: UUID, articleId: UUID, question: String, answer: String, choices: [String]?, type: QuizCardType, difficulty: QuizCardDifficulty, sourceParahraph: String? = nil, cardOrder: Int? = nil) {
        self.id = UUID()
        self.userId = userId
        self.articleId = articleId
        self.question = question
        self.answer = answer
        self.choices = choices
        self.type = type.rawValue.lowercased().replacingOccurrences(of: " ", with: "_")
        self.difficulty = difficulty.rawValue.lowercased()
        self.sourceParahraph = sourceParahraph
        self.cardOrder = cardOrder
        self.isActive = true
        self.createdAt = Date()
    }
    
    var accuracy: Double {
        guard attempts > 0 else { return 0 }
        return Double(correctAttempts) / Double(attempts)
    }
    
    var isWeak: Bool {
        attempts >= 3 && accuracy < 0.6
    }
    
    var isAced: Bool {
        attempts >= 3 && accuracy >= 0.9
    }
    
    mutating func recordAttempt(correct: Bool) {
        attempts += 1
        if correct {
            correctAttempts += 1
        }
        lastStudied = Date()
        
        if correct && !isCompleted {
            isCompleted = true
        }
    }
}