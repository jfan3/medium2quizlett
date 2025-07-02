import SwiftUI

struct ArticleSelectionView: View {
    let selectedTopics: [String]
    @ObservedObject var appViewModel: AppViewModel
    let onBack: () -> Void
    
    @State private var currentArticleIndex = 0
    @State private var articles: [Article] = []
    @State private var dragOffset = CGSize.zero
    
    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("Select Articles")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Invisible placeholder for balance
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .opacity(0)
            }
            .padding(.horizontal)
            
            if !articles.isEmpty && currentArticleIndex < articles.count {
                let article = articles[currentArticleIndex]
                
                VStack(spacing: 16) {
                    // Article card
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            AsyncImage(url: URL(string: article.imageURL ?? "")) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.title)
                                            .foregroundColor(.gray)
                                    )
                            }
                            .frame(height: 200)
                            .cornerRadius(12)
                            .clipped()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(article.title)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .lineLimit(3)
                                
                                if let topic = article.topic {
                                    Text(topic)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundColor(.blue)
                                        .cornerRadius(12)
                                }
                                
                                Text(article.content.prefix(150) + "...")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .lineLimit(4)
                            }
                        }
                        .padding()
                    }
                    .frame(height: 400)
                    .offset(dragOffset)
                    .scaleEffect(1 - abs(dragOffset.width) / 1000)
                    .rotationEffect(.degrees(dragOffset.width / 20))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                dragOffset = value.translation
                            }
                            .onEnded { value in
                                let swipeThreshold: CGFloat = 100
                                
                                if value.translation.width > swipeThreshold {
                                    // Swipe right - reject
                                    withAnimation(.spring()) {
                                        dragOffset = CGSize(width: 400, height: 0)
                                    }
                                    moveToNextArticle()
                                } else if value.translation.width < -swipeThreshold {
                                    // Swipe left - accept
                                    withAnimation(.spring()) {
                                        dragOffset = CGSize(width: -400, height: 0)
                                    }
                                    acceptArticle(article)
                                } else {
                                    // Snap back
                                    withAnimation(.spring()) {
                                        dragOffset = .zero
                                    }
                                }
                            }
                    )
                    
                    // Action buttons
                    HStack(spacing: 40) {
                        Button("Pass") {
                            withAnimation(.spring()) {
                                dragOffset = CGSize(width: 400, height: 0)
                            }
                            moveToNextArticle()
                        }
                        .frame(width: 100, height: 50)
                        .background(Color(.systemGray5))
                        .foregroundColor(.gray)
                        .cornerRadius(25)
                        
                        Button("Queue") {
                            withAnimation(.spring()) {
                                dragOffset = CGSize(width: -400, height: 0)
                            }
                            acceptArticle(article)
                        }
                        .frame(width: 100, height: 50)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                    }
                    
                    // Progress indicator
                    Text("\(currentArticleIndex + 1) of \(articles.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("All articles reviewed!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Button("Back to Topics") {
                        onBack()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
            }
            
            Spacer()
        }
        .onAppear {
            loadArticlesForTopics()
        }
    }
    
    private func loadArticlesForTopics() {
        // Simulate loading articles based on selected topics
        articles = generateSampleArticles(for: selectedTopics)
    }
    
    private func moveToNextArticle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if currentArticleIndex < articles.count - 1 {
                currentArticleIndex += 1
                dragOffset = .zero
            }
        }
    }
    
    private func acceptArticle(_ article: Article) {
        appViewModel.addArticle(article)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            moveToNextArticle()
        }
    }
    
    private func generateSampleArticles(for topics: [String]) -> [Article] {
        let sampleTitles = [
            "Understanding Machine Learning Fundamentals",
            "Advanced Data Visualization Techniques",
            "Cloud Computing Best Practices",
            "Cybersecurity in Modern Applications",
            "Blockchain Technology Deep Dive"
        ]
        
        return sampleTitles.enumerated().map { index, title in
            Article(
                title: title,
                url: "https://example.com/article\(index)",
                content: "This is a sample article about \(topics.randomElement() ?? "technology"). It contains detailed information and insights that would be valuable for learning. The content is comprehensive and covers various aspects of the topic in depth.",
                source: .rss,
                topic: topics.randomElement(),
                imageURL: nil,
                publishedDate: Date()
            )
        }
    }
}