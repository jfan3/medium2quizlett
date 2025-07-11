import SwiftUI

struct ArticleSelectionView: View {
    let articles: [Article]
    @ObservedObject var appViewModel: AppViewModel
    let onBack: () -> Void
    
    @State private var currentArticleIndex = 0
    @State private var displayArticles: [Article] = []
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
            
            if !displayArticles.isEmpty && currentArticleIndex < displayArticles.count {
                let article = displayArticles[currentArticleIndex]
                
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
                    Text("\(currentArticleIndex + 1) of \(displayArticles.count)")
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
            displayArticles = articles
        }
    }
    
    private func moveToNextArticle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if currentArticleIndex < displayArticles.count - 1 {
                currentArticleIndex += 1
                dragOffset = .zero
            } else {
                // All articles processed, start flashcard generation
                startFlashcardGeneration()
            }
        }
    }
    
    private func startFlashcardGeneration() {
        Task {
            await appViewModel.generateFlashcardsForQueuedArticles()
        }
        onBack() // Return to explore view where flashcards will be available
    }
    
    private func acceptArticle(_ article: Article) {
        // Queue the article for flashcard generation
        Task {
            await appViewModel.queueRSSArticle(article)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            moveToNextArticle()
        }
    }
}