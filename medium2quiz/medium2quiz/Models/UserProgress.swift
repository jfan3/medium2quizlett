import Foundation
import SwiftUI

struct UserProgress: Codable {
    let userId: UUID
    var xp: Int
    var coins: Int
    var gems: Int
    var currentStreak: Int
    var longestStreak: Int
    var lastStudyDate: Date?
    var level: Int
    var dailyGoalMinutes: Int
    var dailyMinutesStudied: Int
    var totalStudyTimeMinutes: Int
    
    var nextLevelXP: Int {
        level * 1000
    }
    
    var currentLevelProgress: Double {
        let currentLevelMin = (level - 1) * 1000
        let currentLevelMax = level * 1000
        let progress = Double(xp - currentLevelMin) / Double(currentLevelMax - currentLevelMin)
        return min(max(progress, 0), 1)
    }
    
    var dailyGoalProgress: Double {
        Double(dailyMinutesStudied) / Double(dailyGoalMinutes)
    }
    
    var streakActive: Bool {
        guard let lastDate = lastStudyDate else { return false }
        let calendar = Calendar.current
        let daysSinceLastStudy = calendar.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        return daysSinceLastStudy <= 1
    }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case xp = "xp_points"
        case coins
        case gems
        case currentStreak = "current_streak"
        case longestStreak = "longest_streak"
        case lastStudyDate = "last_study_date"
        case level
        case dailyGoalMinutes = "daily_goal_minutes"
        case dailyMinutesStudied = "daily_minutes_studied"
        case totalStudyTimeMinutes = "total_study_time_minutes"
    }
}

struct Achievement: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let iconName: String
    let category: Category
    let requirementType: RequirementType
    let requirementValue: Int
    let xpReward: Int
    let coinReward: Int
    let gemReward: Int
    let isHidden: Bool
    
    var isEarned: Bool = false
    var earnedAt: Date?
    var progress: Int = 0
    
    enum Category: String, Codable {
        case streak = "streak"
        case mastery = "mastery"
        case speed = "speed"
        case accuracy = "accuracy"
        case social = "social"
        case special = "special"
        
        var color: Color {
            switch self {
            case .streak: return .orange
            case .mastery: return .blue
            case .speed: return .yellow
            case .accuracy: return .green
            case .social: return .purple
            case .special: return .pink
            }
        }
    }
    
    enum RequirementType: String, Codable {
        case count = "count"
        case streak = "streak"
        case percentage = "percentage"
        case time = "time"
    }
    
    var progressPercentage: Double {
        guard requirementValue > 0 else { return 0 }
        return min(Double(progress) / Double(requirementValue), 1.0)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case iconName = "icon_name"
        case category
        case requirementType = "requirement_type"
        case requirementValue = "requirement_value"
        case xpReward = "xp_reward"
        case coinReward = "coin_reward"
        case gemReward = "gem_reward"
        case isHidden = "is_hidden"
    }
}

struct PowerUp: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let iconName: String
    let effectType: EffectType
    let effectValue: Double
    let durationMinutes: Int?
    let coinCost: Int
    let gemCost: Int
    let maxOwned: Int
    
    var quantity: Int = 0
    
    enum EffectType: String, Codable {
        case xpBoost = "xp_boost"
        case timeFreeeze = "time_freeze"
        case streakShield = "streak_shield"
        case hint = "hint"
        case skip = "skip"
        
        var color: Color {
            switch self {
            case .xpBoost: return .purple
            case .timeFreeeze: return .blue
            case .streakShield: return .orange
            case .hint: return .yellow
            case .skip: return .green
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case iconName = "icon_name"
        case effectType = "effect_type"
        case effectValue = "effect_value"
        case durationMinutes = "duration_minutes"
        case coinCost = "coin_cost"
        case gemCost = "gem_cost"
        case maxOwned = "max_owned"
    }
}

struct League: Identifiable, Codable {
    let id: UUID
    let name: String
    let tier: Int
    let minXPRequired: Int
    let iconName: String
    let colorHex: String
    
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tier
        case minXPRequired = "min_xp_required"
        case iconName = "icon_name"
        case colorHex = "color_hex"
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}