import Foundation

struct StudySession: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let sessionType: String
    var cardsStudied: Int
    var newCards: Int
    var reviewCards: Int
    var correctAnswers: Int
    var sessionDuration: Int // in seconds
    var accuracyRate: Double
    let focusTopics: [String]
    let startedAt: Date
    var completedAt: Date?
    var isCompleted: Bool
    
    init(userId: UUID, sessionType: String = "daily_practice", focusTopics: [String] = []) {
        self.id = UUID()
        self.userId = userId
        self.sessionType = sessionType
        self.cardsStudied = 0
        self.newCards = 0
        self.reviewCards = 0
        self.correctAnswers = 0
        self.sessionDuration = 0
        self.accuracyRate = 0.0
        self.focusTopics = focusTopics
        self.startedAt = Date()
        self.completedAt = nil
        self.isCompleted = false
    }
    
    var progressPercentage: Double {
        guard cardsStudied > 0 else { return 0 }
        return accuracyRate * 100
    }
    
    var averageTimePerCard: Double {
        guard cardsStudied > 0 else { return 0 }
        return Double(sessionDuration) / Double(cardsStudied)
    }
}