import SwiftUI

struct ExploreView: View {
    @ObservedObject var appViewModel: AppViewModel
    @State private var selectedTopics: Set<String> = []
    @State private var showingArticleSelection = false
    @State private var availableTopics = Topic.defaultTopics.map { $0.name }
    @State private var visibleTopics: Set<String> = []
    @State private var animationTimer: Timer?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                if !showingArticleSelection {
                    VStack(spacing: 32) {
                        Text("Pick Your Topics")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        ZStack {
                            ForEach(Array(visibleTopics.enumerated()), id: \.offset) { index, topic in
                                FloatingTopicBubble(
                                    topic: topic,
                                    isSelected: selectedTopics.contains(topic),
                                    position: getBubblePosition(for: index)
                                ) {
                                    withAnimation(.spring()) {
                                        if selectedTopics.contains(topic) {
                                            selectedTopics.remove(topic)
                                        } else {
                                            selectedTopics.insert(topic)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(height: 400)
                        
                        VStack(spacing: 16) {
                            Text("Selected: \(selectedTopics.count)/5")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if selectedTopics.count >= 5 {
                                Button("Find Articles") {
                                    showingArticleSelection = true
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding()
                } else {
                    ArticleSelectionView(
                        selectedTopics: Array(selectedTopics),
                        appViewModel: appViewModel,
                        onBack: { showingArticleSelection = false }
                    )
                }
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if !showingArticleSelection {
                startTopicAnimation()
            }
        }
        .onDisappear {
            animationTimer?.invalidate()
        }
    }
    
    private func startTopicAnimation() {
        var topicIndex = 0
        
        // Show initial topics
        for i in 0..<min(3, availableTopics.count) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.5) {
                withAnimation(.spring()) {
                    _ = visibleTopics.insert(availableTopics[i])
                }
            }
        }
        
        // Continue cycling through topics
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            animationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                // Remove oldest topic
                if let oldestTopic = visibleTopics.first {
                    withAnimation(.easeOut(duration: 0.5)) {
                        _ = visibleTopics.remove(oldestTopic)
                    }
                }
                
                // Add new topic
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if topicIndex < availableTopics.count {
                        withAnimation(.spring()) {
                            _ = visibleTopics.insert(availableTopics[topicIndex])
                        }
                        topicIndex = (topicIndex + 1) % availableTopics.count
                    }
                }
            }
        }
    }
    
    private func getBubblePosition(for index: Int) -> CGPoint {
        let positions: [CGPoint] = [
            CGPoint(x: 0, y: -100),
            CGPoint(x: 120, y: -50),
            CGPoint(x: -120, y: 0),
            CGPoint(x: 80, y: 80),
            CGPoint(x: -80, y: 120),
            CGPoint(x: 0, y: 150)
        ]
        return positions[index % positions.count]
    }
}

struct FloatingTopicBubble: View {
    let topic: String
    let isSelected: Bool
    let position: CGPoint
    let action: () -> Void
    
    @State private var scale: CGFloat = 0
    @State private var offset: CGSize = .zero
    @State private var animationTimer: Timer?
    
    var body: some View {
        Button(action: action) {
            Text(topic)
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    isSelected ? 
                    LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing) :
                    LinearGradient(gradient: Gradient(colors: [Color(.systemGray5), Color(.systemGray4)]), startPoint: .leading, endPoint: .trailing)
                )
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(25)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                .scaleEffect(isSelected ? 1.1 : scale)
        }
        .offset(x: position.x + offset.width, y: position.y + offset.height)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                scale = 1.0
            }
            startFloatingAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func startFloatingAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 2.0)) {
                offset = CGSize(
                    width: CGFloat.random(in: -10...10),
                    height: CGFloat.random(in: -10...10)
                )
            }
        }
    }
}