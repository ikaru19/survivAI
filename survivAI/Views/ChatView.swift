import SwiftUI
import Foundation

// All models are defined in the main Module file
// Emergency categories for UI
struct EmergencyCategoryUI: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let questions: [String]
}

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var latestMessageId: UUID? = nil
    @State private var showingCategoryDetail = false
    @State private var selectedCategory: EmergencyCategoryUI? = nil
    
    var body: some View {
        ZStack {
            // Background gradient - red-tinted for emergency focus
            LinearGradient(gradient: Gradient(colors: [Color.white, Color.red.opacity(0.1)]),
                           startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                AppHeader()
                
                if let error = viewModel.modelError {
                    // Error display
                    ErrorView(errorMessage: error)
                } else {
                    // Chat messages with enhanced visuals
                    messagesList
                    
                    // Emergency categories for quick access
                    if viewModel.isModelInitialized {
                        // Emergency menu instead of quick buttons
                        emergencyCategoriesView
                    }
                    
                    // Input area
                    inputArea
                }
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
        .sheet(isPresented: $showingCategoryDetail) {
            if let selectedCategory = selectedCategory {
                categoryDetailView(selectedCategory)
            }
        }
    }
    
    // Update the chatView navigation area
    private var emergencyCategories: [EmergencyCategoryUI] {
        [
            EmergencyCategoryUI(
                title: "Medical",
                icon: "heart",
                color: .red,
                questions: [
                    "First aid for bleeding",
                    "CPR instructions",
                    "Help! Someone collapsed",
                    "Snake bite treatment",
                    "Splint a broken bone"
                ]
            ),
            EmergencyCategoryUI(
                title: "Wilderness",
                icon: "tree",
                color: .green,
                questions: [
                    "Lost in wilderness",
                    "Find north without compass",
                    "Shelter building",
                    "Find water in wild",
                    "Edible plants"
                ]
            ),
            EmergencyCategoryUI(
                title: "Weather",
                icon: "cloud.bolt",
                color: .blue,
                questions: [
                    "Caught in lightning storm",
                    "Flash flood safety",
                    "Hurricane preparation",
                    "Extreme cold survival",
                    "Heat emergency"
                ]
            ),
            EmergencyCategoryUI(
                title: "Fire",
                icon: "flame",
                color: .orange,
                questions: [
                    "Trapped in fire",
                    "Escape burning building",
                    "Smoke inhalation",
                    "Prevent forest fire",
                    "Put out small fire"
                ]
            ),
            EmergencyCategoryUI(
                title: "Travel",
                icon: "car",
                color: .purple,
                questions: [
                    "Car accident help",
                    "Stranded vehicle",
                    "Roadside emergency",
                    "Missing abroad",
                    "Travel medical emergency"
                ]
            )
        ]
    }
    
    // Add emergency category view
    private var emergencyCategoriesView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(emergencyCategories) { category in
                    VStack {
                        Image(systemName: category.icon)
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(category.color)
                            .clipShape(Circle())
                        Text(category.title)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .onTapGesture {
                        showCategorySheet(category)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
    }
    
    // Show the category detail sheet
    private func showCategorySheet(_ category: EmergencyCategoryUI) {
        selectedCategory = category
        showingCategoryDetail = true
    }
    
    // Category detail view
    private func categoryDetailView(_ category: EmergencyCategoryUI) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(.white)
                    .font(.system(size: 20))
                    .padding(8)
                    .background(category.color)
                    .clipShape(Circle())
                
                Text(category.title + " Emergencies")
                    .font(.headline)
                    .foregroundColor(category.color)
                
                Spacer()
                
                Button(action: { showingCategoryDetail = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 24))
                }
            }
            .padding()
            .background(Color.white)
            
            // List of questions
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(category.questions, id: \.self) { question in
                        Button(action: {
                            viewModel.handleQuickQuestion(question)
                            showingCategoryDetail = false
                        }) {
                            HStack {
                                Text(question)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.leading)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.1))
                            )
                        }
                    }
                }
                .padding()
            }   
        }
    }
    
    // Create urgency indicator using ViewBuilder
    @ViewBuilder
    private func createUrgencyIndicator(for message: EmergencyResponse) -> some View {
        if !message.isUser {
            // Simply check if it's an AI message (no urgency level comparison)
            if message.urgencyLevel == .critical {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 12))
                    
                    Text("CRITICAL")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red)
                }
            } else if message.urgencyLevel == .high {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    
                    Text("URGENT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                }
            } else {
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }
    
    // Get background color based on urgency
    private func backgroundColorForMessage(_ message: EmergencyResponse) -> Color {
        if message.isUser {
            return Color.blue
        } else {
            // Vary background color by urgency for AI responses
            switch message.urgencyLevel {
            case .critical:
                return Color.red.opacity(0.15)
            case .high:
                return Color.orange.opacity(0.15)
            case .medium:
                return Color.yellow.opacity(0.15)
            case .low:
                return Color.gray.opacity(0.2)
            }
        }
    }
    
    // Enhanced message view with urgency indicators
    private func enhancedMessageView(for message: EmergencyResponse) -> some View {
        VStack(alignment: message.isUser ? .trailing : .leading, spacing: 0) {
            // Urgency indicator
            createUrgencyIndicator(for: message)
            
            // Actual message
            if viewModel.isTyping && message.id == viewModel.messages.last?.id && !message.isUser {
                TypingEffect(text: message.message)
                    .padding(12)
                    .foregroundColor(message.isUser ? .white : .black)
                    .background(
                        ChatBubble(isFromUser: message.isUser)
                            .fill(backgroundColorForMessage(message))
                    )
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(message.message)
                    .padding(12)
                    .foregroundColor(message.isUser ? .white : .black)
                    .background(
                        ChatBubble(isFromUser: message.isUser)
                            .fill(backgroundColorForMessage(message))
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Timestamp
            Text(formatMessageTime(message.timestamp))
                .font(.system(size: 10))
                .foregroundColor(.gray)
                .padding(.horizontal, 4)
        }
    }
    
    // Format timestamp
    private func formatMessageTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Update messages list to use enhanced message view
    private var messagesList: some View {
        ScrollViewReader { scrollView in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.messages) { message in
                        HStack {
                            if message.isUser {
                                Spacer(minLength: 80)
                            }
                            
                            enhancedMessageView(for: message)
                            
                            if !message.isUser {
                                Spacer(minLength: 80)
                            }
                        }
                        .id(message.id)
                    }
                    
                    if viewModel.isTyping {
                        typingIndicator
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: viewModel.messages.count) { _ in
                scrollToLatestMessage(scrollView)
            }
        }
    }
    
    private func scrollToLatestMessage(_ scrollView: ScrollViewProxy) {
        if let lastMessage = viewModel.messages.last {
            latestMessageId = lastMessage.id
            withAnimation {
                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    private var typingIndicator: some View {
        HStack {
            Text("Typing...")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
            
            Spacer()
        }
        .padding(.horizontal)
    }
    
    private var inputArea: some View {
        VStack(spacing: 0) {
            // Separator line
            Divider()
                .background(Color.gray.opacity(0.3))
            
            HStack(alignment: .bottom, spacing: 8) {
                // Text input with iMessage styling
                HStack {
                    TextField(
                        viewModel.isTyping ? "Waiting for response..." : "Describe your emergency...", 
                        text: $viewModel.inputText,
                        axis: .vertical
                    )
                    .lineLimit(1...6)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .disabled(viewModel.isTyping || !viewModel.isModelInitialized)
                    .opacity(viewModel.isTyping ? 0.6 : 1.0)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.gray.opacity(0.1))
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                // Send button with iMessage styling
                Button(action: viewModel.sendMessage) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isTyping ? Color.gray : Color.red)
                        )
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || 
                         viewModel.isTyping || 
                         !viewModel.isModelInitialized)
                .scaleEffect(viewModel.isTyping ? 0.8 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: viewModel.isTyping)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ErrorView: View {
    let errorMessage: String
    
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundColor(.red)
                .padding()
            
            Text(errorMessage)
                .foregroundColor(.red)
                .padding()
                .multilineTextAlignment(.center)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.red.opacity(0.1))
                )
                .padding()
        }
        .frame(maxHeight: .infinity)
    }
} 
