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
        let cleanedText = cleanText(text)
        let components = parseMessageComponents(cleanedText)
        
        if components.isEmpty {
            Text(cleanedText)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                    componentView(component)
                }
            }
        }
    }
    
    @ViewBuilder
    private func componentView(_ component: MessageComponent) -> some View {
        switch component {
        case .paragraph(let text):
            Text(text)
                .font(.body)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            
        case .numberedItem(let number, let text):
            HStack(alignment: .top, spacing: 8) {
                Text("\(number).")
                    .font(.body.weight(.semibold))
                    .foregroundColor(.red)
                    .frame(minWidth: 20, alignment: .trailing)
                
                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
        case .bulletItem(let text):
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundColor(.red)
                    .padding(.top, 6)
                
                Text(text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private func cleanText(_ text: String) -> String {
        var cleaned = text
        
        // Clean up multiple spaces
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        
        // Clean up multiple newlines (keep max 2 for paragraph breaks)
        while cleaned.contains("\n\n\n") {
            cleaned = cleaned.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func parseMessageComponents(_ text: String) -> [MessageComponent] {
        var components: [MessageComponent] = []
        let lines = text.components(separatedBy: "\n")
        var currentParagraph = ""
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines - they just create paragraph breaks
            if trimmedLine.isEmpty {
                if !currentParagraph.isEmpty {
                    components.append(.paragraph(currentParagraph.trimmingCharacters(in: .whitespaces)))
                    currentParagraph = ""
                }
                continue
            }
            
            // Check for numbered list items (e.g., "1.", "2.", etc.)
            if let match = trimmedLine.range(of: #"^(\d+)\.\s+"#, options: .regularExpression) {
                // Save any accumulated paragraph
                if !currentParagraph.isEmpty {
                    components.append(.paragraph(currentParagraph.trimmingCharacters(in: .whitespaces)))
                    currentParagraph = ""
                }
                
                let numberStr = String(trimmedLine[match]).replacingOccurrences(of: ".", with: "").trimmingCharacters(in: .whitespaces)
                let content = String(trimmedLine[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                
                if let number = Int(numberStr), !content.isEmpty {
                    components.append(.numberedItem(number: number, text: content))
                }
            }
            // Check for bullet points
            else if trimmedLine.hasPrefix("• ") || trimmedLine.hasPrefix("- ") {
                // Save any accumulated paragraph
                if !currentParagraph.isEmpty {
                    components.append(.paragraph(currentParagraph.trimmingCharacters(in: .whitespaces)))
                    currentParagraph = ""
                }
                
                let content = String(trimmedLine.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !content.isEmpty {
                    components.append(.bulletItem(content))
                }
            }
            // Regular text - accumulate as paragraph
            else {
                if !currentParagraph.isEmpty {
                    currentParagraph += " "
                }
                currentParagraph += trimmedLine
            }
        }
        
        // Add any remaining paragraph
        if !currentParagraph.isEmpty {
            components.append(.paragraph(currentParagraph.trimmingCharacters(in: .whitespaces)))
        }
        
        return components
    }
}

enum MessageComponent {
    case paragraph(String)
    case numberedItem(number: Int, text: String)
    case bulletItem(String)
}
