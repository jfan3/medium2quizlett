import SwiftUI
import Supabase

// MARK: - Study Session Types
enum StudySessionType: String, CaseIterable {
    case smartStudy = "Smart Study"
    case starredReview = "Review Starred"
    case quickTest = "Quick Test"
    case newCardsOnly = "New Cards"
    
    var icon: String {
        switch self {
        case .smartStudy: return "brain.head.profile"
        case .starredReview: return "star.fill"
        case .quickTest: return "timer"
        case .newCardsOnly: return "sparkles"
        }
    }
    
    var description: String {
        switch self {
        case .smartStudy: return "AI-curated mix of cards"
        case .starredReview: return "Focus on your starred cards"
        case .quickTest: return "10-minute rapid review"
        case .newCardsOnly: return "Learn new content"
        }
    }
}

// MARK: - Study Session Configuration
struct StudySessionConfig {
    let type: StudySessionType
    let cardLimit: Int
    let timeLimit: Int? // in minutes
    let focusTopics: [String]
    
    static let quickStudy = StudySessionConfig(
        type: .quickTest,
        cardLimit: 15,
        timeLimit: 10,
        focusTopics: []
    )
    
    static let deepDive = StudySessionConfig(
        type: .smartStudy,
        cardLimit: 40,
        timeLimit: 30,
        focusTopics: []
    )
}

// MARK: - Improved Study View
struct StudyViewImproved: View {
    @ObservedObject var appViewModel: AppViewModel
    @State private var sessionConfig: StudySessionConfig?
    @State private var showingSessionSetup = true
    @State private var currentFlashcards: [FlashcardWithContext] = []
    @State private var currentCardIndex = 0
    @State private var showingBack = false
    @State private var sessionStartTime = Date()
    @State private var correctCount = 0
    @State private var studiedCount = 0
    
    // Card states
    @State private var dragOffset = CGSize.zero
    @State private var cardRotation: Double = 0
    @State private var cardOpacity: Double = 1
    
