import Foundation

struct UserSource: Identifiable, Codable {
    let id: UUID
    let name: String
    let url: String
    let description: String?
    let category: String
    let isActive: Bool
    let userAdded: Bool
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case url
        case description
        case category
        case isActive = "is_active"
        case userAdded = "user_added"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}