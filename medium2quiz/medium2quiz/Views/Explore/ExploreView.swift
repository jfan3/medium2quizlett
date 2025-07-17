import SwiftUI

struct ExploreView: View {
    @ObservedObject var appViewModel: AppViewModel
    @State private var selectedTopics: Set<String> = []
    @State private var showingRSSSetup = false
    @State private var availableTopics = Topic.defaultTopics
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                if !showingRSSSetup {
                    VStack(spacing: 32) {
                        Text("Pick Your Topics")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Select 1-5 topics you're interested in")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                            ForEach(availableTopics, id: \.id) { topic in
                                StaticTopicButton(
                                    topic: topic.name,
                                    isSelected: selectedTopics.contains(topic.name)
                                ) {
                                    withAnimation(.spring()) {
                                        if selectedTopics.contains(topic.name) {
                                            selectedTopics.remove(topic.name)
                                        } else if selectedTopics.count < 5 {
                                            selectedTopics.insert(topic.name)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 16) {
                            Text("Selected: \(selectedTopics.count)/5")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if selectedTopics.count >= 1 {
                                Button("Setup RSS Feeds") {
                                    showingRSSSetup = true
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding()
                } else {
                    RSSSetupProgressView(
                        selectedTopics: Array(selectedTopics),
                        appViewModel: appViewModel,
                        onBack: { showingRSSSetup = false }
                    )
                }
            }
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct StaticTopicButton: View {
    let topic: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(topic)
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(minHeight: 60)
                .frame(maxWidth: .infinity)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .leading, endPoint: .trailing)
                        } else {
                            LinearGradient(gradient: Gradient(colors: [Color(.systemGray5), Color(.systemGray5)]), startPoint: .leading, endPoint: .trailing)
                        }
                    }
                )
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
                .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
    }
}