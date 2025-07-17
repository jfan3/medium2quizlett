import SwiftUI

enum ManageFilter: String, CaseIterable {
    case queued = "Queued"
    case inProgress = "In Progress"
    case completed = "Completed"
    case allCards = "All Cards"
    case weakCards = "Weak Cards"
    case acedCards = "Aced Cards"
}

struct ManageView: View {
    @ObservedObject var appViewModel: AppViewModel
    @State private var selectedFilter: ManageFilter = .queued
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats header
                StatsHeaderView(user: appViewModel.user)
                
                // Filter tabs
                FilterTabView(selectedFilter: $selectedFilter)
                
                // Content list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        switch selectedFilter {
                        case .queued:
                            ForEach(appViewModel.getArticles(by: .queued)) { article in
                                ArticleRowView(article: article, appViewModel: appViewModel)
                            }
                        case .inProgress:
                            ForEach(appViewModel.getArticles(by: .inProgress)) { article in
                                ArticleRowView(article: article, appViewModel: appViewModel)
                            }
                        case .completed:
                            ForEach(appViewModel.getArticles(by: .completed)) { article in
                                ArticleRowView(article: article, appViewModel: appViewModel)
                            }
                        case .allCards:
                            // Always try to show database flashcards first
                            if !appViewModel.userFlashcards.isEmpty {
                                ForEach(appViewModel.userFlashcards.filter { $0.isStarred }, id: \.id) { flashcard in
                                    FlashcardRowView(flashcard: flashcard, appViewModel: appViewModel)
                                }
                            } else {
                                // Only show local as absolute fallback
                                ForEach(getAllLocalFlashcards()) { card in
                                    LocalQuizCardRowView(card: card)
                                }
                            }
                        case .weakCards:
                            ForEach(appViewModel.getWeakCards()) { card in
                                QuizCardRowView(card: card, appViewModel: appViewModel)
                            }
                        case .acedCards:
                            ForEach(appViewModel.getAcedCards()) { card in
                                QuizCardRowView(card: card, appViewModel: appViewModel)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                if getContentCount() == 0 {
                    EmptyManageView(filter: selectedFilter)
                }
            }
            .navigationTitle("Manage")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                Task {
                    await appViewModel.loadUserFlashcards()
                }
            }
            .onChange(of: selectedFilter) { _, newFilter in
                if newFilter == .allCards || newFilter == .weakCards || newFilter == .acedCards {
                    Task {
                        await appViewModel.loadUserFlashcards()
                    }
                }
            }
        }
    }
    
    private func getContentCount() -> Int {
        switch selectedFilter {
        case .queued:
            return appViewModel.getArticles(by: .queued).count
        case .inProgress:
            return appViewModel.getArticles(by: .inProgress).count
        case .completed:
            return appViewModel.getArticles(by: .completed).count
        case .allCards:
            if appViewModel.isAuthenticated {
                return appViewModel.userFlashcards.filter { $0.isStarred }.count
            } else {
                return getAllLocalFlashcards().count
            }
        case .weakCards:
            return appViewModel.getWeakCards().count
        case .acedCards:
            return appViewModel.getAcedCards().count
        }
    }
    
    private func getAllLocalFlashcards() -> [QuizCard] {
        return appViewModel.articles.flatMap { $0.quizCards }
    }
}

struct StatsHeaderView: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 24) {
            ManageStatItem(
                icon: "target",
                value: "\(user.accuracyPercentage)%",
                label: "Overall Accuracy",
                color: .red
            )
            
            ManageStatItem(
                icon: "flame.fill",
                value: "\(user.streakDays) days",
                label: "Streak",
                color: .orange
            )
            
