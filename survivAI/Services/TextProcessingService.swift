import Foundation

// All models are defined in the main module

/// Service for text processing and cleanup of AI-generated text
class TextProcessingService {
    
    /// Process AI-generated text for emergency scenarios
    /// - Parameter rawText: The raw text from the LLM
    /// - Returns: Cleaned and formatted text optimized for emergency situations
    static func processEmergencyText(_ rawText: String) -> String {
        // If empty or nil, return fallback
        guard !rawText.isEmpty else {
            return "STAY CALM. I'm having trouble generating a response. Please try again or be more specific about your emergency."
        }
        
        // For debugging
        print("Original text from LLM: \(rawText)")
        
        var cleaned = rawText
        
        // Handle LLama's special Unicode underscore character
        cleaned = cleaned.replacingOccurrences(of: "▁", with: " ")
        
        // First, check if we have the format seen in the debug output
        if cleaned.contains("<0x") && cleaned.contains("_") {
            // Handle this specific format by directly replacing problematic patterns
            
            // Replace all control characters with appropriate replacements
            let newlinePattern = try? NSRegularExpression(pattern: "<0x0A>|<0x0D>", options: [])
            if let matches = newlinePattern?.matches(in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.utf16.count)) {
                for match in matches.reversed() {
                    if let range = Range(match.range, in: cleaned) {
                        cleaned = cleaned.replacingCharacters(in: range, with: "\n")
                    }
                }
            }
            
            // Remove all other control characters
            let otherControlChars = try? NSRegularExpression(pattern: "<0x[0-9A-F]+>", options: [])
            if let matches = otherControlChars?.matches(in: cleaned, options: [], range: NSRange(location: 0, length: cleaned.utf16.count)) {
                for match in matches.reversed() {
                    if let range = Range(match.range, in: cleaned) {
                        cleaned = cleaned.replacingCharacters(in: range, with: "")
                    }
                }
            }
        }
        
        // Remove any role markers or special tags
        let rolePrefixes = ["|assistant|>", "<|user|>", "<assistant>", "<user>", "|user|"]
        for prefix in rolePrefixes {
            cleaned = cleaned.replacingOccurrences(of: prefix, with: "")
        }
        
        // Replace all underscores with spaces
        cleaned = cleaned.replacingOccurrences(of: "_", with: " ")
        
        // Clean up multiple spaces
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Trim whitespace
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return cleaned
    }
    
    /// Generate a fallback response when AI fails
    /// - Parameter query: The user's query
    /// - Returns: An appropriate fallback response
    static func generateFallbackResponse(for query: String) -> String {
        let query = query.lowercased()
        
        // Medical emergency fallbacks
        if query.contains("breath") || query.contains("heart") || query.contains("choking") {
            return "STAY CALM. If someone can't breathe, ensure their airway is clear. If they're choking, perform abdominal thrusts. If they have no pulse, begin CPR immediately and seek emergency medical help."
        }
        
        // Cold-related emergency
        if query.contains("cold") || query.contains("freezing") || query.contains("snow") {
            return "STAY WARM! To stay warm, wear a sweater, scarf, or blanket. If you have a fireplace, light one. Remember to turn off all lights and electronics as they can help warm up your surroundings. Also, if you're camping, make sure you have extra blankets and food in case of sudden weather changes. If you're not camping, wrap yourself in a blanket and make sure you have enough dry clothes to dress in. Lastly, if you're alone, try to find a place with some privacy and shelter. Remember, emergencies can happen to anyone, so be prepared."
        }
        
        // Fire emergency
        if query.contains("fire") || query.contains("burning") {
            return "STAY LOW to avoid smoke. EXIT immediately - don't collect belongings. FEEL doors before opening - if hot, find another exit. Close doors behind you to slow the fire. CALL emergency services once outside. NEVER go back inside a burning building."
        }
        
        // Lost in wilderness
        if query.contains("lost") || query.contains("wilderness") || query.contains("forest") {
            return "STAY WHERE YOU ARE. Moving may take you farther from search teams. Find shelter from elements. Create visible signals (bright clothing, rocks arranged in patterns). Conserve food and water. If you have a whistle, blow three times as a distress signal."
        }
        
        // Generic emergency response if no specific case is matched
        return "1. STAY CALM AND ASSESS the situation.\n2. Check for breathing, severe bleeding, and consciousness level.\n3. Apply direct pressure to any serious bleeding.\n4. Keep airways clear if breathing is compromised.\n5. Keep the victim still if trauma is suspected.\n6. Create clear signals for rescuers - use bright colors, fires, or reflective objects.\n7. Conserve resources and prioritize water, shelter, warmth in that order."
    }
} 

