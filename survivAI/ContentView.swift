//
//  ContentView.swift
//  survivAI
//
//  Created by Muhammad Syafrizal on 03/05/25.
//

import SwiftUI

struct ContentView: View {
    @State private var userInput: String = ""
    @State private var chatHistory: [EmergencyResponse] = []
    @State private var isProcessing = false
    @State private var errorMessage: String? = nil
    
    // Access LLMWrapper through ObservableObject to ensure UI updates
    @ObservedObject private var llmService = LLMService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // App header
            HStack {
                Image(systemName: "cross.case.fill")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.red)
                
                Text("survivAI")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                
                Spacer()
                
                Button(action: {
                    // Show info/about screen
                }) {
                    Image(systemName: "info.circle")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.red)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            
            // Chat history display
            ScrollViewReader { scrollView in
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(chatHistory) { message in
                            MessageView(message: message, useTypingAnimation: !message.isUser)
                                .id(message.id)
                        }
                        
                        // Show typing indicator when processing
                        if isProcessing {
                            HStack {
                                VStack(alignment: .leading) {
                                    TypingIndicator()
                                }
                                .background(
                                    ChatBubble(isFromUser: false)
                                        .fill(Color.gray.opacity(0.3))
                                )
                                
                                Spacer(minLength: 60)
                            }
                            .padding(.horizontal)
                            .id("typing")
                        }
                    }
                    .padding(.top, 8)
                }
                .onChange(of: chatHistory.count) { _ in
                    // Scroll to bottom when chat history changes
                    if let lastMessage = chatHistory.last {
                        withAnimation {
                            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: isProcessing) { newValue in
                    // Scroll to typing indicator when it appears
                    if newValue {
                        withAnimation {
                            scrollView.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
            }
            
            // Error message display (if any)
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
            
            // Input field and send button
            HStack {
                TextField("Describe your emergency...", text: $userInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isProcessing)
                
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(isProcessing || userInput.isEmpty ? .gray : .red)
                }
                .disabled(userInput.isEmpty || isProcessing)
            }
            .padding()
        }
        .background(Color(UIColor.systemBackground))
        .onAppear {
            // Add welcome message when app loads
            let welcomeMessage = EmergencyResponse(
                message: "I'm survivAI, your emergency assistant. What situation are you facing?",
                isUser: false
            )
            chatHistory.append(welcomeMessage)
        }
    }
    
    private func sendMessage() {
        guard !userInput.isEmpty && !isProcessing else { return }
        
        // Add user message to chat
        let userMessage = EmergencyResponse(message: userInput, isUser: true)
        chatHistory.append(userMessage)
        
        // Save and clear input
        let query = userInput
        userInput = ""
        isProcessing = true
        errorMessage = nil
        
        // Process in background
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let aiResponse = try llmService.getResponse(for: query)
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    // Process the response
                    let cleanedResponse = TextProcessingService.processEmergencyText(aiResponse)
                    
                    // Add AI response
                    let responseMessage = EmergencyResponse(message: cleanedResponse, isUser: false)
                    chatHistory.append(responseMessage)
                    isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    // Show error and fallback
                    errorMessage = "Processing error: \(error.localizedDescription)"
                    let fallbackResponse = TextProcessingService.generateFallbackResponse(for: query)
                    let fallbackMessage = EmergencyResponse(message: fallbackResponse, isUser: false)
                    chatHistory.append(fallbackMessage)
                    isProcessing = false
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

