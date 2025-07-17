import Foundation

struct StudySession: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    var sessionType: SessionType
    var flashcards: [Flashcard]
    var testQuestions: [TestQuestion]
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
    
    // Gamification properties
    var currentIndex: Int = 0
    var sessionXP: Int = 0
    var sessionCoins: Int = 0
    var bonusMultiplier: Double = 1.0
    var perfectStreak: Int = 0
    var activePowerUps: [PowerUp] = []
    
    enum SessionType: String, Codable, CaseIterable {
        case flashcard = "flashcard"
        case test = "test"
        case mixed = "mixed"
        case battle = "battle"
        case dailyPractice = "daily_practice"
        
        var displayName: String {
            switch self {
            case .flashcard: return "Study Flashcards"
            case .test: return "Take Test"
            case .mixed: return "Mixed Practice"
            case .battle: return "Quiz Battle"
            case .dailyPractice: return "Daily Practice"
            }
        }
    }
    
    init(userId: UUID, sessionType: SessionType = .dailyPractice, focusTopics: [String] = [], flashcards: [Flashcard] = [], testQuestions: [TestQuestion] = []) {
        self.id = UUID()
        self.userId = userId
        self.sessionType = sessionType
        self.flashcards = flashcards
        self.testQuestions = testQuestions
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
    
    var isTestUnlocked: Bool {
        let masteredCount = flashcards.filter { $0.masteryLevel >= 3 }.count
        return Double(masteredCount) / Double(flashcards.count) >= 0.8
    }
    
    var progress: Double {
        guard !flashcards.isEmpty || !testQuestions.isEmpty else { return 0 }
        let total = sessionType == .test ? testQuestions.count : flashcards.count
        return Double(currentIndex) / Double(total)
    }
    
    mutating func recordAnswer(correct: Bool, timeSpent: TimeInterval) {
        cardsStudied += 1
        
        if correct {
            correctAnswers += 1
            perfectStreak += 1
            
            let baseXP = getCurrentDifficulty().xpValue
            let streakBonus = min(perfectStreak * 2, 20)
            let speedBonus = timeSpent < 5 ? 5 : 0
            
            let xpGained = Int(Double(baseXP + streakBonus + speedBonus) * bonusMultiplier)
            sessionXP += xpGained
            
            if perfectStreak % 5 == 0 {
                sessionCoins += 10
            }
        } else {
            perfectStreak = 0
        }
        
        accuracyRate = Double(correctAnswers) / Double(cardsStudied)
    }
    
    func getCurrentDifficulty() -> Flashcard.Difficulty {
        if sessionType == .test {
            return .intermediate
        } else if currentIndex < flashcards.count {
            return flashcards[currentIndex].difficulty
        }
        return .beginner
    }
    
    mutating func applyPowerUp(_ powerUp: PowerUp) {
        activePowerUps.append(powerUp)
        
        switch powerUp.effectType {
        case .xpBoost:
            bonusMultiplier *= powerUp.effectValue
        default:
            break
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sessionType = "session_type"
        case flashcards
        case testQuestions = "test_questions"
        case cardsStudied = "cards_studied"
        case newCards = "new_cards"
        case reviewCards = "review_cards"
        case correctAnswers = "correct_answers"
        case sessionDuration = "session_duration"
        case accuracyRate = "accuracy_rate"
        case focusTopics = "focus_topics"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case isCompleted = "is_completed"
        case currentIndex = "current_index"
        case sessionXP = "xp_earned"
        case sessionCoins = "coins_earned"
        case bonusMultiplier = "bonus_multiplier"
        case perfectStreak = "perfect_streak"
        case activePowerUps = "active_power_ups"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        userId = try container.decode(UUID.self, forKey: .userId)
        sessionType = try container.decode(SessionType.self, forKey: .sessionType)
        flashcards = try container.decodeIfPresent([Flashcard].self, forKey: .flashcards) ?? []
        testQuestions = try container.decodeIfPresent([TestQuestion].self, forKey: .testQuestions) ?? []
        cardsStudied = try container.decode(Int.self, forKey: .cardsStudied)
        newCards = try container.decode(Int.self, forKey: .newCards)
        reviewCards = try container.decode(Int.self, forKey: .reviewCards)
        correctAnswers = try container.decode(Int.self, forKey: .correctAnswers)
        sessionDuration = try container.decode(Int.self, forKey: .sessionDuration)
        accuracyRate = try container.decode(Double.self, forKey: .accuracyRate)
        focusTopics = try container.decode([String].self, forKey: .focusTopics)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        
        // Gamification properties with defaults
        currentIndex = try container.decodeIfPresent(Int.self, forKey: .currentIndex) ?? 0
        sessionXP = try container.decodeIfPresent(Int.self, forKey: .sessionXP) ?? 0
        sessionCoins = try container.decodeIfPresent(Int.self, forKey: .sessionCoins) ?? 0
        bonusMultiplier = try container.decodeIfPresent(Double.self, forKey: .bonusMultiplier) ?? 1.0
        perfectStreak = try container.decodeIfPresent(Int.self, forKey: .perfectStreak) ?? 0
        activePowerUps = try container.decodeIfPresent([PowerUp].self, forKey: .activePowerUps) ?? []
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(sessionType, forKey: .sessionType)
        try container.encode(flashcards, forKey: .flashcards)
        try container.encode(testQuestions, forKey: .testQuestions)
        try container.encode(cardsStudied, forKey: .cardsStudied)
        try container.encode(newCards, forKey: .newCards)
        try container.encode(reviewCards, forKey: .reviewCards)
        try container.encode(correctAnswers, forKey: .correctAnswers)
        try container.encode(sessionDuration, forKey: .sessionDuration)
        try container.encode(accuracyRate, forKey: .accuracyRate)
        try container.encode(focusTopics, forKey: .focusTopics)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(completedAt, forKey: .completedAt)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(currentIndex, forKey: .currentIndex)
        try container.encode(sessionXP, forKey: .sessionXP)
        try container.encode(sessionCoins, forKey: .sessionCoins)
        try container.encode(bonusMultiplier, forKey: .bonusMultiplier)
        try container.encode(perfectStreak, forKey: .perfectStreak)
        try container.encode(activePowerUps, forKey: .activePowerUps)
    }
}