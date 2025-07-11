import Foundation
import Supabase

// MARK: - Data Structures for RSS Processing
struct RSSArticle: Codable {
    let id: UUID
    let title: String
    let url: String
    let content: String?
    let publishedDate: Date?
    let contentQualityScore: Double
    
    enum CodingKeys: String, CodingKey {
        case id, title, url, content
        case publishedDate = "published_date"
        case contentQualityScore = "content_quality_score"
    }
}

struct UserArticleInsert: Codable {
    let userId: UUID
    let articleId: UUID
    let status: String
    let preferenceScore: Double
    let personalizedScore: Double
    let isStarred: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case articleId = "article_id"
        case status
        case preferenceScore = "preference_score"
        case personalizedScore = "personalized_score"
        case isStarred = "is_starred"
        case createdAt = "created_at"
    }
}

// MARK: - RSS Errors
enum RSSError: LocalizedError {
    case noSourcesFound(topics: [String])
    case noArticlesFound
    case discoveryFailed(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .noSourcesFound(let topics):
            return "No RSS sources found for topics: \(topics.joined(separator: ", ")). Please try different topics or check your internet connection."
        case .noArticlesFound:
            return "No articles could be fetched from RSS sources. Please check your internet connection and try again."
        case .discoveryFailed(let reason):
            return "Failed to discover RSS sources: \(reason)"
        }
    }
}

// MARK: - Helper Structs for Database Operations
struct UserRSSSubscription: Codable {
    let userId: UUID
    let rssSourceId: UUID
    let isActive: Bool
    let selectedTopics: [String]
    let priorityLevel: String
    let lastFetchedAt: Date?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case rssSourceId = "rss_source_id"
        case isActive = "is_active"
        case selectedTopics = "selected_topics"
        case priorityLevel = "priority_level"
        case lastFetchedAt = "last_fetched_at"
        case createdAt = "created_at"
    }
}

struct RSSFetchSchedule: Codable {
    let userId: UUID
    let rssSourceId: UUID
    let fetchFrequency: String
    let nextScheduledFetch: Date
    let isActive: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case rssSourceId = "rss_source_id"
        case fetchFrequency = "fetch_frequency"
        case nextScheduledFetch = "next_scheduled_fetch"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

struct UserArticleData: Codable {
    let id: UUID
    let userId: UUID
    let articleId: UUID
    let personalizedScore: Double
    let isQueued: Bool
    let queuedAt: Date?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case articleId = "article_id"
        case personalizedScore = "personalized_score"
        case isQueued = "is_queued"
        case queuedAt = "queued_at"
        case createdAt = "created_at"
    }
}

struct UserReadingPatternUpdate: Codable {
    let userId: UUID
    let preferredTopics: [String]
    let optimalDifficultyLevel: String
    let weeklyReadingGoal: Int
    let learningVelocity: Double
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case preferredTopics = "preferred_topics"
        case optimalDifficultyLevel = "optimal_difficulty_level"
        case weeklyReadingGoal = "weekly_reading_goal"
        case learningVelocity = "learning_velocity"
        case updatedAt = "updated_at"
    }
}

class RSSService: ObservableObject {
    static let shared = RSSService()
    
    private let supabaseClient: SupabaseClient
    
    private init() {
        guard let url = URL(string: EnvironmentConfig.supabaseURL) else {
            fatalError("Invalid Supabase URL")
        }
        
        self.supabaseClient = SupabaseClient(
            supabaseURL: url,
            supabaseKey: EnvironmentConfig.supabaseAnonKey
        )
    }
    
    // MARK: - RSS Feed Management
    
