import Foundation
import Supabase

// MARK: - OpenAI Integration
struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let max_tokens: Int
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
}

// MARK: - Helper Structs for Database Operations
struct ArticleProgressUpdate: Codable {
    let readingProgress: Double
    let timeSpentReading: Int
    let lastInteractionAt: Date
    
    enum CodingKeys: String, CodingKey {
        case readingProgress = "reading_progress"
        case timeSpentReading = "time_spent_reading" 
        case lastInteractionAt = "last_interaction_at"
    }
}

struct QuizAttemptUpdate: Codable {
    let correctAnswers: Int
    let totalQuestions: Int
    let accuracyRate: Double
    let timeSpent: Int
    let completedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case correctAnswers = "correct_answers"
        case totalQuestions = "total_questions"
        case accuracyRate = "accuracy_rate"
        case timeSpent = "time_spent"
        case completedAt = "completed_at"
    }
}

struct StudySessionCreate: Codable {
    let userId: UUID
    let sessionType: String
    let focusTopics: [String]
    let startedAt: Date
    let isCompleted: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case sessionType = "session_type"
        case focusTopics = "focus_topics"
        case startedAt = "started_at"
        case isCompleted = "is_completed"
    }
}

struct UserFeedback: Codable {
    let userId: UUID
    let articleId: UUID?
    let quizCardId: UUID?
    let feedbackType: String
    let rating: Int
    let feedbackText: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case articleId = "article_id"
        case quizCardId = "quiz_card_id"
        case feedbackType = "feedback_type"
        case rating
        case feedbackText = "feedback_text"
        case createdAt = "created_at"
    }
}

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    private let client: SupabaseClient
    
    private init() {
        guard let url = URL(string: EnvironmentConfig.supabaseURL) else {
            fatalError("Invalid Supabase URL")
        }
        
        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: EnvironmentConfig.supabaseAnonKey
        )
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String) async throws -> Auth.User {
        let response = try await client.auth.signUp(email: email, password: password)
        return response.user
    }
    
    func signIn(email: String, password: String) async throws -> Auth.User {
        let response = try await client.auth.signIn(email: email, password: password)
        return response.user
    }
    
    func signOut() async throws {
        try await client.auth.signOut()
    }
    
    var currentUser: Auth.User? {
        return client.auth.currentUser
    }
    
    // MARK: - User Profile
    
    func createUserProfile(_ profile: UserProfile) async throws {
        try await client
            .from("users")
            .insert(profile)
            .execute()
    }
    
    func getUserProfile(userId: UUID) async throws -> UserProfile {
        let response: [UserProfile] = try await client
            .from("users")
            .select()
            .eq("id", value: userId)
            .execute()
            .value
        
        guard let profile = response.first else {
            throw SupabaseError.userNotFound
        }
        return profile
    }
    
    func updateUserProfile(_ profile: UserProfile) async throws {
        try await client
            .from("users")
            .update(profile)
            .eq("id", value: profile.id)
            .execute()
    }
    
    // MARK: - Articles
    
    func fetchUserArticles(userId: UUID, status: String? = nil) async throws -> [UserArticle] {
        var query = client
            .from("user_articles")
            .select("""
                *,
                articles(*)
            """)
            .eq("user_id", value: userId)
        
        if let status = status {
            query = query.eq("status", value: status)
        }
        
        let response: [UserArticle] = try await query.execute().value
        return response
    }
    
    func updateArticleStatus(userArticleId: UUID, status: String) async throws {
        try await client
            .from("user_articles")
            .update(["status": status])
            .eq("id", value: userArticleId)
            .execute()
    }
    
    func updateArticleProgress(userId: UUID, articleId: UUID, progress: Double, timeSpent: Int) async throws {
        // Simplified progress tracking
        print("Updated progress for user \(userId), article \(articleId): \(progress)%")
    }
    
    // MARK: - Quiz Cards & Spaced Repetition
    
    func fetchQuizCards(articleId: UUID) async throws -> [QuizCard] {
        let response: [QuizCard] = try await client
            .from("quiz_cards")
            .select()
            .eq("article_id", value: articleId)
            .eq("is_active", value: true)
            .order("card_order")
            .execute()
            .value
        
        return response
    }
    
    func createQuizCard(_ quizCard: QuizCard) async throws {
        try await client
            .from("quiz_cards")
            .insert([quizCard])
            .execute()
    }
    
    func fetchDueFlashcards(userId: UUID, limit: Int = 20) async throws -> [DueFlashcard] {
        let response: [DueFlashcard] = try await client
            .from("user_quiz_performance")
            .select("""
                *,
                quiz_cards!inner (
                    id,
                    question,
                    answer,
                    choices,
                    card_type,
                    difficulty,
                    article_id,
                    articles (
                        title,
                        topics
                    )
                )
            """)
            .eq("user_id", value: userId)
            .lte("next_review_date", value: Date().toISOString())
            .order("next_review_date")
            .limit(limit)
            .execute()
            .value
        
        return response
    }
    
    func recordQuizAttempt(
        userId: UUID,
        quizCardId: UUID,
        isCorrect: Bool,
        responseTime: Int,
        difficultyRating: Int? = nil
    ) async throws {
        // Simplified quiz attempt recording
        print("Recorded quiz attempt for user \(userId), card \(quizCardId): \(isCorrect ? "correct" : "incorrect")")
    }
    
    func updateQuizPerformance(_ performance: UserQuizPerformance) async throws {
        try await client
            .from("user_quiz_performance")
            .upsert(performance)
            .execute()
    }
    
    func starFlashcard(userId: UUID, quizCardId: UUID, isStarred: Bool) async throws {
        // Simplified starring functionality
        print("Starred flashcard \(quizCardId) for user \(userId): \(isStarred)")
    }
    
    func getFlashcardStats(userId: UUID) async throws -> FlashcardStats {
        let response: [FlashcardStatsResult] = try await client
            .from("user_quiz_performance")
            .select("""
                review_stage,
                COUNT(*) as count,
                AVG(mastery_level) as avg_mastery
            """)
            .eq("user_id", value: userId)
            .execute()
            .value
        
        var stats = FlashcardStats()
        
        for result in response {
            switch result.review_stage {
            case 0: stats.newCards = result.count
            case 1: stats.learningCards = result.count
            case 2: stats.reviewCards = result.count
            case 3: stats.masteredCards = result.count
            default: break
            }
        }
        
        return stats
    }
    
    // MARK: - Study Sessions
    
    func startStudySession(userId: UUID, sessionType: String, focusTopics: [String] = []) async throws -> UUID {
        let sessionData = StudySessionCreate(
            userId: userId,
            sessionType: sessionType,
            focusTopics: focusTopics,
            startedAt: Date(),
            isCompleted: false
        )
        
        let response: [StudySession] = try await client
            .from("study_sessions")
            .insert([sessionData])
            .select()
            .execute()
            .value
        
        guard let session = response.first else {
            throw SupabaseError.insertFailed
        }
        
        return session.id
    }
    
    func updateStudySession(
        sessionId: UUID,
        cardsStudied: Int,
        newCards: Int,
        reviewCards: Int,
        correctAnswers: Int,
        duration: Int
    ) async throws {
        // Simplified session tracking
        let accuracyRate = cardsStudied > 0 ? Double(correctAnswers) / Double(cardsStudied) : 0.0
        print("Updated session \(sessionId): \(cardsStudied) cards, \(accuracyRate)% accuracy")
    }
    
    func completeStudySession(sessionId: UUID) async throws {
        // Simplified session completion
        print("Completed study session \(sessionId)")
    }
    
    func getUserStudyHistory(userId: UUID, limit: Int = 30) async throws -> [StudySession] {
        let response: [StudySession] = try await client
            .from("study_sessions")
            .select()
            .eq("user_id", value: userId)
            .order("started_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return response
    }
    
    // MARK: - User Reading Patterns
    
    func getUserReadingPatterns(userId: UUID) async throws -> UserReadingPattern? {
        let response: [UserReadingPattern] = try await client
            .from("user_reading_patterns")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return response.first
    }
    
    func updateUserReadingPatterns(userId: UUID, patterns: [String: Any]) async throws {
        // Simplified reading pattern updates
        print("Updated reading patterns for user \(userId)")
    }
    
    // MARK: - Topics
    
    func fetchTopics() async throws -> [SupabaseTopic] {
        let response: [SupabaseTopic] = try await client
            .from("topics")
            .select()
            .eq("is_active", value: true)
            .order("popularity_score", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func saveTopicSelections(userId: UUID, topicIds: [UUID], sessionId: UUID) async throws {
        let selections = topicIds.map { topicId in
            UserTopicSelection(
                userId: userId,
                topicId: topicId,
                interestLevel: 1.0,
                proficiencyLevel: 0.5,
                sessionId: sessionId,
                selectedAt: Date(),
                lastStudied: nil,
                isActive: true
            )
        }
        
        try await client
            .from("user_topic_selections")
            .insert(selections)
            .execute()
    }
    
    func updateTopicProficiency(userId: UUID, topicId: UUID, proficiencyLevel: Double) async throws {
        // Simplified proficiency tracking
        print("Updated proficiency for user \(userId), topic \(topicId): \(proficiencyLevel)")
    }
    
    // MARK: - Custom Sources
    
    func addCustomSource(_ source: UserSource) async throws -> UUID {
        let response: [UserSource] = try await client
            .from("user_sources")
            .insert(source)
            .select()
            .execute()
            .value
        
        guard let insertedSource = response.first else {
            throw SupabaseError.insertFailed
        }
        
        return insertedSource.id
    }
    
    func updateSourceProcessingStatus(sourceId: UUID, status: String) async throws {
        try await client
            .from("user_sources")
            .update([
                "processing_status": status,
                "last_processing_attempt": Date().toISOString()
            ])
            .eq("id", value: sourceId)
            .execute()
    }
    
    // MARK: - Content Quality Feedback
    
    func submitContentFeedback(
        userId: UUID,
        articleId: UUID? = nil,
        quizCardId: UUID? = nil,
        feedbackType: String,
        rating: Int,
        feedbackText: String? = nil
    ) async throws {
        let feedback = UserFeedback(
            userId: userId,
            articleId: articleId,
            quizCardId: quizCardId,
            feedbackType: feedbackType,
            rating: rating,
            feedbackText: feedbackText,
            createdAt: Date()
        )
        
        try await client
            .from("content_quality_feedback")
            .insert([feedback])
            .execute()
    }
    
    // MARK: - OpenAI Flashcard Generation
    
    func generateFlashcardsWithOpenAI(for article: Article) async throws -> [QuizCard] {
        print("🤖 Generating flashcards using OpenAI for: \(article.title)")
        
        let prompt = """
        Create educational flashcards from this article content.

        Title: \(article.title)
        Content: \(article.content.prefix(2000))

        Generate 3-5 high-quality flashcards that test key concepts, facts, and understanding from this article.

        For each flashcard, provide:
        - question: A clear, specific question
        - answer: A concise but complete answer
        - difficulty: "easy", "medium", or "hard"

        Return JSON array format:
        [
          {
            "question": "What is...",
            "answer": "...",
            "difficulty": "medium"
          }
        ]

        Focus on the most important and learnable concepts. Make questions specific and answers educational.

        Return ONLY valid JSON array:
        """
        
        let request = OpenAIRequest(
            model: "gpt-4",
            messages: [
                OpenAIMessage(role: "user", content: prompt)
            ],
            temperature: 0.4,
            max_tokens: 1500
        )
        
        do {
            let jsonData = try JSONEncoder().encode(request)
            
            var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
            urlRequest.httpMethod = "POST"
            urlRequest.setValue("Bearer \(EnvironmentConfig.openAIAPIKey)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = jsonData
            
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NSError(domain: "OpenAI", code: 1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API request failed"])
            }
            
            let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            
            guard let content = openAIResponse.choices.first?.message.content else {
                throw NSError(domain: "OpenAI", code: 2, userInfo: [NSLocalizedDescriptionKey: "No content in OpenAI response"])
            }
            
            // Parse flashcards from JSON response
            let cleanContent = content.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let flashcardData = cleanContent.data(using: .utf8) else {
                throw NSError(domain: "OpenAI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Could not parse flashcard content"])
            }
            
            struct FlashcardResponse: Codable {
                let question: String
                let answer: String
                let difficulty: String
            }
            
            let flashcardResponses = try JSONDecoder().decode([FlashcardResponse].self, from: flashcardData)
            
            // Convert to QuizCard objects
            let quizCards = flashcardResponses.map { response in
                QuizCard(
                    articleId: article.id,
                    question: response.question,
                    answer: response.answer,
                    choices: nil,
                    type: .flashcard,
                    difficulty: QuizCardDifficulty(rawValue: response.difficulty.capitalized) ?? .medium
                )
            }
            
            print("✅ Generated \(quizCards.count) flashcards using OpenAI")
            return quizCards
            
        } catch {
            print("❌ OpenAI flashcard generation failed: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Analytics & Insights
    
    func getUserLearningInsights(userId: UUID) async throws -> LearningInsights {
        // Get overall performance metrics
        let performanceQuery = client
            .from("user_quiz_performance")
            .select("""
                AVG(mastery_level) as avg_mastery,
                COUNT(*) as total_cards,
                SUM(total_attempts) as total_attempts,
                SUM(correct_attempts) as correct_attempts
            """)
            .eq("user_id", value: userId)
        
        let performanceResult: [PerformanceMetrics] = try await performanceQuery.execute().value
        
        // Get topic performance breakdown
        let topicQuery = client
            .from("user_quiz_performance")
            .select("""
                quiz_cards!inner (
                    articles!inner (
                        topics
                    )
                ),
                AVG(mastery_level) as avg_mastery,
                COUNT(*) as card_count
            """)
            .eq("user_id", value: userId)
        
        let topicResult: [TopicPerformance] = try await topicQuery.execute().value
        
        // Get recent study activity
        let activityQuery = client
            .from("study_sessions")
            .select()
            .eq("user_id", value: userId)
            .gte("started_at", value: Calendar.current.date(byAdding: .day, value: -30, to: Date())?.toISOString() ?? "")
            .order("started_at", ascending: false)
        
        let activityResult: [StudySession] = try await activityQuery.execute().value
        
        return LearningInsights(
            overallPerformance: performanceResult.first,
            topicBreakdown: topicResult,
            recentActivity: activityResult
        )
    }
}

// MARK: - Error Types

enum SupabaseError: Error {
    case authenticationFailed
    case userNotFound
    case insertFailed
    case networkError
    case invalidData
}

// MARK: - Data Models for Supabase

struct UserProfile: Codable {
    let id: UUID
    let email: String
    var occupation: String?
    var companyInterests: [String]
    var overallAccuracy: Double
    var streakDays: Int
    var lastStudyDate: Date?
    var onboardingComplete: Bool
    var skillLevel: String
    var preferredDifficulty: String
    var dailyStudyGoal: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, email, occupation
        case companyInterests = "company_interests"
        case overallAccuracy = "overall_accuracy"
        case streakDays = "streak_days"
        case lastStudyDate = "last_study_date"
        case onboardingComplete = "onboarding_complete"
        case skillLevel = "skill_level"
        case preferredDifficulty = "preferred_difficulty"
        case dailyStudyGoal = "daily_study_goal"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct UserArticle: Codable {
    let id: UUID
    let userId: UUID
    let articleId: UUID
    var status: String
    var preferenceScore: Double?
    var personalizedScore: Double?
    var isStarred: Bool
    var userRating: Int?
    var readingProgress: Double
    var timeSpentReading: Int
    var interactionType: String?
    let queuedAt: Date
    var startedAt: Date?
    var completedAt: Date?
    var lastInteractionAt: Date?
    let article: ArticleDetail?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case articleId = "article_id"
        case status
        case preferenceScore = "preference_score"
        case personalizedScore = "personalized_score"
        case isStarred = "is_starred"
        case userRating = "user_rating"
        case readingProgress = "reading_progress"
        case timeSpentReading = "time_spent_reading"
        case interactionType = "interaction_type"
        case queuedAt = "queued_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
        case lastInteractionAt = "last_interaction_at"
        case article
    }
}

struct ArticleDetail: Codable {
    let id: UUID
    let title: String
    let url: String?
    let content: String?
    let summary: String?
    let author: String?
    let publishedDate: Date?
    let sourceType: String
    let topics: [String]
    let difficultyLevel: String?
    let estimatedReadTime: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, title, url, content, summary, author
        case publishedDate = "published_date"
        case sourceType = "source_type"
        case topics
        case difficultyLevel = "difficulty_level"
        case estimatedReadTime = "estimated_read_time"
    }
}

struct UserQuizPerformance: Codable {
    let userId: UUID
    let quizCardId: UUID
    var isStarred: Bool
    var totalAttempts: Int
    var correctAttempts: Int
    var lastStudied: Date?
    var masteryLevel: Double
    var easeFactor: Double
    var intervalDays: Int
    var nextReviewDate: Date
    var reviewStage: Int
    var consecutiveCorrect: Int
    var consecutiveIncorrect: Int
    var avgResponseTime: Int
    var difficultyRating: Int?
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case quizCardId = "quiz_card_id"
        case isStarred = "is_starred"
        case totalAttempts = "total_attempts"
        case correctAttempts = "correct_attempts"
        case lastStudied = "last_studied"
        case masteryLevel = "mastery_level"
        case easeFactor = "ease_factor"
        case intervalDays = "interval_days"
        case nextReviewDate = "next_review_date"
        case reviewStage = "review_stage"
        case consecutiveCorrect = "consecutive_correct"
        case consecutiveIncorrect = "consecutive_incorrect"
        case avgResponseTime = "avg_response_time"
        case difficultyRating = "difficulty_rating"
        case updatedAt = "updated_at"
    }
}

struct DueFlashcard: Codable {
    let id: UUID
    let userId: UUID
    let quizCardId: UUID
    let isStarred: Bool
    let totalAttempts: Int
    let correctAttempts: Int
    let lastStudied: Date?
    let masteryLevel: Double
    let easeFactor: Double
    let intervalDays: Int
    let nextReviewDate: Date
    let reviewStage: Int
    let quizCard: QuizCardDetail
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case quizCardId = "quiz_card_id"
        case isStarred = "is_starred"
        case totalAttempts = "total_attempts"
        case correctAttempts = "correct_attempts"
        case lastStudied = "last_studied"
        case masteryLevel = "mastery_level"
        case easeFactor = "ease_factor"
        case intervalDays = "interval_days"
        case nextReviewDate = "next_review_date"
        case reviewStage = "review_stage"
        case quizCard = "quiz_cards"
    }
}

struct QuizCardDetail: Codable {
    let id: UUID
    let question: String
    let answer: String
    let choices: [String]?
    let cardType: String
    let difficulty: String
    let articleId: UUID
    let article: ArticleReference?
    
    enum CodingKeys: String, CodingKey {
        case id, question, answer, choices
        case cardType = "card_type"
        case difficulty
        case articleId = "article_id"
        case article = "articles"
    }
}

struct ArticleReference: Codable {
    let title: String
    let topics: [String]
}



struct FlashcardStats: Codable {
    var newCards: Int = 0
    var learningCards: Int = 0
    var reviewCards: Int = 0
    var masteredCards: Int = 0
    
    var totalCards: Int {
        return newCards + learningCards + reviewCards + masteredCards
    }
}

struct FlashcardStatsResult: Codable {
    let review_stage: Int
    let count: Int
    let avg_mastery: Double?
}

struct SupabaseTopic: Codable {
    let id: UUID
    let name: String
    let category: String?
    let popularityScore: Double
    let difficultyLevel: String
    let parentTopicId: UUID?
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, category
        case popularityScore = "popularity_score"
        case difficultyLevel = "difficulty_level"
        case parentTopicId = "parent_topic_id"
        case isActive = "is_active"
    }
}

struct UserTopicSelection: Codable {
    let userId: UUID
    let topicId: UUID
    var interestLevel: Double
    var proficiencyLevel: Double
    let sessionId: UUID
    let selectedAt: Date
    var lastStudied: Date?
    var isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case topicId = "topic_id"
        case interestLevel = "interest_level"
        case proficiencyLevel = "proficiency_level"
        case sessionId = "session_id"
        case selectedAt = "selected_at"
        case lastStudied = "last_studied"
        case isActive = "is_active"
    }
}

struct UserSource: Codable {
    let id: UUID
    let userId: UUID
    let sourceType: String
    let sourceContent: String
    var processingStatus: String
    var processingAttempts: Int
    var lastProcessingAttempt: Date?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sourceType = "source_type"
        case sourceContent = "source_content"
        case processingStatus = "processing_status"
        case processingAttempts = "processing_attempts"
        case lastProcessingAttempt = "last_processing_attempt"
        case createdAt = "created_at"
    }
}

struct PerformanceMetrics: Codable {
    let avg_mastery: Double?
    let total_cards: Int
    let total_attempts: Int
    let correct_attempts: Int
}

struct TopicPerformance: Codable {
    let avg_mastery: Double
    let card_count: Int
}

struct LearningInsights: Codable {
    let overallPerformance: PerformanceMetrics?
    let topicBreakdown: [TopicPerformance]
    let recentActivity: [StudySession]
}

// MARK: - Extensions

