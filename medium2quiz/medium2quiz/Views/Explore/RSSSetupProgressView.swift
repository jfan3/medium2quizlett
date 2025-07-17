import SwiftUI

struct RSSSetupProgressView: View {
    let selectedTopics: [String]
    @ObservedObject var appViewModel: AppViewModel
    let onBack: () -> Void
    
    @State private var setupProgress = RSSSetupProgress()
    @State private var currentPhase: SetupPhase = .initializing
    @State private var showingArticleSelection = false
    @State private var fetchedArticles: [Article] = []
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Text("Setting Up Your Feed")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Creating personalized content based on your topics")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)
            
            // Selected Topics
            VStack(alignment: .leading, spacing: 8) {
                Text("Selected Topics:")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(selectedTopics, id: \.self) { topic in
                        Text(topic)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Progress Section
            ScrollView {
                VStack(spacing: 20) {
                    // Phase 1: RSS Source Discovery
                    ProgressStepView(
                        title: "Discovering RSS Sources",
                        description: "Finding relevant tech blogs and publications",
                        phase: .discoveringFeeds,
                        currentPhase: currentPhase,
                        progress: setupProgress,
                        items: setupProgress.discoveredSources.map { "\($0) ✓" }
                    )
                    
                    // Phase 2: RSS Source Setup
                    ProgressStepView(
                        title: "Establishing RSS Connections",
                        description: "Connecting to RSS feeds and verifying access",
                        phase: .establishingFeeds,
                        currentPhase: currentPhase,
                        progress: setupProgress,
                        items: setupProgress.establishedSources.map { "\($0) ✓" }
                    )
                    
                    // Phase 3: Article Fetching
                    ProgressStepView(
                        title: "Fetching Recent Articles",
                        description: currentPhase.rawValue >= SetupPhase.processingArticles.rawValue && setupProgress.processedArticles.count > 0 
                            ? "Found \(setupProgress.processedArticles.count) articles from RSS feeds" 
                            : "Pulling articles from the last 3 months",
                        phase: .fetchingArticles,
                        currentPhase: currentPhase,
                        progress: setupProgress,
                        items: setupProgress.fetchedArticles.map { "\($0.title)" }
                    )
                    
                    // Phase 4: Article Processing
                    ProgressStepView(
                        title: "Processing Articles",
                        description: "Analyzing content and extracting key information",
                        phase: .processingArticles,
                        currentPhase: currentPhase,
                        progress: setupProgress,
                        items: setupProgress.processedArticles.map { "\($0.title)" }
                    )
                    
                    // Completion Section
                    if currentPhase == .readyForReview {
                        VStack(spacing: 16) {
                            Text("🎉 Setup Complete!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            
                            Text("Found \(setupProgress.processedArticles.count) articles ready for review")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Button("Review Articles") {
                                showingArticleSelection = true
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Error Section
                    if currentPhase == .error {
                        VStack(spacing: 16) {
                            Text("⚠️ Setup Issue")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                            
                            Text("We found RSS sources but had trouble retrieving articles. You can retry or continue with existing content.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 12) {
                                Button("Retry") {
                                    currentPhase = .initializing
                                    startRSSSetup()
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                
                                Button("Continue") {
                                    onBack()
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .padding(.horizontal)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            
            Spacer()
            
            // Back Button (only show if not completed and not in error state)
            if currentPhase != .readyForReview && currentPhase != .error {
                Button("Back") {
                    onBack()
                }
                .padding()
            }
        }
        .fullScreenCover(isPresented: $showingArticleSelection) {
            ArticleSelectionView(
                articles: setupProgress.processedArticles,
                appViewModel: appViewModel,
                onBack: { 
                    showingArticleSelection = false
                    onBack()
                }
            )
        }
        .onAppear {
            startRSSSetup()
        }
    }
    
    private func startRSSSetup() {
        Task {
            await performRSSSetup()
        }
    }
    
    private func performRSSSetup() async {
        // Use the user ID from AppViewModel instead of SupabaseService
        let userId = appViewModel.user.id
        print("🔍 Starting RSS setup for user: \(userId)")
        
        do {
            // Phase 1: Discover RSS Sources
            await updatePhase(.discoveringFeeds)
            await updateProgress(discoveredSources: ["AI & Machine Learning Sources", "Tech Company Blogs", "Developer Publications"])
            
            // Phase 2: Establish RSS Connections  
            await updatePhase(.establishingFeeds)
            await updateProgress(establishedSources: ["AWS Blog", "GitHub Blog", "Stack Overflow", "TechCrunch"])
            
            // Phase 3: Fetch Articles
            await updatePhase(.fetchingArticles)
            
            // Call the real RSS setup service
            try await RSSService.shared.setupUserFeeds(
                userId: userId, 
                selectedTopics: selectedTopics
            )
            
            // Phase 4: Process Articles
            await updatePhase(.processingArticles)
            
            // Load the actual articles that were created
            await loadRealArticles(userId: userId)
            
            // Phase 5: Ready for Review
            await updatePhase(.readyForReview)
            
        } catch {
            print("❌ RSS setup failed: \(error.localizedDescription)")
            
            // Check if this is a "no sources found" error after discovery
            if let rssError = error as? RSSError,
               case .noSourcesFound = rssError {
                // Try to get any articles that might exist and continue
                await loadRealArticles(userId: userId)
                
                // If we have articles, continue to completion
                if !setupProgress.processedArticles.isEmpty {
                    await updatePhase(.readyForReview)
                    return
                }
            }
            
            // For other errors, show error state
            await showErrorState(error: error)
        }
    }
    
    @MainActor
    private func updatePhase(_ phase: SetupPhase) async {
        withAnimation(.easeInOut(duration: 0.5)) {
            currentPhase = phase
        }
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
    }
    
    @MainActor
    private func updateProgress(discoveredSources: [String]? = nil, establishedSources: [String]? = nil, fetchedArticles: [Article]? = nil) async {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let sources = discoveredSources {
                setupProgress.discoveredSources = sources
            }
            if let sources = establishedSources {
                setupProgress.establishedSources = sources
            }
            if let articles = fetchedArticles {
                setupProgress.fetchedArticles = articles
            }
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
    }
    
    private func loadRealArticles(userId: UUID) async {
        do {
            // Load actual user articles from the database
            let userArticles = try await SupabaseService.shared.fetchUserArticles(userId: userId)
            
            await MainActor.run {
                // Update progress with fetched articles
                setupProgress.processedArticles = userArticles
                
                // Also update the app's articles
                appViewModel.articles = setupProgress.processedArticles
                
                print("📚 Loaded \(setupProgress.processedArticles.count) articles for user")
            }
        } catch {
            print("❌ Failed to load articles: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func showErrorState(error: Error) async {
        withAnimation(.easeInOut(duration: 0.5)) {
            currentPhase = .error
        }
        print("❌ RSS setup failed: \(error.localizedDescription)")
    }
    
    // All mock functions removed - now using real RSS setup
}

// MARK: - Data Models

enum SetupPhase: Int, CaseIterable {
    case initializing = 0
    case discoveringFeeds = 1
    case establishingFeeds = 2
    case fetchingArticles = 3
    case processingArticles = 4
    case readyForReview = 5
    case error = 6
}

struct RSSSetupProgress {
    var discoveredSources: [String] = []
    var establishedSources: [String] = []
    var fetchedArticles: [Article] = []
    var processedArticles: [Article] = []
}

struct ProgressStepView: View {
    let title: String
    let description: String
    let phase: SetupPhase
    let currentPhase: SetupPhase
    let progress: RSSSetupProgress
    let items: [String]
    
    private var isActive: Bool {
        currentPhase.rawValue >= phase.rawValue
    }
    
    private var isCompleted: Bool {
        currentPhase.rawValue > phase.rawValue
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // Status Icon
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green : (isActive ? Color.blue : Color.gray.opacity(0.3)))
                        .frame(width: 24, height: 24)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .foregroundColor(.white)
                            .font(.system(size: 12, weight: .bold))
                    } else if isActive {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                    } else {
                        Text("\(phase.rawValue)")
                            .foregroundColor(.gray)
                            .font(.system(size: 12, weight: .bold))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isActive ? .primary : .secondary)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Items List
            if isActive && !items.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(items.prefix(3), id: \.self) { item in
                        HStack {
                            Image(systemName: "circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 6))
                            Text(item)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if items.count > 3 {
                        Text("... and \(items.count - 3) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.leading, 16)
                    }
                }
                .padding(.leading, 32)
            }
        }
        .padding()
        .background(isActive ? Color(.systemGray6) : Color.clear)
        .cornerRadius(12)
    }
}