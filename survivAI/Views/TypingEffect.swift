import SwiftUI

struct TypingEffect: View {
    let text: String
    @State private var displayedText: String = ""
    @State private var isTypingComplete = false
    
    var body: some View {
        Text(displayedText)
            .onAppear {
                if !text.isEmpty {
                    startTypingAnimation()
                }
            }
            .onChange(of: text) { _ in
                displayedText = ""
                isTypingComplete = false
                if !text.isEmpty {
                    startTypingAnimation()
                }
            }
    }
    
    private func startTypingAnimation() {
        displayedText = ""
        var charIndex = 0
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            if charIndex < text.count {
                let index = text.index(text.startIndex, offsetBy: charIndex)
                displayedText += String(text[index])
                charIndex += 1
            } else {
                timer.invalidate()
                isTypingComplete = true
            }
        }
    }
} 