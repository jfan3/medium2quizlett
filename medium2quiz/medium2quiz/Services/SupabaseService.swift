import Foundation
import Supabase


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
    
    func getCurrentUser() -> Auth.User? {
        return client.auth.currentUser
    }
    
    func getCurrentSession() -> Auth.Session? {
        return client.auth.currentSession
    }
    
    // MARK: - User Management
    
    func createUserProfile(userId: UUID, email: String, occupation: String, interests: [String]) async throws {
        let userProfile: [String: AnyJSON] = [
            "id": .string(userId.uuidString),
            "email": .string(email),
            "occupation": .string(occupation),
            "company_interests": .array(interests.map { .string($0) }),
            "onboarding_complete": .bool(true),
            "created_at": .string(Date().toISOString()),
            "updated_at": .string(Date().toISOString())
        ]
        
        try await client
            .from("users")
            .insert(userProfile)
            .execute()
    }
    
    func getUser(id: UUID) async throws -> User? {
        do {
            let response: PostgrestResponse<User> = try await client
                .from("users")
                .select("*")
                .eq("id", value: id)
                .single()
                .execute()
            
            return response.value
        } catch {
            // User with this ID doesn't exist
            print("⚠️ User not found with ID: \(id)")
            return nil
        }
    }
    
    func updateUserProfile(userId: UUID, updates: [String: AnyJSON]) async throws {
        var updateData = updates
        updateData["updated_at"] = .string(Date().toISOString())
        
        try await client
            .from("users")
            .update(updateData)
            .eq("id", value: userId)
            .execute()
    }
    
    // MARK: - RSS Management
    
    func getRSSSources() async throws -> [RSSSource] {
        let response: PostgrestResponse<[RSSSource]> = try await client
            .from("rss_sources")
            .select("*")
            .eq("is_active", value: true)
            .order("name")
            .execute()
        
        return response.value
    }
    
    func getUserRSSFeeds(userId: UUID) async throws -> [UserRSSFeed] {
        let response: PostgrestResponse<[UserRSSFeed]> = try await client
            .from("user_rss_feeds")
            .select("*, rss_sources(*)")
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .order("affinity_score", ascending: false)
            .execute()
        
        return response.value
    }
    
    func subscribeToRSSFeeds(userId: UUID, rssSourceIds: [UUID]) async throws {
        let subscriptions = rssSourceIds.map { sourceId in
            [
                "user_id": AnyJSON.string(userId.uuidString),
                "rss_source_id": AnyJSON.string(sourceId.uuidString),
                "affinity_score": .init(floatLiteral: 1.0),
                "is_active": AnyJSON.bool(true),
                "subscription_strength": .init(floatLiteral: 1.0),
                "subscribed_at": AnyJSON.string(Date().toISOString()),
                "created_at": AnyJSON.string(Date().toISOString())
            ]
        }
        
        try await client
            .from("user_rss_feeds")
            .insert(subscriptions)
            .execute()
    }
    
    // MARK: - Article Management
    
    func getArticles(userId: UUID, limit: Int = 20, offset: Int = 0) async throws -> [Article] {
        let response: PostgrestResponse<[Article]> = try await client
            .from("articles")
            .select("*")
            .order("published_date", ascending: false)
            .range(from: offset, to: offset + limit - 1)
            .execute()
        
        return response.value
    }
    
    func getArticle(id: UUID) async throws -> Article? {
        do {
            let response: PostgrestResponse<Article> = try await client
                .from("articles")
                .select("*")
                .eq("id", value: id)
                .single()
                .execute()
            
            return response.value
        } catch {
            // Article with this ID doesn't exist
            print("⚠️ Article not found with ID: \(id)")
            return nil
        }
    }
    
    func getQuizCards(articleId: UUID) async throws -> [QuizCard] {
        let response: PostgrestResponse<[QuizCard]> = try await client
            .from("flashcards")
            .select("*")
            .eq("article_id", value: articleId)
            .eq("is_active", value: true)
            .order("card_order")
            .execute()
        
        return response.value
    }
    
    // MARK: - Study Session Management
    
    func createStudySession(userId: UUID, sessionType: String, focusTopics: [String]) async throws -> UUID {
        let sessionId = UUID()
        let sessionData: [String: AnyJSON] = [
            "id": .string(sessionId.uuidString),
            "user_id": .string(userId.uuidString),
            "session_type": .string(sessionType),
            "focus_topics": .array(focusTopics.map { .string($0) }),
            "started_at": .string(Date().toISOString()),
            "is_completed": .bool(false)
        ]
        
        try await client
            .from("study_sessions_old")
            .insert(sessionData)
            .execute()
        
        return sessionId
    }
    
    func completeStudySession(sessionId: UUID, stats: StudySessionStats) async throws {
        let updateData: [String: AnyJSON] = [
            "completed_at": .string(Date().toISOString()),
            "is_completed": .bool(true),
            "cards_studied": .init(integerLiteral: stats.cardsStudied),
            "correct_answers": .init(integerLiteral: stats.correctAnswers),
            "session_duration": .init(integerLiteral: stats.sessionDuration),
            "accuracy_rate": .init(floatLiteral: stats.accuracyRate)
        ]
        
        try await client
            .from("study_sessions_old")
            .update(updateData)
            .eq("id", value: sessionId)
            .execute()
    }
    
    // MARK: - Performance Tracking
    
    func getUserQuizPerformance(userId: UUID, quizCardId: UUID) async throws -> UserQuizPerformance? {
        do {
            let response: PostgrestResponse<UserQuizPerformance> = try await client
                .from("user_quiz_performance")
                .select("*")
                .eq("user_id", value: userId)
                .eq("quiz_card_id", value: quizCardId)
                .single()
                .execute()
            
            return response.value
        } catch {
            // No performance record exists for this user/card combination
            return nil
        }
    }
    
    func updateQuizPerformance(userId: UUID, quizCardId: UUID, performance: UserQuizPerformance) async throws {
        let performanceData: [String: AnyJSON] = [
            "user_id": .string(userId.uuidString),
            "quiz_card_id": .string(quizCardId.uuidString),
            "is_starred": .bool(performance.isStarred),
            "total_attempts": .init(integerLiteral: performance.totalAttempts),
            "correct_attempts": .init(integerLiteral: performance.correctAttempts),
            "last_studied": .string(performance.lastStudied?.toISOString() ?? ""),
            "mastery_level": .init(floatLiteral: performance.masteryLevel),
            "ease_factor": .init(floatLiteral: performance.easeFactor),
            "interval_days": .init(floatLiteral: Double(performance.intervalDays)),
            "next_review_date": .string(performance.nextReviewDate.toISOString()),
            "review_stage": .init(floatLiteral: Double(performance.reviewStage)),
            "consecutive_correct": .init(floatLiteral: Double(performance.consecutiveCorrect)),
            "consecutive_incorrect": .init(floatLiteral: Double(performance.consecutiveIncorrect)),
            "avg_response_time": .init(floatLiteral: Double(performance.avgResponseTime)),
            "difficulty_rating": .init(floatLiteral: Double(performance.difficultyRating ?? 3)),
            "updated_at": .string(Date().toISOString())
        ]
        
        try await client
            .from("user_quiz_performance")
            .upsert(performanceData)
            .execute()
    }
    
    func initializeUserPerformanceRecords(userId: UUID, quizCardIds: [UUID]) async throws {
        let records = quizCardIds.map { cardId in
            [
                "user_id": AnyJSON.string(userId.uuidString),
                "quiz_card_id": AnyJSON.string(cardId.uuidString),
                "is_starred": AnyJSON.bool(false),
                "total_attempts": AnyJSON.init(integerLiteral: 0),
                "correct_attempts": AnyJSON.init(integerLiteral: 0),
                "mastery_level": AnyJSON.init(integerLiteral: 0),
                "ease_factor": AnyJSON.init(floatLiteral: 2.5),
                "interval_days": AnyJSON.init(integerLiteral: 1),
                "next_review_date": AnyJSON.string(Date().toISOString()),
                "review_stage": AnyJSON.init(integerLiteral: 0),
                "consecutive_correct": AnyJSON.init(integerLiteral: 0),
                "consecutive_incorrect": AnyJSON.init(integerLiteral: 0),
                "avg_response_time": AnyJSON.init(integerLiteral: 0),
                "difficulty_rating": AnyJSON.init(integerLiteral: 3),
                "created_at": AnyJSON.string(Date().toISOString()),
                "updated_at": AnyJSON.string(Date().toISOString())
            ]
        }
        
        try await client
            .from("user_quiz_performance")
            .insert(records)
            .execute()
    }
    
    // MARK: - Gamification Methods
    
    func fetchUserProgress(userId: UUID) async throws -> UserProgress {
        do {
            let response: PostgrestResponse<UserProgress> = try await client
                .from("user_stats")
                .select("*")
                .eq("user_id", value: userId)
                .single()
                .execute()
            
            return response.value
        } catch {
            // User stats don't exist, create new ones
        }
        
        // Create new user stats if not exists
        let newProgress = UserProgress(
            userId: userId,
            xp: 0,
            coins: 100,
            gems: 5,
            currentStreak: 0,
            longestStreak: 0,
            lastStudyDate: nil,
            level: 1,
            dailyGoalMinutes: 15,
            dailyMinutesStudied: 0,
            totalStudyTimeMinutes: 0
        )
        
        let _: PostgrestResponse<UserProgress> = try await client
            .from("user_stats")
            .insert(newProgress)
            .single()
            .execute()
        
        return newProgress
    }
    
    func saveStudySession(_ session: StudySession) async throws {
        let sessionData: [String: AnyJSON] = [
            "id": .string(session.id.uuidString),
            "user_id": .string(session.userId.uuidString),
            "session_type": .string(session.sessionType.rawValue),
            "started_at": .string(session.startedAt.toISOString()),
            "ended_at": .string(session.completedAt?.toISOString() ?? ""),
            "duration_minutes": .init(integerLiteral: Int(session.sessionDuration / 60)),
            "cards_studied": .init(integerLiteral: session.cardsStudied),
            "correct_count": .init(integerLiteral: session.correctAnswers),
            "xp_earned": .init(integerLiteral: session.sessionXP),
            "coins_earned": .init(integerLiteral: session.sessionCoins),
            "perfect_streak": .init(integerLiteral: session.perfectStreak)
        ]
        
        try await client
            .from("study_sessions")
            .insert(sessionData)
            .execute()
    }
    
    func generateTestQuestions(userId: UUID, articleId: UUID) async throws -> [TestQuestion] {
        // Fetch mastered flashcards
        let response: PostgrestResponse<[QuizCard]> = try await client
            .from("flashcards")
            .select("*, user_quiz_performance!inner(*)")
            .eq("article_id", value: articleId)
            .eq("user_quiz_performance.user_id", value: userId)
            .eq("user_quiz_performance.flashcard_mastered", value: true)
            .execute()
        
        let _ = response.value
        
        // For now, return empty array - this would be implemented with proper edge function calls
        return []
    }
    
    func generateFlashcardsForArticles(articleIds: [UUID]) async throws {
        // This would call the edge function to generate flashcards for articles
        // For now, this is a placeholder
        // TODO: Implement proper edge function calls
    }
    
    func fetchUserArticles(userId: UUID) async throws -> [Article] {
        return try await getArticles(userId: userId)
    }
    
    func starFlashcard(userId: UUID, cardId: UUID, isStarred: Bool) async throws {
        try await updateQuizPerformance(userId: userId, quizCardId: cardId, performance: UserQuizPerformance(
            id: UUID(),
            userId: userId,
            quizCardId: cardId,
            isStarred: isStarred,
            totalAttempts: 0,
            correctAttempts: 0,
            lastStudied: nil,
            masteryLevel: 0,
            easeFactor: 2.5,
            intervalDays: 1,
            nextReviewDate: Date(),
            reviewStage: 0,
            consecutiveCorrect: 0,
            consecutiveIncorrect: 0,
            avgResponseTime: 0,
            difficultyRating: 3,
            createdAt: Date(),
            updatedAt: Date()
        ))
    }
    
    func fetchFlashcardsForStudyMode(userId: UUID, mode: String, limit: Int) async throws -> [DueFlashcard] {
        print("🔍 Fetching flashcards for user: \(userId), mode: \(mode), limit: \(limit)")
        
        // First, try to get ALL flashcards without filtering to see if any exist
        do {
            let allResponse: PostgrestResponse<[QuizCard]> = try await client
                .from("flashcards")
                .select("*")
                .limit(limit)
                .execute()
            
            print("📊 Total flashcards in database: \(allResponse.value.count)")
            if let first = allResponse.value.first {
                print("📝 Sample flashcard: ID=\(first.id), Question=\(first.question.prefix(50))...")
            }
        } catch {
            print("❌ Error fetching all flashcards: \(error)")
        }
        
        // Now get active flashcards specifically for this user
        let response: PostgrestResponse<[QuizCard]> = try await client
            .from("flashcards")
            .select("*")
            .eq("user_id", value: userId.uuidString)
            .eq("is_active", value: true)
            .limit(limit)
            .execute()
        
        let flashcards = response.value
        print("📋 Active flashcards from database: \(flashcards.count)")
        
        if flashcards.isEmpty {
            print("⚠️ No active flashcards found. Checking if any flashcards exist without is_active filter...")
            
            // Try without the is_active filter to see if the issue is with that field
            let unfiltered: PostgrestResponse<[QuizCard]> = try await client
                .from("flashcards")
                .select("*")
                .eq("user_id", value: userId.uuidString)
                .limit(limit)
                .execute()
            
            print("📊 Unfiltered flashcards: \(unfiltered.value.count)")
            
            if !unfiltered.value.isEmpty {
                print("✅ Found flashcards without is_active filter. Using those instead.")
                let dueFlashcards = unfiltered.value.map { flashcard in
                    DueFlashcard(
                        id: UUID(),
                        userId: userId,
                        quizCardId: flashcard.id,
                        masteryLevel: 0.0,
                        nextReviewDate: Date(),
                        isStarred: false,
                        lastStudied: nil,
                        totalAttempts: 0,
                        correctAttempts: 0,
                        quizCard: flashcard
                    )
                }
                
                print("📚 Created \(dueFlashcards.count) DueFlashcard objects for study mode: \(mode)")
                return dueFlashcards
            }
            
            return []
        }
        
        // Convert to DueFlashcard format that matches the existing struct
        let dueFlashcards = flashcards.map { flashcard in
            DueFlashcard(
                id: UUID(), // Generate new ID for DueFlashcard record
                userId: userId,
                quizCardId: flashcard.id,
                masteryLevel: 0.0, // Default mastery level
                nextReviewDate: Date(), // All cards are due now
                isStarred: false, // Default not starred
                lastStudied: nil, // No study history yet
                totalAttempts: 0,
                correctAttempts: 0,
                quizCard: flashcard
            )
        }
        
        print("📚 Created \(dueFlashcards.count) DueFlashcard objects for study mode: \(mode)")
        return dueFlashcards
    }
    
    func recordQuizAttempt(userId: UUID, cardId: UUID, correct: Bool, timeSpent: TimeInterval) async throws {
        // Placeholder implementation
    }
    
    func startStudySession(userId: UUID, sessionType: String, focusTopics: [String]) async throws -> UUID {
        return try await createStudySession(userId: userId, sessionType: sessionType, focusTopics: focusTopics)
    }
    
    func addCustomSource(userId: UUID, name: String, url: String, description: String?, category: String) async throws {
        let sourceData: [String: AnyJSON] = [
            "id": .string(UUID().uuidString),
            "name": .string(name),
            "url": .string(url),
            "description": .string(description ?? ""),
            "category": .string(category),
            "is_active": .bool(true),
            "user_added": .bool(true),
            "created_at": .string(Date().toISOString()),
            "updated_at": .string(Date().toISOString())
        ]
        
        try await client
            .from("rss_sources")
            .insert(sourceData)
            .execute()
    }
    
    func generateFlashcards(articleIds: [UUID]) async throws {
        // Use current authenticated user or fall back to dev user ID for development
        let userId: UUID
        if let currentUser = getCurrentUser() {
            userId = currentUser.id
        } else {
            // Use the consistent dev user ID for development
            userId = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
            print("🔧 Using dev user ID for flashcard generation: \(userId)")
        }
        
        for articleId in articleIds {
            // Get article content first
            guard let article = try await getArticle(id: articleId) else {
                print("❌ Article not found for ID: \(articleId)")
                continue
            }
            
            // Call the process-content edge function
            let functionData: [String: AnyJSON] = [
                "sourceId": .string(articleId.uuidString),
                "sourceType": .string("text"),
                "content": .string(article.content),
                "userId": .string(userId.uuidString)
            ]
            
            do {
                let _ = try await client.functions
                    .invoke(
                        "process-content",
                        options: FunctionInvokeOptions(
                            body: functionData
                        )
                    )
                
                print("✅ Successfully called process-content edge function for article: \(articleId)")
                
                // The edge function handles saving articles and quiz cards to database
                // No need to manually save here
                
            } catch {
                print("❌ Failed to call process-content edge function: \(error)")
                throw error
            }
        }
    }
    
    func initializeAllUserPerformanceRecords(userId: UUID) async throws {
        // Placeholder implementation - would initialize performance records for all cards
    }
    
    func updateUserProgress(userId: UUID, progress: UserProgress) async throws {
        let progressData: [String: AnyJSON] = [
            "xp": .init(floatLiteral: Double(progress.xp)),
            "coins": .init(floatLiteral: Double(progress.coins)),
            "gems": .init(floatLiteral: Double(progress.gems)),
            "current_streak": .init(floatLiteral: Double(progress.currentStreak)),
            "longest_streak": .init(floatLiteral: Double(progress.longestStreak)),
            "last_study_date": .string(progress.lastStudyDate?.toISOString() ?? ""),
            "level": .init(floatLiteral: Double(progress.level)),
            "daily_goal_minutes": .init(floatLiteral: Double(progress.dailyGoalMinutes)),
            "daily_minutes_studied": .init(floatLiteral: Double(progress.dailyMinutesStudied)),
            "total_study_time_minutes": .init(floatLiteral: Double(progress.totalStudyTimeMinutes)),
            "updated_at": .string(Date().toISOString())
        ]
        
        try await client
            .from("user_stats")
            .update(progressData)
            .eq("user_id", value: userId)
            .execute()
    }
    
    func updateFlashcardMastery(userId: UUID, cardId: UUID, masteryLevel: Double) async throws {
        let updateData: [String: AnyJSON] = [
            "mastery_level": .init(floatLiteral: masteryLevel),
            "flashcard_mastered": .bool(masteryLevel >= 0.8),
            "updated_at": .string(Date().toISOString())
        ]
        
        try await client
            .from("user_quiz_performance")
            .update(updateData)
            .eq("user_id", value: userId)
            .eq("quiz_card_id", value: cardId)
            .execute()
    }
    
    func fetchUserAchievements(userId: UUID) async throws -> [Achievement] {
        // Placeholder implementation - return empty array
        return []
    }
    
    func purchasePowerUp(userId: UUID, powerUpId: UUID, cost: Int) async throws {
        // Placeholder implementation for purchasing power-ups
    }
    
    func fetchUserFlashcards(userId: UUID) async throws -> [DueFlashcard] {
        // Placeholder implementation - return empty array
        return []
    }
    
    func fetchTopics() async throws -> [Topic] {
        // Placeholder implementation - return empty array
        return []
    }
    
    func saveTopicSelections(userId: UUID, topics: [Topic]) async throws {
        // Placeholder implementation for saving topic selections
    }
    
    func updateArticleStatus(userArticleId: UUID, status: String) async throws {
        // Placeholder implementation for updating article status
    }
    
    func createUserArticle(_ userArticle: Any) async throws {
        // Placeholder implementation for creating user article
    }
    
    func createArticle(_ article: Article) async throws -> Article {
        // Check if article already exists by URL
        if let url = article.url, !url.isEmpty {
            let existingResponse: PostgrestResponse<[Article]> = try await client
                .from("articles")
                .select("*")
                .eq("url", value: url)
                .execute()
            
            if let existingArticle = existingResponse.value.first {
                print("✅ Article already exists with URL: \(url)")
                return existingArticle
            }
        }
        
        let articleData: [String: AnyJSON] = [
            "id": .string(article.id.uuidString),
            "title": .string(article.title),
            "content": .string(article.content),
            "url": .string(article.url ?? ""),
            "source_type": .string(article.source.rawValue),
            "topic": .string(article.topic ?? "General"),
            "image_url": .string(article.imageURL ?? ""),
            "published_date": .string(article.publishedDate.toISOString()),
            "difficulty_level": .string("medium"),
            "estimated_read_time": .init(integerLiteral: max(1, article.content.split(separator: " ").count / 200)),
            "created_at": .string(Date().toISOString()),
            "updated_at": .string(Date().toISOString())
        ]
        
        let response: PostgrestResponse<Article> = try await client
            .from("articles")
            .insert(articleData)
            .select("*")
            .single()
            .execute()
        
        return response.value
    }
}

