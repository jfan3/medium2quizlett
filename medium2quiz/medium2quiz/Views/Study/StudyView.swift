import SwiftUI

enum StudyMode: String, CaseIterable {
    case new = "New"
    case starred = "Starred"
    case test = "Test"
}

struct StudyView: View {
    @ObservedObject var appViewModel: AppViewModel
    @State private var selectedMode: StudyMode = .new
    @State private var currentArticle: Article?
    @State private var currentCardIndex = 0
    @State private var showingBack = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                StudyModeSelector(selectedMode: $selectedMode)
                
                if let article = currentArticle, !article.quizCards.isEmpty {
                    StudyCardView(
                        card: getCurrentCard(),
                        article: article,
                        showingBack: $showingBack,
                        onStar: { starCard() },
                        onDismissArticle: { dismissCurrentArticle() }
                    )
                } else {
                    EmptyStudyView(mode: selectedMode)
                }
                
                if currentArticle != nil {
                    StudyProgressView(
                        flashcardProgress: currentCardIndex + 1,
                        totalFlashcards: currentArticle?.quizCards.count ?? 0,
                        articleProgress: 1,
                        totalArticles: getArticlesForMode().count
                    )
                }
            }
            .navigationTitle("Study New Cards")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            loadArticleForMode()
        }
        .onChange(of: selectedMode) {
            loadArticleForMode()
        }
    }
    
    private func getCurrentCard() -> QuizCard {
        guard let article = currentArticle,
              currentCardIndex < article.quizCards.count else {
            return QuizCard(
                articleId: UUID(),
                question: "",
                answer: "",
                choices: nil,
                type: .flashcard,
                difficulty: .medium
            )
        }
        return article.quizCards[currentCardIndex]
    }
    
    private func getArticlesForMode() -> [Article] {
        switch selectedMode {
        case .new:
            return appViewModel.articles.filter { $0.status == .queued || $0.status == .inProgress }
        case .starred:
            return appViewModel.articles.filter { article in
                article.quizCards.contains { $0.isStarred }
            }
        case .test:
            return appViewModel.articles.filter { $0.status == .inProgress }
        }
    }
    
    private func loadArticleForMode() {
        let articles = getArticlesForMode()
        currentArticle = articles.first
        currentCardIndex = 0
        showingBack = false
    }
    
    private func starCard() {
        guard let article = currentArticle else { return }
        // Update the card in the article
        if let articleIndex = appViewModel.articles.firstIndex(where: { $0.id == article.id }) {
            appViewModel.articles[articleIndex].quizCards[currentCardIndex].isStarred.toggle()
        }
    }
    
    private func dismissCurrentArticle() {
        let articles = getArticlesForMode()
        if let currentIndex = articles.firstIndex(where: { $0.id == currentArticle?.id }),
           currentIndex + 1 < articles.count {
            currentArticle = articles[currentIndex + 1]
            currentCardIndex = 0
            showingBack = false
        } else {
            currentArticle = nil
        }
    }
}

struct StudyModeSelector: View {
    @Binding var selectedMode: StudyMode
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(StudyMode.allCases, id: \.rawValue) { mode in
                Button(mode.rawValue) {
                    selectedMode = mode
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedMode == mode ? Color.white : Color.clear)
                .foregroundColor(selectedMode == mode ? .black : .gray)
                .cornerRadius(8)
            }
        }
        .padding(4)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top)
    }
}

struct EmptyStudyView: View {
    let mode: StudyMode
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No cards available")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Add some articles or check your \(mode.rawValue.lowercased()) collection")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct StudyProgressView: View {
    let flashcardProgress: Int
    let totalFlashcards: Int
    let articleProgress: Int
    let totalArticles: Int
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Flashcard Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(flashcardProgress)/\(totalFlashcards)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: Double(flashcardProgress), total: Double(totalFlashcards))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Article Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("\(articleProgress)/\(totalArticles)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: Double(articleProgress), total: Double(totalArticles))
                    .progressViewStyle(LinearProgressViewStyle(tint: .orange))
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}