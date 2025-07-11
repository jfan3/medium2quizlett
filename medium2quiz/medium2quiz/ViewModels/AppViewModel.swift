import Foundation
import Combine
import Supabase

class AppViewModel: ObservableObject {
    @Published var user = User()
    @Published var articles: [Article] = []
    @Published var selectedTopics: [Topic] = []
    @Published var isOnboardingComplete = false
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let supabaseService = SupabaseService.shared
    private let rssService = RSSService.shared
    
    init() {
        checkAuthenticationStatus()
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        $user
            .map { $0.isOnboardingComplete }
            .assign(to: \.isOnboardingComplete, on: self)
            .store(in: &cancellables)
    }
    
    private func checkAuthenticationStatus() {
        Task { @MainActor in
            self.isAuthenticated = supabaseService.currentUser != nil
            if isAuthenticated {
                await loadUserProfile()
            } else {
                loadUserData() // Fallback to UserDefaults - already @MainActor
            }
        }
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let authUser = try await supabaseService.signUp(email: email, password: password)
            
            // Create user profile
            let profile = UserProfile(
                id: authUser.id,
                email: email,
                occupation: nil,
                companyInterests: [],
                overallAccuracy: 0,
                streakDays: 0,
                lastStudyDate: nil,
                onboardingComplete: false,
                skillLevel: "beginner",
                preferredDifficulty: "medium",
                dailyStudyGoal: 10,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            try await supabaseService.createUserProfile(profile)
            
            await MainActor.run {
                self.isAuthenticated = true
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try await supabaseService.signIn(email: email, password: password)
            await MainActor.run {
                self.isAuthenticated = true
                self.isLoading = false
            }
            await loadUserProfile()
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    func signOut() async {
        do {
            try await supabaseService.signOut()
            await MainActor.run {
                self.isAuthenticated = false
                self.user = User()
                self.articles = []
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func loadUserProfile() async {
        guard let currentUser = supabaseService.currentUser else { return }
        
        do {
            let profile = try await supabaseService.getUserProfile(userId: currentUser.id)
            await MainActor.run {
                self.user = User(
                    id: profile.id,
                    occupation: Occupation(rawValue: profile.occupation ?? ""),
                    interests: profile.companyInterests,
                    isOnboardingComplete: profile.onboardingComplete,
                    overallAccuracy: profile.overallAccuracy,
                    streakDays: profile.streakDays,
                    lastStudyDate: profile.lastStudyDate
                )
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - User Profile
    
    func completeOnboarding() async {
        await MainActor.run {
            user.isOnboardingComplete = true
        }
        
        // Only save to Supabase if user is authenticated with real account
        if isAuthenticated && supabaseService.currentUser != nil {
            await saveUserProfile()
        } else {
            // For dev login, just save locally
            await MainActor.run {
                saveUserData()
            }
        }
    }
    
    // For dev login - complete onboarding without backend calls (synchronous)
    @MainActor
    func completeOnboardingSync() {
        user.isOnboardingComplete = true
        saveUserData()
    }
    
    func updateOccupation(_ occupation: Occupation) async {
        await MainActor.run {
            user.occupation = occupation
        }
        
        if isAuthenticated && supabaseService.currentUser != nil {
            await saveUserProfile()
        } else {
            await MainActor.run {
                saveUserData()
            }
        }
    }
    
    func updateInterests(_ interests: [String]) async {
        await MainActor.run {
            user.interests = interests
        }
        
        if isAuthenticated && supabaseService.currentUser != nil {
            await saveUserProfile()
            // Set up RSS feeds for selected topics
            await setupRSSFeeds(for: interests)
        } else {
            await MainActor.run {
                saveUserData()
            }
        }
    }
    
    private func saveUserProfile() async {
        guard let currentUser = supabaseService.currentUser else { return }
        
        let profile = UserProfile(
            id: currentUser.id,
            email: currentUser.email ?? "",
            occupation: user.occupation?.rawValue,
            companyInterests: user.interests,
            overallAccuracy: user.overallAccuracy,
            streakDays: user.streakDays,
            lastStudyDate: user.lastStudyDate,
            onboardingComplete: user.isOnboardingComplete,
            skillLevel: "beginner",
            preferredDifficulty: "medium",
            dailyStudyGoal: 10,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        do {
            try await supabaseService.updateUserProfile(profile)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Articles
    
    func loadUserArticles() async {
        guard let currentUser = supabaseService.currentUser else { 
            // Load from UserDefaults if not authenticated
            await MainActor.run {
                loadArticles()
            }
            return 
        }
        
        do {
            let userArticles = try await supabaseService.fetchUserArticles(userId: currentUser.id)
            await MainActor.run {
                self.articles = userArticles.compactMap { userArticle -> Article? in
                    guard let articleDetail = userArticle.article else { return nil }
                    return Article(
                        id: articleDetail.id,
                        title: articleDetail.title,
                        url: articleDetail.url,
                        content: articleDetail.content ?? "",
                        source: ContentSource(rawValue: articleDetail.sourceType) ?? .rss,
                        topic: articleDetail.topics.first,
                        imageURL: nil,
                        publishedDate: articleDetail.publishedDate ?? Date(),
                        status: ArticleStatus(rawValue: userArticle.status) ?? .queued,
                        quizCards: [],
                        isStarred: userArticle.isStarred
                    )
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func updateArticleStatus(_ articleId: UUID, status: ArticleStatus) async {
        guard let currentUser = supabaseService.currentUser else { 
            // Update locally if not authenticated
            await MainActor.run {
                if let index = articles.firstIndex(where: { $0.id == articleId }) {
                    articles[index].status = status
                    saveArticles()
                }
            }
            return 
        }
        
        do {
            let userArticles = try await supabaseService.fetchUserArticles(userId: currentUser.id)
            if let userArticle = userArticles.first(where: { $0.articleId == articleId }) {
                try await supabaseService.updateArticleStatus(userArticleId: userArticle.id, status: status.rawValue)
                await loadUserArticles()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    @MainActor
    func addArticle(_ article: Article) {
        articles.append(article)
        saveArticles()
    }
    
    func getArticles(by status: ArticleStatus) -> [Article] {
        articles.filter { $0.status == status }
    }
    
    func getStarredCards() -> [QuizCard] {
        articles.flatMap { $0.quizCards }.filter { $0.isStarred }
    }
    
    func getWeakCards() -> [QuizCard] {
        articles.flatMap { $0.quizCards }.filter { $0.isWeak }
    }
    
    func getAcedCards() -> [QuizCard] {
        articles.flatMap { $0.quizCards }.filter { $0.isAced }
    }
    
    // MARK: - Topics
    
    func loadTopics() async {
        do {
            let topics = try await supabaseService.fetchTopics()
            await MainActor.run {
                self.selectedTopics = topics.map { topic in
                    Topic(id: topic.id, name: topic.name, isSelected: false)
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func saveTopicSelections(_ topicIds: [UUID]) async {
        guard let currentUser = supabaseService.currentUser else { return }
        
        do {
            let sessionId = UUID()
            try await supabaseService.saveTopicSelections(
                userId: currentUser.id,
                topicIds: topicIds,
                sessionId: sessionId
            )
            
            // Get topic names and set up RSS feeds
            let topicNames = selectedTopics.filter { topic in
                topicIds.contains(topic.id)
            }.map { $0.name }
            
            await setupRSSFeeds(for: topicNames)
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Custom Sources
    
    func addCustomSource(sourceType: String, content: String) async {
        guard let currentUser = supabaseService.currentUser else { return }
        
        let source = UserSource(
            id: UUID(),
            userId: currentUser.id,
            sourceType: sourceType,
            sourceContent: content,
            processingStatus: "pending",
            processingAttempts: 0,
            lastProcessingAttempt: nil,
            createdAt: Date()
        )
        
        do {
            let sourceId = try await supabaseService.addCustomSource(source)
            
            // Trigger content processing via Edge Function
            await processCustomSource(sourceId: sourceId, sourceType: sourceType, content: content)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    private func processCustomSource(sourceId: UUID, sourceType: String, content: String) async {
        // Call Supabase Edge Function for content processing
        guard let url = URL(string: "\(EnvironmentConfig.supabaseURL)/functions/v1/process-content") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(EnvironmentConfig.supabaseAnonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "sourceId": sourceId.uuidString,
            "sourceType": sourceType,
            "content": content
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (_, _) = try await URLSession.shared.data(for: request)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to process content: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - UserDefaults fallback methods
    
    @MainActor
    private func loadUserData() {
        if let data = UserDefaults.standard.data(forKey: "user"),
           let user = try? JSONDecoder().decode(User.self, from: data) {
            self.user = user
        }
    }
    
    @MainActor
    private func saveUserData() {
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "user")
        }
    }
    
    @MainActor
    private func saveArticleData() {
        if let data = try? JSONEncoder().encode(articles) {
            UserDefaults.standard.set(data, forKey: "articles")
        }
    }
    
    @MainActor
    private func loadArticles() {
        if let data = UserDefaults.standard.data(forKey: "articles"),
           let articles = try? JSONDecoder().decode([Article].self, from: data) {
            self.articles = articles
        }
    }
    
    @MainActor
    private func saveArticles() {
        if let data = try? JSONEncoder().encode(articles) {
            UserDefaults.standard.set(data, forKey: "articles")
        }
    }
    
    // MARK: - RSS Feed Management
    
    /// Sets up RSS feeds based on user's selected topics
    private func setupRSSFeeds(for topics: [String]) async {
        guard let currentUser = supabaseService.currentUser else { return }
        
        do {
            try await rssService.setupUserFeeds(userId: currentUser.id, selectedTopics: topics)
            
            // Fetch initial articles from the newly set up feeds
            await fetchRSSArticles()
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Fetches articles from user's RSS feeds
    func fetchRSSArticles() async {
        guard let currentUser = supabaseService.currentUser else { return }
        
        do {
            let rssArticles = try await rssService.getUserArticles(userId: currentUser.id, status: "queued")
            
            await MainActor.run {
                // Add RSS articles to existing articles
                let newArticles = rssArticles.filter { rssArticle in
                    !self.articles.contains { existingArticle in
                        existingArticle.id == rssArticle.id
                    }
                }
                self.articles.append(contentsOf: newArticles)
            }
            
            // Process articles for flashcard generation
            await processQueuedArticles(rssArticles)
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    /// Queues an RSS article for a user
    func queueRSSArticle(_ article: Article) async {
        guard let currentUser = supabaseService.currentUser else { return }
        
        do {
            try await rssService.queueArticle(userId: currentUser.id, articleId: article.id)
            
            await MainActor.run {
                // Update local article status
                if let index = self.articles.firstIndex(where: { $0.id == article.id }) {
                    self.articles[index].status = .queued
                }
            }
            
            // Process the article for flashcard generation
            await processQueuedArticles([article])
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to queue article: \(error.localizedDescription)"
            }
        }
    }
    
    /// Generates flashcards for all queued articles
    func generateFlashcardsForQueuedArticles() async {
        guard let currentUser = supabaseService.currentUser else { return }
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // Get all queued articles for the user
            let queuedArticles = try await rssService.getPersonalizedRecommendations(userId: currentUser.id, limit: 50)
            
            // Process each article for flashcard generation
            await processQueuedArticles(queuedArticles)
            
            await MainActor.run {
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to generate flashcards: \(error.localizedDescription)"
            }
        }
    }
    
    /// Processes queued articles to generate flashcards using OpenAI
    private func processQueuedArticles(_ articles: [Article]) async {
        print("🤖 Processing \(articles.count) articles for OpenAI flashcard generation")
        
        for article in articles {
            await processArticleForFlashcards(article)
        }
    }
    
    /// Processes a single article to generate flashcards using OpenAI
    private func processArticleForFlashcards(_ article: Article) async {
        do {
            print("🤖 Using AI to generate flashcards for: \(article.title)")
            
            // Generate flashcards using OpenAI
            let flashcards = try await supabaseService.generateFlashcardsWithOpenAI(for: article)
            
            // Store flashcards in database
            for flashcard in flashcards {
                try await supabaseService.createQuizCard(flashcard)
            }
            
            await MainActor.run {
                // Update the article with generated flashcards
                if let index = self.articles.firstIndex(where: { $0.id == article.id }) {
                    self.articles[index].quizCards = flashcards
                    self.articles[index].status = .completed
                }
                
                // Save updated articles
                saveArticleData()
                
                print("✅ Successfully generated and saved \(flashcards.count) flashcards for article")
            }
            
        } catch {
            print("❌ Failed to generate flashcards with OpenAI: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to generate flashcards: \(error.localizedDescription)"
            }
        }
    }
    
    /// Gets user's RSS feed subscriptions
    func getUserRSSFeeds() async -> [UserRSSFeed] {
        guard let currentUser = supabaseService.currentUser else { return [] }
        
        do {
            return try await rssService.getUserRSSFeeds(userId: currentUser.id)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch RSS feeds: \(error.localizedDescription)"
            }
            return []
        }
    }
    
    /// Updates RSS feed affinity based on user interactions
    func updateRSSFeedAffinity(userRSSFeedId: UUID, score: Double) async {
        do {
            try await rssService.updateFeedAffinity(userRSSFeedId: userRSSFeedId, score: score)
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update feed affinity: \(error.localizedDescription)"
            }
        }
    }
}