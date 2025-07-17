import SwiftUI

struct InterestSelectionView: View {
    @ObservedObject var appViewModel: AppViewModel
    @Binding var currentStep: OnboardingStep
    @State private var selectedTopics: Set<String> = []
    
    let topics = Topic.defaultTopics
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 32) {
                Text("Pick Your Topics")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Select 1-5 topics you're interested in")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    ForEach(topics, id: \.id) { topic in
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
                    Task {
                        await appViewModel.updateInterests(Array(selectedTopics))
                    }
                    currentStep = .login
                }
                .frame(width: 100, height: 50)
                .background(selectedTopics.count >= 1 ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(selectedTopics.count < 1)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
    }
}

// StaticTopicButton is now defined in ExploreView.swift and can be reused