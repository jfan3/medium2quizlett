import SwiftUI

enum SourceType: String, CaseIterable {
    case link = "Link"
    case pdf = "PDF"
    case text = "Text"
}

struct AddSourceView: View {
    @ObservedObject var appViewModel: AppViewModel
    @State private var selectedSourceType: SourceType = .link
    @State private var sourceContent = ""
    @State private var isGenerating = false
    @State private var showingSuccessAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 32) {
                // Source type selector
                SourceTypeSelector(selectedType: $selectedSourceType)
                
                // Input area
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedSourceType {
                    case .link:
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Paste tech-blog URL or article link", text: $sourceContent)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.URL)
                            
                            Text("Example: https://example.com/article")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                    case .pdf:
                        VStack(spacing: 16) {
                            TextField("PDF URL or file path", text: $sourceContent)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                            
                            Button("Upload PDF") {
                                // Handle PDF upload
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color(.systemGray5))
                            .foregroundColor(.primary)
                            .cornerRadius(12)
                        }
                        
                    case .text:
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Paste your content")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            TextEditor(text: $sourceContent)
                                .frame(minHeight: 200)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Generate button
                Button(action: generateQuizCards) {
                    HStack {
                        if isGenerating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isGenerating ? "Generating..." : "Generate Quiz Cards")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(sourceContent.isEmpty ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                .disabled(sourceContent.isEmpty || isGenerating)
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .navigationTitle("Add Source")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("Success!", isPresented: $showingSuccessAlert) {
            Button("OK") {
                sourceContent = ""
            }
        } message: {
            Text("Quiz cards have been generated and added to your study queue!")
        }
    }
    
    private func generateQuizCards() {
        isGenerating = true
        
        // Simulate API call delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let article = createArticleFromSource()
            appViewModel.addArticle(article)
            
            isGenerating = false
            showingSuccessAlert = true
        }
    }
    
    private func createArticleFromSource() -> Article {
        var article = Article(
            title: extractTitleFromContent(),
            url: selectedSourceType == .link ? sourceContent : nil,
            content: sourceContent,
            source: ContentSource(rawValue: selectedSourceType.rawValue) ?? .text,
            topic: "General",
            imageURL: nil,
            publishedDate: Date()
        )
        
        article.quizCards = generateSampleQuizCards(for: article.id)
        
        return article
    }
    
    private func extractTitleFromContent() -> String {
        switch selectedSourceType {
        case .link:
            return "Article from \(URL(string: sourceContent)?.host ?? "Web")"
        case .pdf:
            return "PDF Document"
        case .text:
            let lines = sourceContent.components(separatedBy: .newlines)
            return lines.first?.prefix(50).description ?? "Custom Content"
        }
    }
    
    private func generateSampleQuizCards(for articleId: UUID) -> [QuizCard] {
        let sampleQuestions = [
            ("What is the main concept discussed?", "The primary focus is on understanding the fundamental principles and their practical applications."),
            ("How does this relate to real-world scenarios?", "It provides concrete examples and case studies that demonstrate practical implementation."),
            ("What are the key benefits mentioned?", "Improved efficiency, better scalability, and enhanced user experience are the main advantages."),
            ("What challenges are identified?", "Technical complexity, resource requirements, and implementation timelines are the primary challenges."),
            ("What recommendations are provided?", "Start with a proof of concept, gather stakeholder feedback, and iterate based on results.")
        ]
        
        return sampleQuestions.map { question, answer in
            QuizCard(
                articleId: articleId,
                question: question,
                answer: answer,
                choices: nil,
                type: .flashcard,
                difficulty: .medium
            )
        }
    }
}

struct SourceTypeSelector: View {
    @Binding var selectedType: SourceType
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(SourceType.allCases, id: \.rawValue) { type in
                Button(type.rawValue) {
                    selectedType = type
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(selectedType == type ? Color.white : Color.clear)
                .foregroundColor(selectedType == type ? .black : .gray)
                .cornerRadius(8)
            }
        }
        .padding(4)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}