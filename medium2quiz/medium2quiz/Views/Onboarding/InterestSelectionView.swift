import SwiftUI

struct InterestSelectionView: View {
    @ObservedObject var appViewModel: AppViewModel
    @Binding var currentStep: OnboardingStep
    @State private var selectedTopics: Set<String> = []
    @State private var visibleTopics: Set<String> = []
    @State private var animationTimer: Timer?
    
    let topics = Topic.defaultTopics.map { $0.name }
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 32) {
                Text("Pick Your Topics")
                    .font(.title)
                    .fontWeight(.bold)
                
                ZStack {
                    ForEach(Array(visibleTopics.enumerated()), id: \.offset) { index, topic in
                        TopicBubble(
                            topic: topic,
                            isSelected: selectedTopics.contains(topic),
                            position: getBubblePosition(for: index)
                        ) {
                            if selectedTopics.contains(topic) {
                                _ = selectedTopics.remove(topic)
                            } else if selectedTopics.count < 5 {
                                _ = selectedTopics.insert(topic)
                            }
                        }
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 20) {
                                withAnimation(.easeOut(duration: 0.5)) {
                                    _ = visibleTopics.remove(topic)
                                }
                            }
                        }
                    }
                }
                .frame(height: 300)
                .padding(.horizontal)
                
                Text("Selected: \(selectedTopics.count)/5")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack {
                Button("Skip") {
                    currentStep = .login
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Next") {
                    appViewModel.updateInterests(Array(selectedTopics))
                    currentStep = .login
                }
                .frame(width: 100, height: 50)
                .background(selectedTopics.count >= 3 ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(selectedTopics.count < 3)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .onAppear {
            startTopicAnimation()
        }
        .onDisappear {
            animationTimer?.invalidate()
        }
    }
    
    private func startTopicAnimation() {
        var topicIndex = 0
        animationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            if topicIndex < topics.count {
                withAnimation(.spring()) {
                    _ = visibleTopics.insert(topics[topicIndex])
                }
                topicIndex += 1
            } else {
                topicIndex = 0
            }
        }
        
        if !topics.isEmpty {
            withAnimation(.spring()) {
                _ = visibleTopics.insert(topics[0])
            }
        }
    }
    
    private func getBubblePosition(for index: Int) -> CGPoint {
        let positions: [CGPoint] = [
            CGPoint(x: 0, y: -50),
            CGPoint(x: 100, y: 0),
            CGPoint(x: -100, y: 50),
            CGPoint(x: 50, y: -100),
            CGPoint(x: -50, y: 100)
        ]
        return positions[index % positions.count]
    }
}

struct TopicBubble: View {
    let topic: String
    let isSelected: Bool
    let position: CGPoint
    let action: () -> Void
    
    @State private var scale: CGFloat = 0
    
    var body: some View {
        Button(action: action) {
            Text(topic)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
                .scaleEffect(scale)
        }
        .offset(x: position.x, y: position.y)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                scale = 1.0
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}