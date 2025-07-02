import Foundation

enum Occupation: String, CaseIterable, Codable {
    case softwareEngineer = "Software Engineer"
    case dataScientist = "Data Scientist"
    case productManager = "Product Manager"
    case designer = "Designer"
    case student = "Student"
    case other = "Other"
    
    var icon: String {
        switch self {
        case .softwareEngineer: return "chevron.left.slash.chevron.right"
        case .dataScientist: return "chart.bar.doc.horizontal"
        case .productManager: return "briefcase"
        case .designer: return "paintbrush"
        case .student: return "graduationcap"
        case .other: return "questionmark.circle"
        }
    }
}

struct User: Codable, Identifiable {
    let id: UUID
    var occupation: Occupation?
    var interests: [String]
    var isOnboardingComplete: Bool
    var overallAccuracy: Double
    var streakDays: Int
    var lastStudyDate: Date?
    
    init() {
        self.id = UUID()
        self.occupation = nil
        self.interests = []
        self.isOnboardingComplete = false
        self.overallAccuracy = 0.0
        self.streakDays = 0
        self.lastStudyDate = nil
    }
    
    var accuracyPercentage: Int {
        Int(overallAccuracy * 100)
    }
}