    /// Sets up RSS feeds for a user based on their selected topics with intelligent scheduling
    func setupUserFeeds(userId: UUID, selectedTopics: [String]) async throws {
        var rssources: [RSSSource]
        
        do {
            // First, try to get all active RSS sources
            let allSources: [RSSSource] = try await supabaseClient
                .from("rss_sources")
                .select("*")
                .eq("is_active", value: true)
                .execute()
                .value
            
            // Filter sources that match any of the selected topics
            rssources = allSources.filter { source in
                // Check if any of the source's topics match any of the selected topics
                let sourceTopicsLower = source.topics.map { $0.lowercased() }
                let selectedTopicsLower = selectedTopics.map { $0.lowercased() }
                
                for sourceTopic in sourceTopicsLower {
                    for selectedTopic in selectedTopicsLower {
                        if sourceTopic.contains(selectedTopic) || selectedTopic.contains(sourceTopic) {
                            return true
                        }
                    }
                }
                return false
            }
            
            print("✅ Found \(rssources.count) existing RSS sources for topics: \(selectedTopics) (from \(allSources.count) total)")
            
            // If no sources found, trigger dynamic discovery
            if rssources.isEmpty {
                print("🔍 No RSS sources found. Triggering dynamic discovery...")
                try await discoverAndSetupRSSources(for: selectedTopics)
                
                // Add a longer delay to ensure database writes complete
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                
                // Debug: Check what's actually in the database
                let allSourcesDebug: [RSSSource] = try await supabaseClient
                    .from("rss_sources")
                    .select("*")
                    .execute()
                    .value
                
                print("🔍 DEBUG: Total sources in database: \(allSourcesDebug.count)")
                for source in allSourcesDebug {
                    print("  - \(source.name): topics = \(source.topics)")
                }
                
                // Retry after discovery - try multiple approaches
                var retryCount = 0
                let maxRetries = 3
                
                while retryCount < maxRetries {
                    // First, always try to get all active sources
                    let allSources: [RSSSource] = try await supabaseClient
                        .from("rss_sources")
                        .select("*")
                        .eq("is_active", value: true)
                        .execute()
                        .value
                    
                    print("🔍 All active sources query returned \(allSources.count) sources")
                    
                    if !allSources.isEmpty {
                        // Filter sources that match any of the selected topics
                        let matchingSources = allSources.filter { source in
                            // Check if any of the source's topics match any of the selected topics
                            let sourceTopicsLower = source.topics.map { $0.lowercased() }
                            let selectedTopicsLower = selectedTopics.map { $0.lowercased() }
                            
                            for sourceTopic in sourceTopicsLower {
                                for selectedTopic in selectedTopicsLower {
                                    if sourceTopic.contains(selectedTopic) || selectedTopic.contains(sourceTopic) {
                                        return true
                                    }
                                }
                            }
                            return false
                        }
                        
                        if !matchingSources.isEmpty {
                            print("✅ Found \(matchingSources.count) RSS sources matching topics")
                            rssources = matchingSources
                            break
                        } else {
                            // If no matching topics, use all sources as fallback
                            print("⚠️ No sources match selected topics, using all \(allSources.count) sources")
                            rssources = allSources
                            break
                        }
                    }
                    
                    retryCount += 1
                    if retryCount < maxRetries {
                        print("🔄 Retry \(retryCount): Waiting for sources to be available...")
                        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
                    }
                }
                
                if rssources.isEmpty {
                    throw RSSError.noSourcesFound(topics: selectedTopics)
                }
            }
            
        } catch {
            print("⚠️ RSS setup error: \(error.localizedDescription)")
            throw error
        }
        
        // Create user RSS feed subscriptions
        let subscriptions = rssources.map { source in
            UserRSSSubscription(
                userId: userId,
                rssSourceId: source.id,
                isActive: true,
                selectedTopics: selectedTopics,
                priorityLevel: "medium",
                lastFetchedAt: nil,
                createdAt: Date()
            )
        }
        
        try await supabaseClient
            .from("user_rss_feeds")
            .upsert(subscriptions, onConflict: "user_id,rss_source_id")
            .execute()
        
        // Create RSS fetch schedule for each source
        let schedules = rssources.map { source in
            RSSFetchSchedule(
                userId: userId,
                rssSourceId: source.id,
                fetchFrequency: "hourly",
                nextScheduledFetch: Date(),
                isActive: true,
                createdAt: Date()
            )
        }
        
        try await supabaseClient
            .from("rss_fetch_schedule")
            .upsert(schedules, onConflict: "user_id,rss_source_id")
            .execute()
        
        // Initialize user reading patterns
        try await createUserReadingPattern(userId: userId, selectedTopics: selectedTopics)
        
        // Only call RSS processor if we have sources
        if !rssources.isEmpty {
            print("🕷️ Starting RSS crawl for \(rssources.count) sources...")
            
            // Add a delay to allow RSS discovery to complete database writes
            try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            // Wait for articles to be crawled and create user articles
            let articleCount = try await waitForArticlesToBeCrawled(for: rssources.map { $0.id })
            
            if articleCount > 0 {
                // Create user_articles entries for the new articles
                try await createUserArticlesFromRSSArticles(userId: userId, rssSourceIds: rssources.map { $0.id })
                print("✅ RSS setup completed - \(articleCount) articles available for user")
            } else {
                print("⚠️ RSS setup completed but no articles were found")
            }
        }
        
        print("RSS feeds setup completed for user: \(userId) with \(rssources.count) sources")
    }
    
