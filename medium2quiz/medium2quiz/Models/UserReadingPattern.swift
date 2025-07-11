import Foundation

struct UserReadingPattern: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var preferredTopics: [String]
    var avoidedTopics: [String]
    var optimalDifficultyLevel: String
    var avgReadingTime: Int
    var preferredContentLength: Int
    var preferredReadingHours: [Int]
    var readingStreak: Int
    var weeklyReadingGoal: Int
    var learningVelocity: Double
    let updatedAt: Date
    
    init(userId: UUID) {
        self.id = UUID()
        self.userId = userId
        self.preferredTopics = []
        self.avoidedTopics = []
        self.optimalDifficultyLevel = "medium"
        self.avgReadingTime = 0
        self.preferredContentLength = 0
        self.preferredReadingHours = [9,10,11,14,15,16,17,18,19,20]
        self.readingStreak = 0
        self.weeklyReadingGoal = 5
        self.learningVelocity = 1.0
        self.updatedAt = Date()
    }
    
    var isActiveReader: Bool {
        return readingStreak > 0 && avgReadingTime > 300 // 5+ minutes average
    }
    
    var preferredDifficultyEnum: DifficultyLevel {
        return DifficultyLevel(rawValue: optimalDifficultyLevel) ?? .medium
    }
}

enum DifficultyLevel: String, CaseIterable, Codable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case medium = "medium" // Legacy support
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .medium: return "Medium"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .beginner: return 1
        case .medium, .intermediate: return 2
        case .advanced: return 3
        }
    }
}