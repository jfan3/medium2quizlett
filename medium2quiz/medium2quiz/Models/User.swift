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
    var skillLevel: String
    var preferredDifficulty: String
    var dailyStudyGoal: Int
    
    // Create empty user for UI initialization - Use consistent dev ID
    init() {
        self.id = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID() // Consistent dev user ID
        self.occupation = nil
        self.interests = []
        self.isOnboardingComplete = false
        self.overallAccuracy = 0.0
        self.streakDays = 0
        self.lastStudyDate = nil
        self.skillLevel = "beginner"
        self.preferredDifficulty = "medium"
        self.dailyStudyGoal = 20
    }
    
    
    init(id: UUID, occupation: Occupation?, interests: [String], isOnboardingComplete: Bool, overallAccuracy: Double, streakDays: Int, lastStudyDate: Date?, skillLevel: String = "beginner", preferredDifficulty: String = "medium", dailyStudyGoal: Int = 20) {
        self.id = id
        self.occupation = occupation
        self.interests = interests
        self.isOnboardingComplete = isOnboardingComplete
        self.overallAccuracy = overallAccuracy
        self.streakDays = streakDays
        self.lastStudyDate = lastStudyDate
        self.skillLevel = skillLevel
        self.preferredDifficulty = preferredDifficulty
        self.dailyStudyGoal = dailyStudyGoal
    }
    
    var accuracyPercentage: Int {
        Int(overallAccuracy * 100)
    }
}