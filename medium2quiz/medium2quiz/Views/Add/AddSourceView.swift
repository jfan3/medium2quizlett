import SwiftUI
import PDFKit

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
                            TextField("Enter PDF URL", text: $sourceContent)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .keyboardType(.URL)
                            
                            Text("Paste a URL to a PDF document")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            // Note: File upload would require document picker
                            // For now, we support URL-based PDFs only
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
        
        Task {
            // Process based on source type
            switch selectedSourceType {
            case .pdf:
                // Extract text from PDF and generate flashcards
                await processPDFSource()
            case .link:
                // Process web link
                await processLinkSource()
            case .text:
                // Process raw text
                await processTextSource()
            }
            
            await MainActor.run {
                isGenerating = false
                showingSuccessAlert = true
            }
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
            // Look for a clear title in the first few lines
            let lines = sourceContent.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            
            // Look for common title patterns
            for line in lines.prefix(10) {
                // Skip common header patterns
                if line.contains("arXiv:") || line.contains("@") || line.contains("Abstract") {
                    continue
                }
                
                // Look for lines that look like titles (not too short, not too long, likely sentences)
                if line.count > 10 && line.count < 100 && 
                   !line.contains("Provided proper attribution") &&
                   !line.contains("Google hereby grants") &&
                   !line.lowercased().contains("abstract") {
                    
                    // Clean up common title artifacts
                    let cleanedLine = line
                        .replacingOccurrences(of: "∗", with: "")
                        .replacingOccurrences(of: "†", with: "")
                        .replacingOccurrences(of: "‡", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if !cleanedLine.isEmpty {
                        return cleanedLine
                    }
                }
            }
            
            // Fallback to first non-empty line
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
                userId: appViewModel.currentUser?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                articleId: articleId,
                question: question,
                answer: answer,
                choices: nil,
                type: QuizCardType.flashcard,
                difficulty: QuizCardDifficulty.medium
            )
        }
    }
    
    // MARK: - PDF Processing
    
    private func processPDFSource() async {
        guard let pdfURL = URL(string: sourceContent) else {
            print("❌ Invalid PDF URL")
            return
        }
        
        do {
            // Download PDF data
            let (data, _) = try await URLSession.shared.data(from: pdfURL)
            
            // Extract text from PDF
            let extractedText = extractTextFromPDF(data: data)
            
            if extractedText.isEmpty {
                print("❌ No text extracted from PDF")
                return
            }
            
            // Create article from PDF content
            // Extract a better title from the PDF content or use filename
            let pdfTitle = pdfURL.lastPathComponent
                .replacingOccurrences(of: ".pdf", with: "")
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
            
            let article = Article(
                id: UUID(),
                title: pdfTitle.isEmpty ? "PDF Document" : pdfTitle,
                url: sourceContent,
                content: extractedText,
                source: .pdf,
                topic: "PDF Document",
                imageURL: nil,
                publishedDate: Date(),
                status: .queued,
                quizCards: [],
                isStarred: false
            )
            
            // Save article to database
            let savedArticle = await saveArticleToDatabase(article)
            
            if let savedArticle = savedArticle {
                // Generate flashcards using Claude with the correct article ID
                await generateFlashcardsForArticle(savedArticle)
            } else {
                print("❌ Skipping flashcard generation due to article save failure")
            }
            
        } catch {
            print("❌ Failed to process PDF: \(error)")
        }
    }
    
    private func extractTextFromPDF(data: Data) -> String {
        // Use PDFKit to extract text from PDF
        guard let pdf = PDFDocument(data: data) else {
            print("❌ Failed to create PDFDocument from data")
            return ""
        }
        
        var fullText = ""
        let pageCount = pdf.pageCount
        
        print("📄 Extracting text from PDF with \(pageCount) pages")
        
        for i in 0..<pageCount {
            if let page = pdf.page(at: i) {
                if let pageText = page.string {
                    fullText += pageText
                    // Add page separator
                    if i < pageCount - 1 {
                        fullText += "\n\n--- Page \(i + 1) ---\n\n"
                    }
                }
            }
        }
        
        print("✅ Extracted \(fullText.count) characters from PDF")
        return fullText
    }
    
    // MARK: - Link Processing
    
    private func processLinkSource() async {
        guard let url = URL(string: sourceContent) else {
            print("❌ Invalid URL")
            return
        }
        
        // Use existing WebFetch functionality to extract content
        // For now, create article with URL
        let article = Article(
            id: UUID(),
            title: "Article from \(url.host ?? "Web")",
            url: sourceContent,
            content: "", // Will be fetched
            source: .link,
            topic: "Web Article",
            imageURL: nil,
            publishedDate: Date(),
            status: .queued,
            quizCards: [],
            isStarred: false
        )
        
        let savedArticle = await saveArticleToDatabase(article)
        
        if let savedArticle = savedArticle {
            await generateFlashcardsForArticle(savedArticle)
        }
    }
    
    // MARK: - Text Processing
    
    private func processTextSource() async {
        let article = Article(
            id: UUID(),
            title: extractTitleFromContent(),
            url: nil,
            content: sourceContent,
            source: .text,
            topic: "Custom Content",
            imageURL: nil,
            publishedDate: Date(),
            status: .queued,
            quizCards: [],
            isStarred: false
        )
        
        let savedArticle = await saveArticleToDatabase(article)
        
        if let savedArticle = savedArticle {
            await generateFlashcardsForArticle(savedArticle)
        }
    }
    
    // MARK: - Database Operations
    
    private func saveArticleToDatabase(_ article: Article) async -> Article? {
        // Add article to local storage first
        await MainActor.run {
            appViewModel.addArticle(article)
        }
        
        // Always attempt to save to Supabase - let the service handle authentication
        print("📤 Attempting to save article to database...")
        
        // Save to Supabase
        do {
            // Create article in database
            // Generate a summary from the first 200 characters of content
            let summary = String(article.content.prefix(200))
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let _ = (
                id: article.id,
                title: article.title,
                url: article.url,
                content: article.content,
                summary: summary.isEmpty ? nil : summary + "...",
                author: article.source == .pdf ? "PDF Import" : nil,
                publishedDate: article.publishedDate,
                sourceType: article.source.rawValue,
                topics: [article.topic ?? "General"],
                difficultyLevel: "medium",
                estimatedReadTime: max(1, article.content.split(separator: " ").count / 200)
            )
            
            let savedArticle = try await SupabaseService.shared.createArticle(article)
            
            // Placeholder for user article creation
            print("📝 Article would be saved for user: \(appViewModel.user.id)")
            
            print("✅ Article saved to database")
            return savedArticle
        } catch {
            print("❌ Failed to save article to database: \(error)")
            // For now, continue with local processing even if database save fails
            return article // Return original article to continue with flashcard generation
        }
    }
    
    private func generateFlashcardsForArticle(_ article: Article) async {
        // Always attempt database flashcard generation first, fall back to local on error
        print("🤖 Attempting to generate flashcards using Claude...")
        
        do {
            // Generate flashcards using Claude
            try await SupabaseService.shared.generateFlashcards(articleIds: [article.id])
            
            // Get the generated flashcards to initialize user performance
            let flashcards = try await SupabaseService.shared.getQuizCards(articleId: article.id)
            let flashcardIds = flashcards.map { $0.id }
            
            if !flashcardIds.isEmpty {
                // Initialize user performance records for the flashcards
                try await SupabaseService.shared.initializeUserPerformanceRecords(
                    userId: appViewModel.user.id,
                    quizCardIds: flashcardIds
                )
                print("📊 Initialized user performance records for \(flashcardIds.count) flashcards")
            }
            
            print("✅ Generated flashcards and initialized user performance for article")
            
            // Update local article status
            await MainActor.run {
                if let index = appViewModel.articles.firstIndex(where: { $0.id == article.id }) {
                    appViewModel.articles[index].status = .inProgress
                }
            }
            
        } catch {
            print("❌ Failed to generate flashcards with database: \(error)")
            // Don't generate local flashcards - the database cards are what we want
            // Just update the UI to show the error
            await MainActor.run {
                if let index = appViewModel.articles.firstIndex(where: { $0.id == article.id }) {
                    appViewModel.articles[index].status = .queued
                }
            }
        }
    }
    
    private func generateLocalFlashcards(for article: Article) async {
        print("🔧 Generating local flashcards for: \(article.title)")
        
        // Generate simple sample flashcards based on content
        let sampleQuestions = [
            ("What is the main topic of this content?", "The content discusses \(article.title.prefix(50))..."),
            ("What type of document is this?", "This is a \(article.source.rawValue) document containing technical information."),
            ("When was this content created?", "This content was processed on \(DateFormatter.localizedString(from: article.publishedDate, dateStyle: .medium, timeStyle: .none)).")
        ]
        
        let localFlashcards = sampleQuestions.map { question, answer in
            QuizCard(
                userId: appViewModel.currentUser?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                articleId: article.id,
                question: question,
                answer: answer,
                choices: nil,
                type: QuizCardType.flashcard,
                difficulty: QuizCardDifficulty.medium
            )
        }
        
        // Update local article with flashcards
        await MainActor.run {
            if let index = appViewModel.articles.firstIndex(where: { $0.id == article.id }) {
                appViewModel.articles[index].quizCards = localFlashcards
                appViewModel.articles[index].status = .completed
            }
        }
        
        print("✅ Generated \(localFlashcards.count) local flashcards")
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