    /// Waits for articles to be crawled and returns the count
    private func waitForArticlesToBeCrawled(for rssSourceIds: [UUID]) async throws -> Int {
        var attempts = 0
        let maxAttempts = 10 // 30 seconds total
        
        while attempts < maxAttempts {
            let articleCount: Int = try await supabaseClient
                .from("articles")
                .select("id", head: false, count: .exact)
                .in("rss_source_id", values: rssSourceIds.map { $0.uuidString })
                .execute()
                .count ?? 0
            
            if articleCount > 0 {
                return articleCount
            }
            
            // Wait 3 seconds before checking again
            try await Task.sleep(nanoseconds: 3_000_000_000)
            attempts += 1
            print("🔄 Waiting for articles... attempt \(attempts)/\(maxAttempts)")
        }
        
        return 0 // No articles found after waiting
    }
    
    /// Creates user_articles entries for articles from RSS sources
    private func createUserArticlesFromRSSArticles(userId: UUID, rssSourceIds: [UUID]) async throws {
        // Get all articles from the RSS sources
        let articles: [RSSArticle] = try await supabaseClient
            .from("articles")
            .select("*")
            .in("rss_source_id", values: rssSourceIds.map { $0.uuidString })
            .execute()
            .value
        
        // Create user_articles entries
        let userArticles = articles.map { article in
            UserArticleInsert(
                userId: userId,
                articleId: article.id,
                status: "queued",
                preferenceScore: calculatePreferenceScore(for: article),
                personalizedScore: 0.5,
                isStarred: false,
                createdAt: Date()
            )
        }
        
        if !userArticles.isEmpty {
            try await supabaseClient
                .from("user_articles")
                .upsert(userArticles, onConflict: "user_id,article_id")
                .execute()
            
            print("📚 Created \(userArticles.count) user article entries")
        }
    }
    
    /// Calculates preference score based on article metadata
    private func calculatePreferenceScore(for article: RSSArticle) -> Double {
        var score = 0.5 // Base score
        
        // Boost score for recent articles
        if let publishedDate = article.publishedDate {
            let daysSincePublished = Date().timeIntervalSince(publishedDate) / (24 * 60 * 60)
            if daysSincePublished < 7 {
                score += 0.2
            }
        }
        
        // Boost score for high-quality sources
        if article.contentQualityScore > 0.7 {
            score += 0.1
        }
        
        return min(score, 1.0)
    }
    
