import SwiftUI

struct TypingIndicator: View {
    @State private var numberOfDots = 0
    private let dotLimit = 3
    private let animationDuration = 0.5
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<dotLimit, id: \.self) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 7, height: 7)
                    .opacity(index < numberOfDots ? 1 : 0.3)
            }
        }
        .padding(12)
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: animationDuration, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 0.3)) {
                numberOfDots = (numberOfDots + 1) % (dotLimit + 1)
                if numberOfDots == 0 {
                    numberOfDots = 1
                }
            }
        }
    }
} 