// MARK: - Extensions

extension Date {
    func toISOString() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: self)
    }
}

// MARK: - Helper Structs

struct StudySessionStats {
    let cardsStudied: Int
    let correctAnswers: Int
    let sessionDuration: Int
    let accuracyRate: Double
}

// RSSSource and UserRSSFeed are defined in RSSService.swift

struct DueFlashcard: Codable {
    let id: UUID
    let userId: UUID
    let quizCardId: UUID
    let masteryLevel: Double
    let nextReviewDate: Date
    let isStarred: Bool
    let lastStudied: Date?
    let totalAttempts: Int
    let correctAttempts: Int
    let quizCard: QuizCard
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case quizCardId = "quiz_card_id"
        case masteryLevel = "mastery_level"
        case nextReviewDate = "next_review_date"
        case isStarred = "is_starred"
        case lastStudied = "last_studied"
        case totalAttempts = "total_attempts"
        case correctAttempts = "correct_attempts"
        case quizCard = "flashcards"
    }
}

struct UserProfile: Codable {
    let id: UUID
    let email: String
    let occupation: String?
    let companyInterests: [String]
    let overallAccuracy: Double
    let streakDays: Int
    let lastStudyDate: Date?
    let onboardingComplete: Bool
    let skillLevel: String
    let preferredDifficulty: String
    let dailyStudyGoal: Int
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

struct UserQuizPerformance: Codable {
    let id: UUID
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
    var createdAt: Date
    var updatedAt: Date
    
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
        case consecutiveCorrect = "consecutive_correct"
        case consecutiveIncorrect = "consecutive_incorrect"
        case avgResponseTime = "avg_response_time"
        case difficultyRating = "difficulty_rating"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

enum SupabaseError: Error {
    case authenticationFailed
    case userNotFound
    case insertFailed
    case updateFailed
    case networkError
    case invalidData
}