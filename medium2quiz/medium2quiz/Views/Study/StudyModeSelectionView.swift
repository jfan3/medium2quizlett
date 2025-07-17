import SwiftUI

struct StudyModeSelectionView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedArticle: Article?
    @State private var showingFlashcardStudy = false
    @State private var showingTest = false
    @State private var flashcards: [Flashcard] = []
    @State private var testQuestions: [TestQuestion] = []
    @State private var isLoadingFlashcards = false
    @State private var isLoadingTests = false
    @State private var testUnlocked = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.05), Color.purple.opacity(0.05)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // User Progress Card
                        if let progress = viewModel.userProgress {
                            UserProgressCard(progress: progress)
                                .padding(.horizontal)
                        }
                        
                        // Article Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Content")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(viewModel.articles) { article in
                                        ArticleCard(
                                            article: article,
                                            isSelected: selectedArticle?.id == article.id,
                                            action: {
                                                selectedArticle = article
                                                loadFlashcardsForArticle(article)
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        
                        // Study Modes
                        if selectedArticle != nil {
                            VStack(spacing: 16) {
                                Text("Choose Study Mode")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                // Flashcard Study
                                StudyModeCard(
                                    title: "Study Flashcards",
                                    subtitle: "\(flashcards.count) cards available",
                                    icon: "rectangle.stack.fill",
                                    color: .blue,
                                    isLoading: isLoadingFlashcards,
                                    isEnabled: !flashcards.isEmpty,
                                    action: {
                                        showingFlashcardStudy = true
                                    }
                                )
                                
                                // Test Mode
                                StudyModeCard(
                                    title: "Take Test",
                                    subtitle: testUnlocked ? "\(testQuestions.count) questions ready" : "Master 80% of flashcards to unlock",
                                    icon: "checkmark.circle.fill",
                                    color: .indigo,
                                    isLoading: isLoadingTests,
                                    isEnabled: testUnlocked && !testQuestions.isEmpty,
                                    isLocked: !testUnlocked,
                                    action: {
                                        showingTest = true
                                    }
                                )
                                
                                // Review Mistakes
                                StudyModeCard(
                                    title: "Review Mistakes",
                                    subtitle: "Focus on cards you got wrong",
                                    icon: "exclamationmark.triangle.fill",
                                    color: .orange,
                                    isEnabled: false,
                                    action: {}
                                )
                                
                                // Challenge Mode
                                StudyModeCard(
                                    title: "Challenge Mode",
                                    subtitle: "Test your speed and accuracy",
                                    icon: "bolt.fill",
                                    color: .purple,
                                    isEnabled: false,
                                    action: {}
                                )
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Study")
            .navigationDestination(isPresented: $showingFlashcardStudy) {
                FlashcardStudyView(viewModel: viewModel, flashcards: flashcards)
            }
            .navigationDestination(isPresented: $showingTest) {
                TestView(viewModel: viewModel, testQuestions: testQuestions)
            }
        }
    }
    
    private func loadFlashcardsForArticle(_ article: Article) {
        isLoadingFlashcards = true
        
        Task {
            // TODO: Load flashcards from database
            // For now, convert quiz cards to flashcards
            flashcards = article.quizCards.map { card in
                Flashcard(
                    id: card.id,
                    articleId: article.id,
                    question: card.question,
                    answer: card.answer,
                    explanation: nil,
                    difficulty: mapDifficulty(card.difficulty),
                    tags: [],
                    createdAt: card.createdAt,
                    updatedAt: card.createdAt
                )
            }
            
            isLoadingFlashcards = false
            
            // Check if test is unlocked
            checkTestUnlocked()
        }
    }
    
    private func checkTestUnlocked() {
        // TODO: Check actual mastery from database
        // For now, simulate some mastery
        let masteredCount = flashcards.filter { _ in Bool.random() }.count
        testUnlocked = Double(masteredCount) / Double(flashcards.count) >= 0.8
        
        if testUnlocked {
            loadTestQuestions()
        }
    }
    
    private func loadTestQuestions() {
        isLoadingTests = true
        
        Task {
            // TODO: Generate test questions from flashcards
            // For now, create sample questions
            testQuestions = flashcards.prefix(10).map { flashcard in
                TestQuestion(
                    id: UUID(),
                    flashcardId: flashcard.id,
                    questionType: TestQuestion.QuestionType.multipleChoice,
                    questionData: TestQuestion.QuestionData.multipleChoice(
                        TestQuestion.MultipleChoiceData(
                            question: flashcard.question,
                            options: generateOptions(for: flashcard),
                            correctIndex: 0,
                            explanation: flashcard.explanation
                        )
                    ),
                    createdAt: Date()
                )
            }
            
            isLoadingTests = false
        }
    }
    
    private func generateOptions(for flashcard: Flashcard) -> [String] {
        // TODO: Generate plausible wrong answers
        return [flashcard.answer, "Option B", "Option C", "Option D"].shuffled()
    }
    
    private func mapDifficulty(_ difficulty: String) -> Flashcard.Difficulty {
        switch difficulty.lowercased() {
        case "beginner": return .beginner
        case "advanced": return .advanced
        default: return .intermediate
        }
    }
}

struct UserProgressCard: View {
    let progress: UserProgress
    
    var body: some View {
        VStack(spacing: 16) {
            // Level and XP
            HStack {
                VStack(alignment: .leading) {
                    Text("Level \(progress.level)")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        ProgressView(value: progress.currentLevelProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                        
                        Text("\(progress.xp % 1000)/\(progress.nextLevelXP % 1000) XP")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Streak
                VStack {
                    Image(systemName: "flame.fill")
                        .font(.title)
                        .foregroundColor(progress.streakActive ? .orange : .gray)
                    
                    Text("\(progress.currentStreak)")
                        .font(.headline)
                        .foregroundColor(progress.streakActive ? .orange : .gray)
                }
            }
            
            Divider()
            
            // Stats
            HStack(spacing: 20) {
                StatItem(
                    icon: "dollarsign.circle.fill",
                    value: "\(progress.coins)",
                    color: .yellow
                )
                
                StatItem(
                    icon: "diamond.fill",
                    value: "\(progress.gems)",
                    color: .cyan
                )
                
                StatItem(
                    icon: "clock.fill",
                    value: "\(progress.dailyMinutesStudied)/\(progress.dailyGoalMinutes)m",
                    color: .green
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .gray.opacity(0.2), radius: 10)
        )
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
        }
    }
}

struct ArticleCard: View {
    let article: Article
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(article.title)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            HStack {
                Image(systemName: "rectangle.stack")
                Text("\(article.quizCards.count)")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .frame(width: 150, height: 80)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture {
            action()
        }
    }
}

struct StudyModeCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var isLoading: Bool = false
    var isEnabled: Bool = true
    var isLocked: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            if isEnabled && !isLocked {
                action()
            }
        }) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.title2)
                            .foregroundColor(color.opacity(0.5))
                    } else {
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(isEnabled ? color : .gray)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isEnabled && !isLocked ? .primary : .secondary)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !isLocked {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color(.systemBackground))
                    .shadow(color: .gray.opacity(0.1), radius: 5)
            )
        }
        .disabled(!isEnabled || isLocked)
    }
}