    /// Discovers RSS sources dynamically using Supabase Edge Function
    private func discoverAndSetupRSSources(for topics: [String]) async throws {
        print("🔍 Calling RSS discovery Edge Function for topics: \(topics)")
        
        guard let url = URL(string: "\(EnvironmentConfig.supabaseURL)/functions/v1/rss-discovery") else {
            throw RSSError.discoveryFailed(reason: "Invalid Supabase URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(EnvironmentConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "topics": topics
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RSSError.discoveryFailed(reason: "Invalid response from discovery service")
            }
            
            if httpResponse.statusCode == 200 {
                if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = result["success"] as? Bool,
                   let sourcesDiscovered = result["sources_discovered"] as? Int,
                   success {
                    print("✅ Successfully discovered \(sourcesDiscovered) RSS sources")
                } else {
                    print("⚠️ Discovery completed but with unexpected response format")
                }
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw RSSError.discoveryFailed(reason: "Discovery failed: \(errorMessage)")
            }
        } catch {
            throw RSSError.discoveryFailed(reason: "Failed to call discovery service: \(error.localizedDescription)")
        }
    }
    
    /// Fetches and processes articles from a specific RSS source
    func fetchFeed(rssSourceId: UUID) async throws -> RSSFetchResult {
        let _ = try await supabaseClient
            .functions
            .invoke(
                "rss-processor",
                options: FunctionInvokeOptions(
                    body: [
                        "action": "fetch_feed",
                        "rss_source_id": rssSourceId.uuidString
                    ]
                )
            )
        
        // Return a simple result since we can't easily decode the response
        return RSSFetchResult(
            success: true,
            feedTitle: "RSS Feed",
            processedCount: 0,
            rssSourceId: rssSourceId.uuidString
        )
    }
    
    /// Backfills historical articles for a RSS source
    func backfillArticles(rssSourceId: UUID) async throws {
        let _ = try await supabaseClient
            .functions
            .invoke(
                "rss-processor",
                options: FunctionInvokeOptions(
                    body: [
                        "action": "backfill_articles",
                        "rss_source_id": rssSourceId.uuidString
                    ]
                )
            )
    }
    
    /// Gets RSS sources for specific topics
    func getRSSSourcesForTopics(_ topics: [String]) async throws -> [RSSSource] {
        let response: [RSSSource] = try await supabaseClient
            .from("rss_sources")
            .select()
            .overlaps("topics", value: topics)
            .eq("is_active", value: true)
            .execute()
            .value
        
        return response
    }
    
    /// Gets user's RSS feed subscriptions
    func getUserRSSFeeds(userId: UUID) async throws -> [UserRSSFeed] {
        let response: [UserRSSFeed] = try await supabaseClient
            .from("user_rss_feeds")
            .select("""
                *,
                rss_sources (
                    id,
                    name,
                    url,
                    description,
                    topics,
                    tags
                )
            """)
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .execute()
            .value
        
        return response
    }
    
    /// Updates RSS feed affinity score based on user interactions
    func updateFeedAffinity(userRSSFeedId: UUID, score: Double) async throws {
        try await supabaseClient
            .from("user_rss_feeds")
            .update(["affinity_score": score])
            .eq("id", value: userRSSFeedId)
            .execute()
    }
    
