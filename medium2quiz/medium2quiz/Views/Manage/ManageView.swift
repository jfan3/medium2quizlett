import SwiftUI

enum ManageFilter: String, CaseIterable {
    case queued = "Queued"
    case inProgress = "In Progress"
    case completed = "Completed"
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
        case .weakCards:
            return appViewModel.getWeakCards().count
        case .acedCards:
            return appViewModel.getAcedCards().count
        }
    }
}

struct StatsHeaderView: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 24) {
            StatItem(
                icon: "target",
                value: "\(user.accuracyPercentage)%",
                label: "Overall Accuracy",
                color: .red
            )
            
            StatItem(
                icon: "flame.fill",
                value: "\(user.streakDays) days",
                label: "Streak",
                color: .orange
            )
            
            StatItem(
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

struct StatItem: View {
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
        case .weakCards: return "exclamationmark.triangle"
        case .acedCards: return "star.circle"
        }
    }
    
    private var emptyMessage: String {
        switch filter {
        case .queued: return "Add some articles to get started"
        case .inProgress: return "Start studying to see articles here"
        case .completed: return "Complete some articles to see them here"
        case .weakCards: return "Cards you struggle with will appear here"
        case .acedCards: return "Cards you've mastered will appear here"
        }
    }
}