import Foundation

enum ArticleStatus: String, CaseIterable, Codable {
    case queued = "Queued"
    case inProgress = "In Progress"
    case completed = "Completed"
}

enum ContentSource: String, CaseIterable, Codable {
    case rss = "RSS"
    case link = "Link"
    case pdf = "PDF"
    case text = "Text"
}

struct Article: Codable, Identifiable {
    let id: UUID
    let title: String
    let url: String?
    let content: String
    let source: ContentSource
    let topic: String?
    let imageURL: String?
    let publishedDate: Date
    var status: ArticleStatus
    var quizCards: [QuizCard]
    var isStarred: Bool
    
    init(title: String, url: String?, content: String, source: ContentSource, topic: String?, imageURL: String?, publishedDate: Date) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.content = content
        self.source = source
        self.topic = topic
        self.imageURL = imageURL
        self.publishedDate = publishedDate
        self.status = .queued
        self.quizCards = []
        self.isStarred = false
    }
    
    init(id: UUID, title: String, url: String?, content: String, source: ContentSource, topic: String?, imageURL: String?, publishedDate: Date, status: ArticleStatus, quizCards: [QuizCard], isStarred: Bool) {
        self.id = id
        self.title = title
        self.url = url
        self.content = content
        self.source = source
        self.topic = topic
        self.imageURL = imageURL
        self.publishedDate = publishedDate
        self.status = status
        self.quizCards = quizCards
        self.isStarred = isStarred
    }
    
    var totalCards: Int {
        quizCards.count
    }
    
    var completedCards: Int {
        quizCards.filter { $0.isCompleted }.count
    }
    
    var progress: Double {
        guard totalCards > 0 else { return 0 }
        return Double(completedCards) / Double(totalCards)
    }
}