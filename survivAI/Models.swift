import Foundation
import SwiftUI

/// Represents the urgency level of an emergency situation
enum UrgencyLevel: String, Codable, CaseIterable {
    case critical = "CRITICAL" 
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
    
    /// The raw numeric value for sorting/comparison
    var rawValue: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
    
    /// Color associated with this urgency level
    var color: String {
        switch self {
        case .critical: return "red"
        case .high: return "orange" 
        case .medium: return "yellow"
        case .low: return "blue"
        }
    }
    
    /// Estimate urgency based on message content
    static func estimateUrgency(from message: String) -> UrgencyLevel {
        let lowercaseMessage = message.lowercased()
        
        // Critical emergencies (immediate life threat)
        if lowercaseMessage.contains("cannot breathe") || 
           lowercaseMessage.contains("heart attack") ||
           lowercaseMessage.contains("severe bleeding") ||
           lowercaseMessage.contains("choking") ||
           lowercaseMessage.contains("drowning") ||
           lowercaseMessage.contains("suicide") {
            return .critical
        }
        
        // High urgency (serious but not immediately life-threatening)
        if lowercaseMessage.contains("broke") ||
           lowercaseMessage.contains("fracture") ||
           lowercaseMessage.contains("fire") ||
           lowercaseMessage.contains("lost") ||
           lowercaseMessage.contains("hurt") {
            return .high
        }
        
        // Medium urgency
        if lowercaseMessage.contains("sick") ||
           lowercaseMessage.contains("pain") ||
           lowercaseMessage.contains("cold") ||
           lowercaseMessage.contains("hot") {
            return .medium
        }
        
        // Default to low if no keywords found
        return .low
    }
}

/// Defines an emergency category
enum EmergencyCategory: String, Codable, CaseIterable {
    case medical = "Medical"
    case wilderness = "Wilderness"
    case weather = "Weather"
    case fire = "Fire"
    case travel = "Travel"
    case other = "Other"
    
    /// Icon name for this category
    var iconName: String {
        switch self {
        case .medical: return "heart.fill"
        case .wilderness: return "leaf.fill"
        case .weather: return "cloud.rain.fill"
        case .fire: return "flame.fill"
        case .travel: return "car.fill"
        case .other: return "questionmark.circle.fill"
        }
    }
    
    /// Detect category from message content
    static func detectCategory(from message: String) -> EmergencyCategory {
        let lowercaseMessage = message.lowercased()
        
        if lowercaseMessage.contains("bleeding") ||
           lowercaseMessage.contains("pain") ||
           lowercaseMessage.contains("hurt") ||
           lowercaseMessage.contains("sick") ||
           lowercaseMessage.contains("heart") ||
           lowercaseMessage.contains("breath") {
            return .medical
        }
        
        if lowercaseMessage.contains("lost") ||
           lowercaseMessage.contains("forest") ||
           lowercaseMessage.contains("mountain") ||
           lowercaseMessage.contains("trail") ||
           lowercaseMessage.contains("hike") ||
           lowercaseMessage.contains("wilderness") {
            return .wilderness
        }
        
        if lowercaseMessage.contains("snow") ||
           lowercaseMessage.contains("cold") ||
           lowercaseMessage.contains("hot") ||
           lowercaseMessage.contains("heat") ||
           lowercaseMessage.contains("storm") ||
           lowercaseMessage.contains("flood") ||
           lowercaseMessage.contains("rain") ||
           lowercaseMessage.contains("tornado") ||
           lowercaseMessage.contains("hurricane") {
            return .weather
        }
        
        if lowercaseMessage.contains("fire") ||
           lowercaseMessage.contains("burn") ||
           lowercaseMessage.contains("smoke") {
            return .fire
        }
        
        if lowercaseMessage.contains("car") ||
           lowercaseMessage.contains("vehicle") ||
           lowercaseMessage.contains("crash") ||
           lowercaseMessage.contains("accident") ||
           lowercaseMessage.contains("road") ||
           lowercaseMessage.contains("stuck") {
            return .travel
        }
        
        return .other
    }
}

// The core message model for all emergency responses
struct EmergencyResponse: Identifiable {
    let id = UUID()
    let message: String
    let isUser: Bool
    let timestamp: Date
    let urgencyLevel: UrgencyLevel
    
    init(message: String, isUser: Bool, timestamp: Date = Date()) {
        self.message = message
        self.isUser = isUser
        self.timestamp = timestamp
        // Determine urgency level automatically for AI responses
        self.urgencyLevel = isUser ? .low : UrgencyLevel.estimateUrgency(from: message)
    }
} 