            ManageStatItem(
                icon: "person.circle.fill",
                value: "Profile",
                label: "",
                color: .blue
            )
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct ManageStatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            if !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct FilterTabView: View {
    @Binding var selectedFilter: ManageFilter
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(ManageFilter.allCases, id: \.rawValue) { filter in
                    Button(filter.rawValue) {
                        selectedFilter = filter
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(selectedFilter == filter ? Color.blue : Color.clear)
                    .foregroundColor(selectedFilter == filter ? .white : .primary)
                    .cornerRadius(20)
                    .font(.subheadline)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
    }
}

struct ArticleRowView: View {
    let article: Article
    @ObservedObject var appViewModel: AppViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Article thumbnail
            AsyncImage(url: URL(string: article.imageURL ?? "")) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .overlay(
                        Image(systemName: "doc.text")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 60, height: 60)
            .cornerRadius(8)
            .clipped()
            
            // Article info
            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.headline)
                    .lineLimit(2)
                
                Text("\(article.completedCards) / \(article.totalCards) cards")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                ProgressView(value: article.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            }
            
            Spacer()
            
            // Status indicator
            Circle()
                .fill(statusColor(for: article.status))
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func statusColor(for status: ArticleStatus) -> Color {
        switch status {
        case .queued: return .orange
        case .inProgress: return .blue
        case .completed: return .green
        }
    }
}

struct QuizCardRowView: View {
    let card: QuizCard
    @ObservedObject var appViewModel: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.question)
                .font(.headline)
                .lineLimit(2)
            
            Text(card.answer)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                Text("Accuracy: \(Int(card.accuracy * 100))%")
                    .font(.caption)
                    .foregroundColor(card.isWeak ? .red : card.isAced ? .green : .primary)
                
                Spacer()
                
                Text("\(card.attempts) attempts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct EmptyManageView: View {
    let filter: ManageFilter
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: emptyIcon)
                .font(.system(size: 50))
                .foregroundColor(.gray)
            
            Text("No \(filter.rawValue.lowercased())")
                .font(.title2)
                .fontWeight(.medium)
            
            Text(emptyMessage)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyIcon: String {
        switch filter {
        case .queued: return "clock"
        case .inProgress: return "play.circle"
        case .completed: return "checkmark.circle"
        case .allCards: return "rectangle.stack"
        case .weakCards: return "exclamationmark.triangle"
        case .acedCards: return "star.circle"
        }
    }
    
    private var emptyMessage: String {
        switch filter {
        case .queued: return "Add some articles to get started"
        case .inProgress: return "Start studying to see articles here"
        case .completed: return "Complete some articles to see them here"
        case .allCards: return "Create some flashcards to see them here"
        case .weakCards: return "Cards you struggle with will appear here"
        case .acedCards: return "Cards you've mastered will appear here"
        }
    }
}

struct FlashcardRowView: View {
    let flashcard: DueFlashcard
    @ObservedObject var appViewModel: AppViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with topic and star
            HStack {
                Text("General")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(6)
                
                Spacer()
                
                Button(action: { toggleStar() }) {
                    Image(systemName: flashcard.isStarred ? "star.fill" : "star")
                        .foregroundColor(flashcard.isStarred ? .yellow : .gray)
                }
            }
            
            // Question
            Text(flashcard.quizCard.question)
                .font(.headline)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            // Answer preview
            Text(flashcard.quizCard.answer)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            // Stats and metadata
            HStack {
                // Mastery level
                HStack(spacing: 4) {
                    Circle()
                        .fill(masteryColor)
                        .frame(width: 8, height: 8)
                    Text(masteryText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Last studied
                if let lastStudied = flashcard.lastStudied {
                    Text("Studied \(timeAgoString(from: lastStudied))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("New card")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var masteryColor: Color {
        if flashcard.masteryLevel >= 0.8 {
            return .green
        } else if flashcard.masteryLevel >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var masteryText: String {
        if flashcard.masteryLevel >= 0.8 {
            return "Mastered"
        } else if flashcard.masteryLevel >= 0.5 {
            return "Learning"
        } else {
            return "Needs practice"
        }
    }
    
    private func toggleStar() {
        // Update in database
        Task {
            let userId = appViewModel.user.id
            try? await SupabaseService.shared.starFlashcard(
                userId: userId,
                cardId: flashcard.quizCard.id,
                isStarred: !flashcard.isStarred
            )
            
            // Reload flashcards to reflect changes
            await appViewModel.loadUserFlashcards()
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 3600 { // Less than 1 hour
            let minutes = Int(timeInterval / 60)
            return "\(minutes)m ago"
        } else if timeInterval < 86400 { // Less than 1 day
            let hours = Int(timeInterval / 3600)
            return "\(hours)h ago"
        } else { // 1 day or more
            let days = Int(timeInterval / 86400)
            return "\(days)d ago"
        }
    }
}

struct LocalQuizCardRowView: View {
    let card: QuizCard
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(card.question)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)
                    
                    Text(card.answer)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(card.difficulty.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)
                    
                    Text("Local")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}