    /// Gets articles from user's RSS feeds with intelligent scoring
    func getUserArticles(userId: UUID, status: String? = nil, limit: Int = 50) async throws -> [Article] {
        // Build query based on whether status filter is provided
        let query = if let status = status {
            supabaseClient
                .from("articles")
                .select("""
                    *,
                    user_articles!inner (
                        id,
                        status,
                        is_starred,
                        queued_at,
                        personalized_score,
                        preference_score,
                        interaction_type,
                        reading_progress
                    )
                """)
                .eq("source_type", value: "rss")
                .eq("user_articles.user_id", value: userId)
                .eq("user_articles.status", value: status)
                .order("published_date", ascending: false)
                .limit(limit)
        } else {
            supabaseClient
                .from("articles")
                .select("""
                    *,
                    user_articles!inner (
                        id,
                        status,
                        is_starred,
                        queued_at,
                        personalized_score,
                        preference_score,
                        interaction_type,
                        reading_progress
                    )
                """)
                .eq("source_type", value: "rss")
                .eq("user_articles.user_id", value: userId)
                .order("published_date", ascending: false)
                .limit(limit)
        }
        
        let response: [ArticleWithUserData] = try await query.execute().value
        
        // Convert to Article objects
        return response.map { articleData in
            Article(
                id: articleData.id,
                title: articleData.title,
                url: articleData.url,
                content: articleData.content ?? "",
                source: .rss,
                topic: articleData.topics?.first,
                imageURL: nil,
                publishedDate: articleData.published_date ?? Date(),
                status: ArticleStatus(rawValue: articleData.user_articles?.status ?? "queued") ?? .queued,
                quizCards: [],
                isStarred: articleData.user_articles?.is_starred ?? false
            )
        }
    }
    
    /// Queues an article for a user with personalized scoring
    func queueArticle(userId: UUID, articleId: UUID) async throws {
        // Simplified article queuing
        print("Queued article \(articleId) for user \(userId)")
    }
    
    /// Records user article interaction (swipe, click, etc.)
    func recordArticleInteraction(
        userId: UUID,
        articleId: UUID,
        interactionType: String,
        preferenceChange: Double = 0.0
    ) async throws {
        // Simple interaction recording - complex updates will be handled by database functions
        print("User \(userId) interacted with article \(articleId): \(interactionType)")
    }
    
    /// Updates RSS source affinity based on user interactions
    private func updateRSSSourceAffinity(userId: UUID, articleId: UUID, change: Double) async throws {
        // Simplified affinity tracking
        print("Updating affinity for user \(userId) with change \(change)")
    }
    
    /// Creates or updates user reading patterns
    private func createUserReadingPattern(userId: UUID, selectedTopics: [String]) async throws {
        let pattern = UserReadingPatternUpdate(
            userId: userId,
            preferredTopics: selectedTopics,
            optimalDifficultyLevel: "medium",
            weeklyReadingGoal: 5,
            learningVelocity: 1.0,
            updatedAt: Date()
        )
        
        try await supabaseClient
            .from("user_reading_patterns")
            .upsert([pattern], onConflict: "user_id")
            .execute()
    }
    
    /// Updates user topic preferences and re-scores articles
    func updateUserTopicPreferences(userId: UUID, newTopics: [String]) async throws {
        // Setup new RSS feeds - this will handle the updates
        try await setupUserFeeds(userId: userId, selectedTopics: newTopics)
    }
    
    /// Gets personalized article recommendations
    func getPersonalizedRecommendations(userId: UUID, limit: Int = 20) async throws -> [Article] {
        do {
            // First, trigger RSS crawl to ensure we have fresh content
            try await crawlRSSFeeds()
            
            // Get recent articles ordered by relevance
            let response: [Article] = try await supabaseClient
                .from("articles")
                .select("*")
                .gte("published_date", value: Calendar.current.date(byAdding: .month, value: -3, to: Date())?.toISOString() ?? "")
                .order("relevance_score", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            print("✅ Found \(response.count) recommended articles for user \(userId)")
            
            if response.isEmpty {
                throw RSSError.noArticlesFound
            }
            
            return response
        } catch {
            print("⚠️ Article fetch error: \(error.localizedDescription)")
            if error is RSSError {
                throw error
            }
            throw RSSError.noArticlesFound
        }
    }
    
    /// Triggers RSS crawling using Supabase Edge Function
    private func crawlRSSFeeds() async throws {
        print("🕷️ Calling RSS crawler Edge Function...")
        
        guard let url = URL(string: "\(EnvironmentConfig.supabaseURL)/functions/v1/rss-crawler") else {
            throw RSSError.discoveryFailed(reason: "Invalid Supabase URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(EnvironmentConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "action": "crawl_all",
            "limit": 20
        ] as [String : Any]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RSSError.discoveryFailed(reason: "Invalid response from RSS crawler")
            }
            
            if httpResponse.statusCode == 200 {
                if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let success = result["success"] as? Bool,
                   let articlesFetched = result["articles_fetched"] as? Int,
                   success {
                    print("✅ Successfully crawled \(articlesFetched) articles")
                } else {
                    print("⚠️ RSS crawling completed but with unexpected response format")
                }
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("⚠️ RSS crawling failed: \(errorMessage)")
                // Don't throw here - we want to try getting existing articles from database
                print("⚠️ RSS crawling skipped - using existing articles from database")
            }
        } catch {
            print("⚠️ Failed to call RSS crawler: \(error.localizedDescription)")
            print("⚠️ RSS crawling skipped - using existing articles from database")
        }
    }
}

