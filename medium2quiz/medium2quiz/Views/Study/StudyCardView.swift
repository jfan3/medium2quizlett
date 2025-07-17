import SwiftUI

struct StudyCardView: View {
    let card: QuizCard
    let article: Article
    @Binding var showingBack: Bool
    let onStar: () -> Void
    let onDismissArticle: () -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var cardRotation: Double = 0
    
    var body: some View {
        VStack(spacing: 24) {
            // Flash card
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.black, .gray]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 280)
                
                VStack(spacing: 16) {
                    if showingBack {
                        VStack(spacing: 12) {
                            Text(card.answer)
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            if card.type == "multiple_choice", let choices = card.choices {
                                VStack(spacing: 8) {
                                    ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                                        HStack {
                                            Text("\(["A", "B", "C", "D"][index]). \(choice)")
                                                .font(.body)
                                                .foregroundColor(.white.opacity(0.8))
                                            Spacer()
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .scaleEffect(x: -1, y: 1)
                    } else {
                        VStack(spacing: 16) {
                            Text(card.question)
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                            
                            Text("Tap to reveal the answer")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .rotation3DEffect(
                .degrees(cardRotation),
                axis: (x: 0, y: 1, z: 0)
            )
            .offset(dragOffset)
            .scaleEffect(1 - abs(dragOffset.width) / 1000)
            .rotationEffect(.degrees(dragOffset.width / 20))
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
                    }
                    .onEnded { value in
                        let swipeThreshold: CGFloat = 100
                        
                        if value.translation.width > swipeThreshold {
                            // Swipe right - next card or article
                            withAnimation {
                                dragOffset = CGSize(width: 400, height: 0)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                // Move to next card or article
                                resetCard()
                            }
                        } else if value.translation.width < -swipeThreshold {
                            // Swipe left - dismiss article
                            withAnimation {
                                dragOffset = CGSize(width: -400, height: 0)
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onDismissArticle()
                                resetCard()
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring()) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
            .padding(.horizontal)
            
            // Action buttons
            HStack(spacing: 40) {
                Button(action: onDismissArticle) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.title2)
                        Text("Dismiss Article")
                            .font(.caption)
                    }
                    .foregroundColor(.gray)
                }
                
                Button(action: onStar) {
                    VStack(spacing: 4) {
                        Image(systemName: card.isStarred ? "star.fill" : "star")
                            .font(.title2)
                        Text("Star")
                            .font(.caption)
                    }
                    .foregroundColor(card.isStarred ? .yellow : .gray)
                }
            }
            .padding(.horizontal)
            
            // Article info
            VStack(spacing: 4) {
                Text(article.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                
                if let topic = article.topic {
                    Text(topic)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func resetCard() {
        dragOffset = .zero
        showingBack = false
        cardRotation = 0
    }
}