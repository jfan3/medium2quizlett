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
    
    // Gamification properties
    @Published var userProgress: UserProgress?
    @Published var userAchievements: [Achievement] = []
    @Published var currentSession: StudySession?
    
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
            // First try immediate user check
            var currentUser = supabaseService.getCurrentUser()
            
            // If no immediate user, try to restore session
            if currentUser == nil {
                print("🔄 No immediate user found, attempting session restoration...")
                // Session restore is handled automatically by Supabase client
                currentUser = supabaseService.getCurrentUser()
            }
            
            // If still no user and we're in development, try auto-login
            if currentUser == nil && EnvironmentConfig.isDevelopment {
                print("🔧 Development mode: attempting auto-login...")
                await attemptDevAutoLogin()
                currentUser = supabaseService.getCurrentUser()
            }
            
            // If still no authenticated user, create/use consistent dev user
            if currentUser == nil {
                print("🔧 No auth user found, using consistent dev user")
                await setupConsistentDevUser()
            } else {
                self.isAuthenticated = true
                print("✅ User authenticated: \(currentUser?.id.uuidString ?? "unknown")")
                
                // Update local user with auth ID
                if self.user.id != currentUser!.id {
                    self.user = User(
                        id: currentUser!.id,
                        occupation: self.user.occupation,
                        interests: self.user.interests,
                        isOnboardingComplete: self.user.isOnboardingComplete,
                        overallAccuracy: self.user.overallAccuracy,
                        streakDays: self.user.streakDays,
                        lastStudyDate: self.user.lastStudyDate,
                        skillLevel: self.user.skillLevel,
                        preferredDifficulty: self.user.preferredDifficulty,
                        dailyStudyGoal: self.user.dailyStudyGoal
                    )
                }
                
                await loadUserProfile()
                await loadUserArticles() // Load articles for authenticated user
                await initializeUserData() // Initialize all user data
                await loadUserFlashcards() // Preload flashcards for authenticated user
                await loadUserProgress() // Load gamification progress
                await loadUserAchievements() // Load achievements
                
                // Sync onboarding status with authenticated user
                if user.isOnboardingComplete {
                    print("✅ Authenticated user has completed onboarding")
                } else {
                    print("⚠️ Authenticated user needs to complete onboarding")
                }
            }
        }
    }
    
    private func attemptDevAutoLogin() async {
        do {
            print("🔐 Attempting dev auto-login with: \(EnvironmentConfig.devUserEmail)")
            _ = try await supabaseService.signIn(
                email: EnvironmentConfig.devUserEmail,
                password: EnvironmentConfig.devUserPassword
            )
            self.isAuthenticated = true
            print("✅ Dev auto-login successful")
        } catch {
            print("⚠️ Dev auto-login failed: \(error.localizedDescription)")
            // Try to create the dev user if it doesn't exist
            await createDevUserIfNeeded()
        }
    }
    
    private func createDevUserIfNeeded() async {
        do {
            print("🔨 Creating dev user...")
            let authUser = try await supabaseService.signUp(
                email: EnvironmentConfig.devUserEmail,
                password: EnvironmentConfig.devUserPassword
            )
            
            // Create user profile
            let _ = UserProfile(
                id: authUser.id,
                email: EnvironmentConfig.devUserEmail,
                occupation: "Developer",
                companyInterests: ["Technology", "AI", "Swift"],
                overallAccuracy: 0,
                streakDays: 0,
                lastStudyDate: nil,
                onboardingComplete: true,
                skillLevel: "intermediate",
                preferredDifficulty: "medium",
                dailyStudyGoal: 20,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            try await supabaseService.createUserProfile(
                userId: authUser.id,
                email: EnvironmentConfig.devUserEmail,
                occupation: "Developer",
                interests: ["Technology", "AI", "Swift"]
            )
            
            // Update local state
            self.user = User(
                id: authUser.id,
                occupation: .softwareEngineer,
                interests: ["Technology", "AI", "Swift"],
                isOnboardingComplete: true,
                overallAccuracy: 0,
                streakDays: 0,
                lastStudyDate: nil,
                skillLevel: "intermediate",
                preferredDifficulty: "medium",
                dailyStudyGoal: 20
            )
            self.isAuthenticated = true
            
            print("✅ Dev user created and authenticated")
        } catch {
            print("❌ Failed to create dev user: \(error.localizedDescription)")
        }
    }
    
    /// Sets up a consistent dev user when no authentication is available
    private func setupConsistentDevUser() async {
        // Use a fixed UUID for consistent dev user across app sessions
        let devUserId = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
        
        await MainActor.run {
            // Load existing user data or create new
            loadUserData()
            
            // Update user with consistent ID
            self.user = User(
                id: devUserId,
                occupation: self.user.occupation ?? .softwareEngineer,
                interests: self.user.interests.isEmpty ? ["Technology", "AI", "Swift"] : self.user.interests,
                isOnboardingComplete: self.user.isOnboardingComplete,
                overallAccuracy: self.user.overallAccuracy,
                streakDays: self.user.streakDays,
                lastStudyDate: self.user.lastStudyDate,
                skillLevel: self.user.skillLevel,
                preferredDifficulty: self.user.preferredDifficulty,
                dailyStudyGoal: self.user.dailyStudyGoal
            )
            
            // Ensure user has completed onboarding for dev mode
            if !self.user.isOnboardingComplete {
                self.user.isOnboardingComplete = true
            }
            
            self.isAuthenticated = false // Mark as not auth but with consistent user
            saveUserData()
            loadArticles()
        }
        
        // Preload flashcards for the consistent user
        Task {
            await loadUserFlashcards()
            
            // Don't automatically generate flashcards or crawl at startup
            if userFlashcards.isEmpty {
                print("📝 No flashcards found. Use the Explore tab to discover content.")
            }
        }
        
        print("🔧 Setup consistent dev user with ID: \(devUserId)")
    }
    
    /// Creates sample content for testing when no articles exist
    private func createSampleContent() async {
        let sampleArticles = [
            Article(
                id: UUID(),
                title: "Introduction to Machine Learning",
                url: "https://example.com/ml-intro",
                content: """
                Machine learning is a subset of artificial intelligence that enables computers to learn and make decisions from data without being explicitly programmed. It works by identifying patterns in data and using these patterns to make predictions or decisions about new, unseen data.
                
                There are three main types of machine learning: supervised learning, unsupervised learning, and reinforcement learning. Supervised learning uses labeled data to train models, unsupervised learning finds patterns in unlabeled data, and reinforcement learning learns through trial and error with rewards and penalties.
                
                Common applications include recommendation systems, image recognition, natural language processing, and autonomous vehicles. Popular algorithms include linear regression, decision trees, neural networks, and support vector machines.
                """,
                source: .rss,
                topic: "Machine Learning",
                imageURL: nil,
                publishedDate: Date(),
                status: .queued,
                quizCards: [],
                isStarred: false
            ),
            Article(
                id: UUID(),
                title: "Understanding Cloud Computing",
                url: "https://example.com/cloud-computing",
                content: """
                Cloud computing is the delivery of computing services including servers, storage, databases, networking, software, analytics, and intelligence over the Internet. This allows for faster innovation, flexible resources, and economies of scale.
                
                The main service models are Infrastructure as a Service (IaaS), Platform as a Service (PaaS), and Software as a Service (SaaS). Deployment models include public, private, hybrid, and multi-cloud.
                
                Benefits include cost reduction, scalability, reliability, and security. Major providers include Amazon Web Services (AWS), Microsoft Azure, and Google Cloud Platform. Common use cases include data backup, disaster recovery, data analytics, and software development and testing.
                """,
                source: .rss,
                topic: "Cloud Computing",
                imageURL: nil,
                publishedDate: Date(),
                status: .queued,
                quizCards: [],
                isStarred: false
            )
        ]
        
        await MainActor.run {
            self.articles = sampleArticles
            self.saveArticles()
            print("✅ Created \(sampleArticles.count) sample articles")
        }
        
        // Generate flashcards for the sample articles
        await generateFlashcardsForQueuedArticles()
    }
    
    // MARK: - Authentication
    
    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let authUser = try await supabaseService.signUp(email: email, password: password)
            
            // Create user profile
            let _ = UserProfile(
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
            
            try await supabaseService.createUserProfile(
                userId: authUser.id,
                email: EnvironmentConfig.devUserEmail,
                occupation: "Developer",
                interests: ["Technology", "AI", "Swift"]
            )
            
            // Update local user with auth ID
            await MainActor.run {
                self.user = User(
                    id: authUser.id,
                    occupation: nil,
                    interests: [],
                    isOnboardingComplete: false,
                    overallAccuracy: 0,
                    streakDays: 0,
                    lastStudyDate: nil,
                    skillLevel: "beginner",
                    preferredDifficulty: "medium",
                    dailyStudyGoal: 10
                )
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
        guard let currentUser = supabaseService.getCurrentUser() else { return }
        
        do {
            if let existingUser = try await supabaseService.getUser(id: currentUser.id) {
                await MainActor.run {
                    self.user = existingUser
                    print("✅ Loaded user profile - onboarding complete: \(self.user.isOnboardingComplete)")
                }
            }
        } catch {
            print("⚠️ Failed to load user profile: \(error.localizedDescription)")
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
        if isAuthenticated && supabaseService.getCurrentUser() != nil {
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
        
        if isAuthenticated && supabaseService.getCurrentUser() != nil {
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
        
        if isAuthenticated && supabaseService.getCurrentUser() != nil {
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
        guard let currentUser = supabaseService.getCurrentUser() else { return }
        
        let _ = UserProfile(
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
            try await supabaseService.updateUserProfile(
                userId: user.id,
                updates: [
                    "occupation": .string(user.occupation?.rawValue ?? ""),
                    "company_interests": .array(user.interests.map { .string($0) })
                ]
            )
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // MARK: - Articles
    
    func loadUserArticles() async {
        let currentUser = supabaseService.getCurrentUser()
        
        if currentUser == nil {
            // Load from UserDefaults if not authenticated
            await MainActor.run {
                loadArticles()
            }
            return 
        }
        
        do {
            let userArticles = try await supabaseService.fetchUserArticles(userId: currentUser!.id)
            
            // Load articles with quiz cards
            var articlesWithCards: [Article] = []
            
            for userArticle in userArticles {
                
                // Fetch quiz cards for this article
                let quizCards = try await supabaseService.getQuizCards(articleId: userArticle.id)
                
                let article = Article(
                    id: userArticle.id,
                    title: userArticle.title,
                    url: userArticle.url,
                    content: userArticle.content,
                    source: ContentSource(rawValue: userArticle.source.rawValue) ?? .rss,
                    topic: userArticle.topic,
                    imageURL: userArticle.imageURL,
                    publishedDate: userArticle.publishedDate,
                    status: ArticleStatus(rawValue: userArticle.status.rawValue) ?? .queued,
                    quizCards: quizCards,
                    isStarred: userArticle.isStarred
                )
                articlesWithCards.append(article)
            }
            
            // Capture the array to avoid concurrency issues
            let finalArticles = articlesWithCards
            await MainActor.run {
                self.articles = finalArticles
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    func updateArticleStatus(_ articleId: UUID, status: ArticleStatus) async {
        let currentUser = supabaseService.getCurrentUser()
        
        if currentUser == nil {
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
            let userArticles = try await supabaseService.fetchUserArticles(userId: currentUser!.id)
            if let userArticle = userArticles.first(where: { $0.id == articleId }) {
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
        // Return starred cards that have been answered incorrectly (low mastery level)
        return userFlashcards
            .filter { flashcard in
                // Card must be starred and have poor performance (tested and incorrect)
                flashcard.isStarred && flashcard.masteryLevel < 0.5 && flashcard.totalAttempts > 0
            }
            .compactMap { flashcard -> QuizCard? in
                // Create a QuizCard from the database data
                let decoder = JSONDecoder()
                
                // Create a dictionary with the quiz card data
                var cardData: [String: Any] = [
                    "id": flashcard.quizCard.id.uuidString,
                    "article_id": flashcard.quizCard.articleId.uuidString,
                    "question": flashcard.quizCard.question,
                    "answer": flashcard.quizCard.answer,
                    "card_type": flashcard.quizCard.type,
                    "difficulty": flashcard.quizCard.difficulty,
                    "is_active": true,
                    "created_at": Date().timeIntervalSince1970
                ]
                
                if let choices = flashcard.quizCard.choices {
                    cardData["choices"] = choices
                }
                
                // Convert to QuizCard
                guard let jsonData = try? JSONSerialization.data(withJSONObject: cardData),
                      var card = try? decoder.decode(QuizCard.self, from: jsonData) else {
                    return nil
                }
                
                // Update the local properties
                card.attempts = flashcard.totalAttempts
                card.correctAttempts = flashcard.correctAttempts
                card.isStarred = flashcard.isStarred
                card.lastStudied = flashcard.lastStudied
                card.masteryLevel = flashcard.masteryLevel
                
                return card
            }
    }
    
    func getAcedCards() -> [QuizCard] {
        // Return starred cards that have been answered correctly (high mastery level)
        return userFlashcards
            .filter { flashcard in
                // Card must be starred and have high performance (tested and correct)
                flashcard.isStarred && flashcard.masteryLevel >= 0.8 && flashcard.totalAttempts > 0
            }
            .compactMap { flashcard -> QuizCard? in
                // Create a QuizCard from the database data
                let decoder = JSONDecoder()
                
                // Create a dictionary with the quiz card data
                var cardData: [String: Any] = [
                    "id": flashcard.quizCard.id.uuidString,
                    "article_id": flashcard.quizCard.articleId.uuidString,
                    "question": flashcard.quizCard.question,
                    "answer": flashcard.quizCard.answer,
                    "card_type": flashcard.quizCard.type,
                    "difficulty": flashcard.quizCard.difficulty,
                    "is_active": true,
                    "created_at": Date().timeIntervalSince1970
                ]
                
                if let choices = flashcard.quizCard.choices {
                    cardData["choices"] = choices
                }
                
                // Convert to QuizCard
                guard let jsonData = try? JSONSerialization.data(withJSONObject: cardData),
                      var card = try? decoder.decode(QuizCard.self, from: jsonData) else {
                    return nil
                }
                
                // Update the local properties
                card.attempts = flashcard.totalAttempts
                card.correctAttempts = flashcard.correctAttempts
                card.isStarred = flashcard.isStarred
                card.lastStudied = flashcard.lastStudied
                card.masteryLevel = flashcard.masteryLevel
                
                return card
            }
    }
    
    // MARK: - Flashcard Management
    
    @Published var userFlashcards: [DueFlashcard] = []
    
    func loadUserFlashcards() async {
        // Use the current app user's ID (which is now consistent)
        let userId = self.user.id
        print("🔍 Loading flashcards for user: \(userId)")
        
        do {
            let flashcards = try await supabaseService.fetchUserFlashcards(userId: userId)
            print("✅ Loaded \(flashcards.count) flashcards from database")
            
            // Show starred count summary
            let starredCount = flashcards.filter { $0.isStarred }.count
            if starredCount > 0 {
                print("⭐ Found \(starredCount) starred cards")
            }
            
            await MainActor.run {
                self.userFlashcards = flashcards
            }
        } catch {
            print("❌ Failed to load flashcards: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                // Set empty array as fallback so UI doesn't break
                self.userFlashcards = []
            }
        }
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
        // Use consistent user ID approach
        let userId = self.user.id
        
        do {
            let _ = UUID()
            // Convert topicIds to empty Topic objects for now
            let topics: [Topic] = topicIds.map { topicId in
                Topic(id: topicId, name: "Unknown", isSelected: true)
            }
            try await supabaseService.saveTopicSelections(
                userId: userId,
                topics: topics
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
        // Use consistent user ID approach
        let _ = self.user.id
        
        let source = UserSource(
            id: UUID(),
            name: "Custom \(sourceType)",
            url: "custom://\(sourceType)",
            description: "User provided \(sourceType) content",
            category: sourceType,
            isActive: true,
            userAdded: true,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        do {
            try await supabaseService.addCustomSource(
                userId: user.id,
                name: source.name,
                url: source.url,
                description: source.description,
                category: source.category
            )
            
            // Trigger content processing via Edge Function
            await processCustomSource(sourceId: UUID(), sourceType: sourceType, content: content)
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
            "content": content,
            "userId": currentUser?.id.uuidString ?? "00000000-0000-0000-0000-000000000001"
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
            print("✅ Loaded user from UserDefaults: onboarding complete = \(user.isOnboardingComplete)")
        } else {
            print("📝 No user data in UserDefaults, using default user")
            // User already initialized with default values
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
        // Use consistent user ID approach
        let userId = self.user.id
        
        do {
            try await rssService.setupUserFeeds(userId: userId, selectedTopics: topics)
            
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
        // Use consistent user ID approach
        let userId = self.user.id
        
        do {
            let rssArticles = try await rssService.getUserArticles(userId: userId, status: "queued")
            
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
        // Use consistent user ID approach
        let userId = self.user.id
        
        do {
            try await rssService.queueArticle(userId: userId, articleId: article.id)
            
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
        // Use consistent user ID approach
        let userId = self.user.id
        
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // Get all queued articles for the user
            let queuedArticles = try await rssService.getPersonalizedRecommendations(userId: userId, limit: 50)
            
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
    
    /// Processes queued articles to generate flashcards using Claude
    private func processQueuedArticles(_ articles: [Article]) async {
        print("🤖 Processing \(articles.count) articles for Claude flashcard generation")
        
        for article in articles {
            await processArticleForFlashcards(article)
        }
    }
    
    /// Processes a single article to generate flashcards using Claude
    private func processArticleForFlashcards(_ article: Article) async {
        do {
            print("🤖 Using Claude to generate flashcards for: \(article.title)")
            
            // Generate flashcards using Claude
            try await supabaseService.generateFlashcards(articleIds: [article.id])
            
            // Create user performance records to associate flashcards with current user
            let userId = self.user.id
            try await supabaseService.initializeAllUserPerformanceRecords(userId: userId)
            print("✅ Created user performance records for article: \(article.title)")
            
            await MainActor.run {
                // Update the article status
                if let index = self.articles.firstIndex(where: { $0.id == article.id }) {
                    self.articles[index].status = .completed
                }
                
                // Save updated articles
                saveArticleData()
                
                print("✅ Successfully generated flashcards for article: \(article.title)")
            }
            
        } catch {
            print("❌ Failed to generate flashcards with Claude: \(error.localizedDescription)")
            await MainActor.run {
                self.errorMessage = "Failed to generate flashcards: \(error.localizedDescription)"
            }
        }
    }
    
    /// Gets user's RSS feed subscriptions
    func getUserRSSFeeds() async -> [UserRSSFeed] {
        // Use consistent user ID approach
        let userId = self.user.id
        
        do {
            return try await rssService.getUserRSSFeeds(userId: userId)
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
    
    // MARK: - Helper Methods
    
    private func userFromProfile(_ profile: UserProfile) -> User {
        return User(
            id: profile.id, // Use auth ID from profile
            occupation: Occupation(rawValue: profile.occupation ?? ""),
            interests: profile.companyInterests,
            isOnboardingComplete: profile.onboardingComplete,
            overallAccuracy: profile.overallAccuracy,
            streakDays: profile.streakDays,
            lastStudyDate: profile.lastStudyDate,
            skillLevel: profile.skillLevel,
            preferredDifficulty: profile.preferredDifficulty,
            dailyStudyGoal: profile.dailyStudyGoal
        )
    }
    
    // MARK: - Gamification Methods
    
    var currentUser: User? {
        return user
    }
    
    private func initializeUserData() async {
        let userId = user.id
        
        do {
            // Initialize performance records for all quiz cards
            try await supabaseService.initializeAllUserPerformanceRecords(userId: userId)
            print("✅ Initialized user performance records")
        } catch {
            print("❌ Failed to initialize user data: \(error)")
        }
    }
    
    func loadUserProgress() async {
        let userId = user.id
        
        do {
            let progress = try await supabaseService.fetchUserProgress(userId: userId)
            await MainActor.run {
                self.userProgress = progress
            }
        } catch {
            print("❌ Failed to load user progress: \(error)")
        }
    }
    
    func updateUserProgress(xp: Int? = nil, coins: Int? = nil, gems: Int? = nil, studyMinutes: Int? = nil) async {
        let userId = user.id
        
        do {
            // Create updated progress object
            if var currentProgress = userProgress {
                if let xp = xp { currentProgress.xp += xp }
                if let coins = coins { currentProgress.coins += coins }
                if let gems = gems { currentProgress.gems += gems }
                if let studyMinutes = studyMinutes { currentProgress.dailyMinutesStudied += studyMinutes }
                
                try await supabaseService.updateUserProgress(
                    userId: userId,
                    progress: currentProgress
                )
                
                // Reload progress to get updated values
                await loadUserProgress()
            }
        } catch {
            print("❌ Failed to update user progress: \(error)")
        }
    }
    
    func saveStudySession(_ session: StudySession) async {
        do {
            try await supabaseService.saveStudySession(session)
            
            // Update progress with session results
            await updateUserProgress(
                xp: session.sessionXP,
                coins: session.sessionCoins,
                studyMinutes: session.sessionDuration / 60
            )
        } catch {
            print("❌ Failed to save study session: \(error)")
        }
    }
    
    func updateFlashcardMastery(flashcardId: UUID, correct: Bool) async {
        let userId = user.id
        
        do {
            let masteryLevel = correct ? 1.0 : 0.0
            try await supabaseService.updateFlashcardMastery(
                userId: userId,
                cardId: flashcardId,
                masteryLevel: masteryLevel
            )
        } catch {
            print("❌ Failed to update flashcard mastery: \(error)")
        }
    }
    
    func generateTestQuestions(articleId: UUID) async -> [TestQuestion] {
        let userId = user.id
        
        do {
            return try await supabaseService.generateTestQuestions(
                userId: userId,
                articleId: articleId
            )
        } catch {
            print("❌ Failed to generate test questions: \(error)")
            return []
        }
    }
    
    func loadUserAchievements() async {
        let userId = user.id
        
        do {
            let achievements = try await supabaseService.fetchUserAchievements(userId: userId)
            await MainActor.run {
                self.userAchievements = achievements
            }
        } catch {
            print("❌ Failed to load achievements: \(error)")
        }
    }
    
    func purchasePowerUp(powerUpId: UUID, useCurrency: String) async -> Bool {
        let userId = user.id
        
        do {
            let cost = useCurrency == "coins" ? 100 : 10 // Default costs
            try await supabaseService.purchasePowerUp(
                userId: userId,
                powerUpId: powerUpId,
                cost: cost
            )
            
            // Reload progress to reflect updated currency
            await loadUserProgress()
            return true
        } catch {
            print("❌ Failed to purchase power-up: \(error)")
            return false
        }
    }
}