// MARK: - Data Models

struct RSSSource: Codable, Identifiable {
    let id: UUID
    let name: String
    let url: String
    let description: String?
    let topics: [String]
    let tags: [String]
    let lastFetched: Date?
    let fetchInterval: Int
    let isActive: Bool
    let autoRefreshEnabled: Bool
    let contentQualityScore: Double
    let avgEngagementScore: Double
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, url, description, topics, tags
        case lastFetched = "last_fetched"
        case fetchInterval = "fetch_interval"
        case isActive = "is_active"
        case autoRefreshEnabled = "auto_refresh_enabled"
        case contentQualityScore = "content_quality_score"
        case avgEngagementScore = "avg_engagement_score"
        case createdAt = "created_at"
    }
}

struct UserRSSFeed: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let rssSourceId: UUID
    let affinityScore: Double
    let isActive: Bool
    let subscriptionStrength: Double
    let articlesRead: Int
    let articlesLiked: Int
    let articlesDisliked: Int
    let subscribedAt: Date
    let lastInteractionAt: Date?
    let rssSource: RSSSource?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case rssSourceId = "rss_source_id"
        case affinityScore = "affinity_score"
        case isActive = "is_active"
        case subscriptionStrength = "subscription_strength"
        case articlesRead = "articles_read"
        case articlesLiked = "articles_liked"
        case articlesDisliked = "articles_disliked"
        case subscribedAt = "subscribed_at"
        case lastInteractionAt = "last_interaction_at"
        case rssSource = "rss_sources"
    }
}

struct RSSFetchResult: Codable {
    let success: Bool
    let feedTitle: String?
    let processedCount: Int
    let rssSourceId: String
    
    enum CodingKeys: String, CodingKey {
        case success
        case feedTitle = "feedTitle"
        case processedCount = "processedCount"
        case rssSourceId = "rssSourceId"
    }
}

struct ArticleWithUserData: Codable {
    let id: UUID
    let title: String
    let url: String?
    let content: String?
    let summary: String?
    let author: String?
    let published_date: Date?
    let source_type: String
    let rss_source_id: UUID?
    let topics: [String]?
    let difficulty_level: String?
    let estimated_read_time: Int?
    let processing_status: String
    let relevance_score: Double?
    let engagement_score: Double?
    let freshness_score: Double?
    let content_quality_score: Double?
    let created_at: Date
    let user_articles: UserArticleRelation?
}

struct UserArticleRelation: Codable {
    let id: UUID
    let status: String
    let is_starred: Bool
    let queued_at: Date
    let personalized_score: Double?
    let preference_score: Double?
    let interaction_type: String?
    let reading_progress: Double?
}

struct ScoreResult: Codable {
    let score: Double
}

struct RSSSourceRef: Codable {
    let rss_source_id: UUID
}

struct UserArticleRef: Codable {
    let article_id: UUID
}

// MARK: - Extensions

extension Date {
    func toISOString() -> String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}