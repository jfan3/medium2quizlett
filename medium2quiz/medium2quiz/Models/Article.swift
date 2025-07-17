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
        let progress = Double(completedCards) / Double(totalCards)
        return min(max(progress, 0), 1) // Clamp between 0 and 1
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case content
        case source = "source_type"
        case topic
        case imageURL = "image_url"
        case publishedDate = "published_date"
        // Note: status, quizCards, isStarred are UI-only properties, not stored in database
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        content = try container.decode(String.self, forKey: .content)
        source = try container.decode(ContentSource.self, forKey: .source)
        topic = try container.decodeIfPresent(String.self, forKey: .topic)
        imageURL = try container.decodeIfPresent(String.self, forKey: .imageURL)
        publishedDate = try container.decode(Date.self, forKey: .publishedDate)
        
        // UI-only properties with defaults
        status = .queued
        quizCards = []
        isStarred = false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encode(content, forKey: .content)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(topic, forKey: .topic)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encode(publishedDate, forKey: .publishedDate)
        // Note: status, quizCards, isStarred are not encoded to database
    }
}