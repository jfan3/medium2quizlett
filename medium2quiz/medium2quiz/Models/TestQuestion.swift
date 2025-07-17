import Foundation

struct TestQuestion: Identifiable, Codable {
    let id: UUID
    let flashcardId: UUID
    let questionType: QuestionType
    let questionData: QuestionData
    let createdAt: Date
    
    var userAnswer: String? = nil
    var isCorrect: Bool? = nil
    var timeSpent: TimeInterval = 0
    
    enum QuestionType: String, Codable, CaseIterable {
        case multipleChoice = "multiple_choice"
        case fillBlank = "fill_blank"
        case trueFalse = "true_false"
        case matching = "matching"
        case shortAnswer = "short_answer"
        
        var displayName: String {
            switch self {
            case .multipleChoice: return "Multiple Choice"
            case .fillBlank: return "Fill in the Blank"
            case .trueFalse: return "True or False"
            case .matching: return "Matching"
            case .shortAnswer: return "Short Answer"
            }
        }
        
        var icon: String {
            switch self {
            case .multipleChoice: return "list.bullet"
            case .fillBlank: return "square.and.pencil"
            case .trueFalse: return "checkmark.circle"
            case .matching: return "arrow.left.arrow.right"
            case .shortAnswer: return "text.cursor"
            }
        }
    }
    
    enum QuestionData: Codable {
        case multipleChoice(MultipleChoiceData)
        case fillBlank(FillBlankData)
        case trueFalse(TrueFalseData)
        case matching(MatchingData)
        case shortAnswer(ShortAnswerData)
        
        enum CodingKeys: String, CodingKey {
            case type
            case data
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            
            switch type {
            case "multiple_choice":
                let data = try container.decode(MultipleChoiceData.self, forKey: .data)
                self = .multipleChoice(data)
            case "fill_blank":
                let data = try container.decode(FillBlankData.self, forKey: .data)
                self = .fillBlank(data)
            case "true_false":
                let data = try container.decode(TrueFalseData.self, forKey: .data)
                self = .trueFalse(data)
            case "matching":
                let data = try container.decode(MatchingData.self, forKey: .data)
                self = .matching(data)
            case "short_answer":
                let data = try container.decode(ShortAnswerData.self, forKey: .data)
                self = .shortAnswer(data)
            default:
                throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown question type")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .multipleChoice(let data):
                try container.encode("multiple_choice", forKey: .type)
                try container.encode(data, forKey: .data)
            case .fillBlank(let data):
                try container.encode("fill_blank", forKey: .type)
                try container.encode(data, forKey: .data)
            case .trueFalse(let data):
                try container.encode("true_false", forKey: .type)
                try container.encode(data, forKey: .data)
            case .matching(let data):
                try container.encode("matching", forKey: .type)
                try container.encode(data, forKey: .data)
            case .shortAnswer(let data):
                try container.encode("short_answer", forKey: .type)
                try container.encode(data, forKey: .data)
            }
        }
    }
    
    struct MultipleChoiceData: Codable {
        let question: String
        let options: [String]
        let correctIndex: Int
        let explanation: String?
    }
    
    struct FillBlankData: Codable {
        let sentence: String
        let blanks: [String]
        let correctAnswers: [String]
    }
    
    struct TrueFalseData: Codable {
        let statement: String
        let isTrue: Bool
        let explanation: String?
    }
    
    struct MatchingPair: Codable {
        let left: String
        let right: String
    }
    
    struct MatchingData: Codable {
        let instruction: String
        let pairs: [MatchingPair]
    }
    
    struct ShortAnswerData: Codable {
        let question: String
        let acceptableAnswers: [String]
        let caseSensitive: Bool
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case flashcardId = "flashcard_id"
        case questionType = "question_type"
        case questionData = "question_data"
        case createdAt = "created_at"
    }
    
    init(id: UUID, flashcardId: UUID, questionType: QuestionType, questionData: QuestionData, createdAt: Date) {
        self.id = id
        self.flashcardId = flashcardId
        self.questionType = questionType
        self.questionData = questionData
        self.createdAt = createdAt
        self.userAnswer = nil
        self.isCorrect = nil
        self.timeSpent = 0
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        flashcardId = try container.decode(UUID.self, forKey: .flashcardId)
        questionType = try container.decode(QuestionType.self, forKey: .questionType)
        questionData = try container.decode(QuestionData.self, forKey: .questionData)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        // Initialize non-Codable properties with defaults
        userAnswer = nil
        isCorrect = nil
        timeSpent = 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(flashcardId, forKey: .flashcardId)
        try container.encode(questionType, forKey: .questionType)
        try container.encode(questionData, forKey: .questionData)
        try container.encode(createdAt, forKey: .createdAt)
        // Don't encode userAnswer, isCorrect, timeSpent as they're runtime properties
    }
    
    func checkAnswer(_ answer: String) -> Bool {
        switch questionData {
        case .multipleChoice(let data):
            guard let index = Int(answer) else { return false }
            return index == data.correctIndex
            
        case .fillBlank(let data):
            let answers = answer.split(separator: "|").map(String.init)
            return answers == data.correctAnswers
            
        case .trueFalse(let data):
            return (answer.lowercased() == "true") == data.isTrue
            
        case .matching(let data):
            let answerPairs = answer.split(separator: "|").map { pair in
                pair.split(separator: ":").map(String.init)
            }
            return answerPairs.count == data.pairs.count
            
        case .shortAnswer(let data):
            if data.caseSensitive {
                return data.acceptableAnswers.contains(answer)
            } else {
                return data.acceptableAnswers.contains { $0.lowercased() == answer.lowercased() }
            }
        }
    }
}