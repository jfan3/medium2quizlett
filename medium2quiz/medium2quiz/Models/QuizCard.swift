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
    let articleId: UUID
    let question: String
    let answer: String
    let choices: [String]?
    let type: QuizCardType
    let difficulty: QuizCardDifficulty
    var isStarred: Bool
    var isCompleted: Bool
    var attempts: Int
    var correctAttempts: Int
    var lastStudied: Date?
    var masteryLevel: Double
    var easeFactor: Double
    var intervalDays: Int
    var nextReviewDate: Date
    var reviewStage: Int
    let createdAt: Date
    
    init(articleId: UUID, question: String, answer: String, choices: [String]?, type: QuizCardType, difficulty: QuizCardDifficulty) {
        self.id = UUID()
        self.articleId = articleId
        self.question = question
        self.answer = answer
        self.choices = choices
        self.type = type
        self.difficulty = difficulty
        self.isStarred = false
        self.isCompleted = false
        self.attempts = 0
        self.correctAttempts = 0
        self.lastStudied = nil
        self.masteryLevel = 0.0
        self.easeFactor = 2.5
        self.intervalDays = 1
        self.nextReviewDate = Date()
        self.reviewStage = 0
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