    var body: some View {
        NavigationView {
            ZStack {
                if showingSessionSetup {
                    StudySessionSetupView(
                        appViewModel: appViewModel,
                        onStartSession: { config in
                            startSession(with: config)
                        }
                    )
                    .transition(.move(edge: .leading))
                } else if let config = sessionConfig {
                    activeStudyView(config: config)
                        .transition(.move(edge: .trailing))
                } else {
                    LoadingView()
                }
            }
            .navigationTitle("Study")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !showingSessionSetup {
                        Button("End Session") {
                            endSession()
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func activeStudyView(config: StudySessionConfig) -> some View {
        VStack(spacing: 0) {
            // Progress Header
            StudyProgressHeader(
                currentCard: min(currentCardIndex + 1, currentFlashcards.count),
                totalCards: currentFlashcards.count,
                sessionTime: sessionStartTime,
                correctCount: correctCount,
                studiedCount: studiedCount
            )
            
            // Card Area
            if currentCardIndex < currentFlashcards.count {
                let flashcardContext = currentFlashcards[currentCardIndex]
                
                ImprovedStudyCard(
                    flashcard: flashcardContext,
                    showingBack: $showingBack,
                    dragOffset: $dragOffset,
                    cardRotation: $cardRotation,
                    cardOpacity: $cardOpacity,
                    onSwipeRight: { starAndNext() },
                    onSwipeLeft: { discardAndNext() },
                    onStar: { toggleStar() }
                )
                .padding()
            } else {
                StudySessionCompleteView(
                    correctCount: correctCount,
                    totalCount: studiedCount,
                    sessionDuration: Date().timeIntervalSince(sessionStartTime),
                    onRestart: { restartSession() },
                    onNewSession: { showingSessionSetup = true }
                )
            }
            
            // Action Buttons
            if currentCardIndex < currentFlashcards.count {
                HStack(spacing: 40) {
                    Button(action: { discardAndNext() }) {
                        VStack(spacing: 8) {
                            Image(systemName: "trash.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                            Text("Discard")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { starAndNext() }) {
                        VStack(spacing: 8) {
                            Image(systemName: "star.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.yellow)
                            Text("Star")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.bottom, 30)
            }
            
            // Swipe Hints (only show when card front is visible)
            if currentCardIndex < currentFlashcards.count && !showingBack {
                SwipeHintsView()
                    .padding(.bottom)
            }
        }
    }
    
    // MARK: - Session Management
    
    private func startSession(with config: StudySessionConfig) {
        sessionConfig = config
        showingSessionSetup = false
        sessionStartTime = Date()
        correctCount = 0
        studiedCount = 0
        currentCardIndex = 0
        
        Task {
            await loadFlashcards(for: config)
        }
    }
    
    private func endSession() {
        // Save session data
        Task {
            await saveSessionResults()
        }
        
        // Reset state
        sessionConfig = nil
        showingSessionSetup = true
        currentFlashcards = []
        currentCardIndex = 0
    }
    
    private func restartSession() {
        if let config = sessionConfig {
            startSession(with: config)
        }
    }
    
    // MARK: - Card Navigation
    
    private func starAndNext() {
        guard currentCardIndex < currentFlashcards.count else { return }
        
        // Star the card if not already starred
        if !currentFlashcards[currentCardIndex].isStarred {
            toggleStar()
        }
        
        studiedCount += 1
        
        moveToNextCard()
    }
    
    private func discardAndNext() {
        guard currentCardIndex < currentFlashcards.count else { return }
        
        // Just move to next card without starring
        studiedCount += 1
        
        moveToNextCard()
    }
    
    private func moveToNextCard() {
        withAnimation(.spring()) {
            showingBack = false
            cardRotation = 0
            currentCardIndex += 1
        }
    }
    
    private func toggleStar() {
        guard currentCardIndex < currentFlashcards.count else { return }
        
        currentFlashcards[currentCardIndex].isStarred.toggle()
        
        // Capture the current flashcard and its state before async operation
        let flashcard = currentFlashcards[currentCardIndex]
        let isStarred = flashcard.isStarred
        let quizCardId = flashcard.quizCard.id
        
        // Update in database using consistent user ID approach
        Task {
            let userId = appViewModel.user.id  // Use consistent user ID from app view model
            do {
                try await SupabaseService.shared.starFlashcard(
                    userId: userId,
                    cardId: quizCardId,
                    isStarred: isStarred
                )
            } catch {
                print("❌ Failed to star flashcard: \(error)")
            }
            
            // Don't reload here - let the Manage view reload when it appears
        }
    }
    
    // MARK: - Helper Functions
    
    private func getCurrentUser() async -> Auth.User? {
        var currentUser = SupabaseService.shared.getCurrentUser()
        
        if currentUser == nil {
            // Session restore is automatic in Supabase client
            currentUser = SupabaseService.shared.getCurrentUser()
        }
        
        return currentUser
    }
    
    // MARK: - Data Loading
    
    private func loadFlashcards(for config: StudySessionConfig) async {
        // Use consistent user ID approach
        let userId = appViewModel.user.id
        print("🎯 Loading flashcards for user: \(userId), mode: \(config.type.rawValue)")
        
        // Always try database first, regardless of authentication status
        // The database now has the dev user and proper flashcards
        do {
            let flashcards = try await SupabaseService.shared.fetchFlashcardsForStudyMode(
                userId: userId,
                mode: config.type.rawValue,
                limit: config.cardLimit
            )
            
            if !flashcards.isEmpty {
                print("✅ Loaded \(flashcards.count) flashcards from database")
                
                // Convert to FlashcardWithContext
                currentFlashcards = flashcards.compactMap { dueCard -> FlashcardWithContext? in
                    // Create a QuizCard from the database data, preserving the ID
                    let decoder = JSONDecoder()
                    
                    // Create a dictionary with the quiz card data
                    var cardData: [String: Any] = [
                        "id": dueCard.quizCard.id.uuidString,
                        "article_id": dueCard.quizCard.articleId.uuidString,
                        "question": dueCard.quizCard.question,
                        "answer": dueCard.quizCard.answer,
                        "card_type": dueCard.quizCard.type,
                        "difficulty": dueCard.quizCard.difficulty,
                        "is_active": true,
                        "created_at": Date().timeIntervalSince1970
                    ]
                    
                    if let choices = dueCard.quizCard.choices {
                        cardData["choices"] = choices
                    }
                    
                    // Convert to QuizCard
                    guard let jsonData = try? JSONSerialization.data(withJSONObject: cardData),
                          let quizCard = try? decoder.decode(QuizCard.self, from: jsonData) else {
                        return nil
                    }
                    
                    return FlashcardWithContext(
                        quizCard: quizCard,
                        articleTitle: "Unknown Article",
                        topic: "General",
                        masteryLevel: dueCard.masteryLevel,
                        isStarred: dueCard.isStarred,
                        lastStudied: dueCard.lastStudied
                    )
                }
                
                // Apply smart sorting based on session type
                sortFlashcards(for: config.type)
                return
            }
        } catch {
            print("❌ Failed to load flashcards from database: \(error)")
        }
        
        // Only fall back to local flashcards if database is empty or fails
        print("📱 Falling back to local flashcards")
        await loadLocalFlashcards(for: config)
    }
    
    private func loadLocalFlashcards(for config: StudySessionConfig) async {
        print("🔧 Loading local flashcards for mode: \(config.type.rawValue)")
        
        await MainActor.run {
            // Get all quiz cards from local articles
            let allLocalFlashcards = appViewModel.articles.flatMap { article in
                article.quizCards.map { quizCard in
                    FlashcardWithContext(
                        quizCard: quizCard,
                        articleTitle: article.title,
                        topic: article.topic ?? "General",
                        masteryLevel: 0.0, // Default for local cards
                        isStarred: false, // Default for local cards
                        lastStudied: nil // New card
                    )
                }
            }
            
            // Limit to config.cardLimit
            currentFlashcards = Array(allLocalFlashcards.prefix(config.cardLimit))
            
            print("✅ Loaded \(currentFlashcards.count) local flashcards")
            
            // Apply smart sorting based on session type
            sortFlashcards(for: config.type)
        }
    }
    
    private func sortFlashcards(for sessionType: StudySessionType) {
        switch sessionType {
        case .smartStudy:
            // Mix of overdue, learning, and new cards
            currentFlashcards.sort { card1, card2 in
                // Prioritize overdue cards
                if card1.lastStudied == nil { return false }
                if card2.lastStudied == nil { return true }
                return card1.lastStudied! < card2.lastStudied!
            }
            
        case .starredReview:
            // Only starred cards
            currentFlashcards = currentFlashcards.filter { $0.isStarred }
            print("📌 Filtered to \(currentFlashcards.count) starred cards for review")
            
        case .quickTest:
            // Random mix for variety
            currentFlashcards.shuffle()
            
        case .newCardsOnly:
            // Only unstudied cards
            currentFlashcards = currentFlashcards.filter { $0.lastStudied == nil }
        }
    }
    
    // MARK: - Progress Tracking
    
    private func recordAttempt(flashcard: FlashcardWithContext, correct: Bool) async {
        do {
            // Use consistent user ID approach
            let userId = appViewModel.user.id
            
            try await SupabaseService.shared.recordQuizAttempt(
                userId: userId,
                cardId: flashcard.quizCard.id,
                correct: correct,
                timeSpent: 5
            )
        } catch {
            print("Failed to record attempt: \(error)")
        }
    }
    
    private func saveSessionResults() async {
        guard let config = sessionConfig else { return }
        
        do {
            // Use consistent user ID approach
            let userId = appViewModel.user.id
            
            let sessionId = try await SupabaseService.shared.startStudySession(
                userId: userId,
                sessionType: config.type.rawValue,
                focusTopics: config.focusTopics
            )
            
            let stats = StudySessionStats(
                cardsStudied: studiedCount,
                correctAnswers: correctCount,
                sessionDuration: Int(Date().timeIntervalSince(sessionStartTime)),
                accuracyRate: studiedCount > 0 ? Double(correctCount) / Double(studiedCount) : 0.0
            )
            try await SupabaseService.shared.completeStudySession(sessionId: sessionId, stats: stats)
            
            print("Session saved successfully")
        } catch {
            print("Failed to save session: \(error)")
        }
    }
}

// MARK: - Supporting Views

struct StudySessionSetupView: View {
    @ObservedObject var appViewModel: AppViewModel
    let onStartSession: (StudySessionConfig) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("Choose Your Study Mode")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                ForEach(StudySessionType.allCases, id: \.self) { type in
                    ImprovedStudyModeCard(
                        type: type,
                        onSelect: {
                            let config = StudySessionConfig(
                                type: type,
                                cardLimit: type == .quickTest ? 15 : 30,
                                timeLimit: type == .quickTest ? 10 : nil,
                                focusTopics: []
                            )
                            onStartSession(config)
                        }
                    )
                }
                
                Spacer(minLength: 50)
            }
            .padding()
        }
    }
}

struct ImprovedStudyModeCard: View {
    let type: StudySessionType
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: type.icon)
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(type.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StudyProgressHeader: View {
    let currentCard: Int
    let totalCards: Int
    let sessionTime: Date
    let correctCount: Int
    let studiedCount: Int
    
    @State private var timeElapsed = "00:00"
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 20) {
            // Card Progress
            VStack(alignment: .leading, spacing: 4) {
                Text("Card \(currentCard) of \(totalCards)")
                    .font(.headline)
                ProgressView(value: Double(currentCard), total: Double(max(totalCards, 1)))
                    .tint(.blue)
            }
            .frame(maxWidth: .infinity)
            
            // Stats
            VStack(spacing: 4) {
                HStack(spacing: 12) {
                    Label("\(correctCount)", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Label("\(timeElapsed)", systemImage: "timer")
                        .foregroundColor(.orange)
                }
                .font(.subheadline)
                
                // Removed accuracy display per user request
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .onReceive(timer) { _ in
            let elapsed = Date().timeIntervalSince(sessionTime)
            let minutes = Int(elapsed) / 60
            let seconds = Int(elapsed) % 60
            timeElapsed = String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

struct ImprovedStudyCard: View {
    let flashcard: FlashcardWithContext
    @Binding var showingBack: Bool
    @Binding var dragOffset: CGSize
    @Binding var cardRotation: Double
    @Binding var cardOpacity: Double
    let onSwipeRight: () -> Void
    let onSwipeLeft: () -> Void
    let onStar: () -> Void
    
    var body: some View {
        ZStack {
            // Background card for depth
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray5))
                .offset(x: 5, y: 5)
            
            // Main card
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.black, Color(.darkGray)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    VStack(spacing: 16) {
                        // Topic badge
                        HStack {
                            Text(flashcard.topic)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                            
                            Spacer()
                            
                            Button(action: onStar) {
                                Image(systemName: flashcard.isStarred ? "star.fill" : "star")
                                    .foregroundColor(flashcard.isStarred ? .yellow : .white.opacity(0.6))
                            }
                        }
                        .scaleEffect(x: showingBack ? -1 : 1, y: 1)
                        
                        Spacer()
                        
                        // Content
                        if showingBack {
                            Text(flashcard.quizCard.answer)
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .scaleEffect(x: -1, y: 1)
                                .transition(.opacity)
                        } else {
                            VStack(spacing: 12) {
                                Text(flashcard.quizCard.question)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                Text("Tap to reveal answer")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .transition(.opacity)
                        }
                        
                        Spacer()
                        
                        // Article info
                        Text(flashcard.articleTitle)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .scaleEffect(x: showingBack ? -1 : 1, y: 1)
                    }
                    .padding(24)
                )
        }
        .frame(height: 400)
        .rotation3DEffect(
            .degrees(cardRotation),
            axis: (x: 0, y: 1, z: 0)
        )
        .offset(dragOffset)
        .opacity(cardOpacity)
        .scaleEffect(1 - abs(dragOffset.width) / 500)
        .rotationEffect(.degrees(Double(dragOffset.width) / 20))
        .onTapGesture {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showingBack.toggle()
                cardRotation = showingBack ? 180 : 0
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                    cardOpacity = 1 - abs(value.translation.width) / 200.0
                }
                .onEnded { value in
                    let swipeThreshold: CGFloat = 100
                    
                    if value.translation.width > swipeThreshold {
                        // Swipe right - star
                        withAnimation(.spring()) {
                            dragOffset = CGSize(width: 500, height: 0)
                            cardOpacity = 0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSwipeRight()
                            resetCard()
                        }
                    } else if value.translation.width < -swipeThreshold {
                        // Swipe left - discard
                        withAnimation(.spring()) {
                            dragOffset = CGSize(width: -500, height: 0)
                            cardOpacity = 0
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onSwipeLeft()
                            resetCard()
                        }
                    } else {
                        // Snap back
                        withAnimation(.spring()) {
                            dragOffset = .zero
                            cardOpacity = 1
                        }
                    }
                }
        )
    }
    
    private func resetCard() {
        dragOffset = .zero
        cardOpacity = 1
        // Don't reset showingBack here - it's controlled by the parent
        // showingBack = false  
        cardRotation = 0
    }
}

struct SwipeHintsView: View {
    var body: some View {
        HStack(spacing: 40) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left")
                Text("Discard")
            }
            .font(.caption)
            .foregroundColor(.red)
            
            HStack(spacing: 8) {
                Text("Star")
                Image(systemName: "arrow.right")
            }
            .font(.caption)
            .foregroundColor(.yellow)
        }
        .padding(.horizontal)
    }
}

struct StudySessionCompleteView: View {
    let correctCount: Int
    let totalCount: Int
    let sessionDuration: TimeInterval
    let onRestart: () -> Void
    let onNewSession: () -> Void
    
    var accuracyPercentage: Int {
        totalCount > 0 ? Int(Double(correctCount) / Double(totalCount) * 100) : 0
    }
    
    var formattedDuration: String {
        let minutes = Int(sessionDuration) / 60
        let seconds = Int(sessionDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Session Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 24) {
                // Stats
                HStack(spacing: 40) {
                    VStack(spacing: 8) {
                        Text("\(correctCount)/\(totalCount)")
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("Cards Correct")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Text("\(accuracyPercentage)%")
                            .font(.title)
                            .fontWeight(.semibold)
                            .foregroundColor(accuracyPercentage >= 80 ? .green : .orange)
                        Text("Accuracy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(spacing: 8) {
                        Text(formattedDuration)
                            .font(.title)
                            .fontWeight(.semibold)
                        Text("Duration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Motivational message
                Text(getMotivationalMessage())
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Actions
            VStack(spacing: 16) {
                Button(action: onRestart) {
                    Label("Study Again", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(action: onNewSession) {
                    Label("New Session", systemImage: "plus.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
    
    private func getMotivationalMessage() -> String {
        switch accuracyPercentage {
        case 90...100:
            return "Outstanding! You're mastering this content!"
        case 70...89:
            return "Great job! Keep up the excellent work!"
        case 50...69:
            return "Good effort! Practice makes perfect."
        default:
            return "Keep studying! Every session makes you stronger."
        }
    }
}

// MARK: - Data Models

struct FlashcardWithContext {
    let quizCard: QuizCard
    let articleTitle: String
    let topic: String
    let masteryLevel: Double
    var isStarred: Bool
    let lastStudied: Date?
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading flashcards...")
                .foregroundColor(.secondary)
        }
    }
}