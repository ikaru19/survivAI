import SwiftUI
import Foundation

// All models are defined in the main module

struct MessageView: View {
    let message: EmergencyResponse
    let useTypingAnimation: Bool
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading) {
                if useTypingAnimation && !message.isUser {
                    formattedMessageView(message.message)
                        .padding(12)
                        .foregroundColor(message.isUser ? Color.white : Color.primary)
                } else {
                    formattedMessageView(message.message)
                        .padding(12)
                        .foregroundColor(message.isUser ? Color.white : Color.primary)
                }
            }
            .background(
                ChatBubble(isFromUser: message.isUser)
                    .fill(message.isUser ? Color.blue : Color.gray.opacity(0.3))
            )
            .fixedSize(horizontal: false, vertical: true) // Important for proper text wrapping
            
            if !message.isUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func formattedMessageView(_ text: String) -> some View {
        if hasBulletPoints(text) {
            bulletPointView(text)
        } else {
            Text(text)
        }
    }
    
    private func hasBulletPoints(_ text: String) -> Bool {
        return text.contains("•") || text.contains("- ")
    }
    
    @ViewBuilder
    private func bulletPointView(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            let bulletItems = parseBulletPoints(text)
            
            ForEach(bulletItems, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 6))
                        .foregroundColor(.red)
                        .padding(.top, 6)
                    
                    Text(item)
                        .font(.body)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
    
    private func parseBulletPoints(_ text: String) -> [String] {
        // First, clean up common LLM artifacts
        var cleanedText = text
            .replacingOccurrences(of: "<0x0A>", with: "\n")  // Replace encoded newlines
            .replacingOccurrences(of: "▁", with: " ")        // Replace space tokens
            .replacingOccurrences(of: "<|end|>", with: "")
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .replacingOccurrences(of: "<|im_start|>", with: "")
            .replacingOccurrences(of: "<|assistant|>", with: "")
            .replacingOccurrences(of: "assistant", with: "")
        
        // Split by bullet points and clean up
        let lines = cleanedText.components(separatedBy: "•")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Further clean each line
        return lines.map { line in
            var cleanLine = line
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Remove any remaining artifacts at the end
            if cleanLine.hasSuffix("assistant") {
                cleanLine = String(cleanLine.dropLast(9)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            // Clean up any double spaces
            while cleanLine.contains("  ") {
                cleanLine = cleanLine.replacingOccurrences(of: "  ", with: " ")
            }
            
            return cleanLine
        }
    }
} 
