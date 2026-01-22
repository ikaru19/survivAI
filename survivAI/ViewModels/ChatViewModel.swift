import Foundation
import SwiftUI
import Combine

// All models are defined in the main module

class ChatViewModel: ObservableObject {
    @Published var messages: [EmergencyResponse] = []
    @Published var inputText: String = ""
    @Published var isTyping: Bool = false
    @Published var isModelInitialized: Bool = false
    @Published var modelError: String? = nil
    @Published var showWelcomeMessage: Bool = true
    
    // Use the shared LLMService singleton
    private let llmService: LLMServiceProtocol = LLMService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Quick emergency questions for buttons
    let emergencyQuickQuestions = [
        "First aid for bleeding",
        "Lost in wilderness",
        "Earthquake safety",
        "CPR instructions",
        "Hurricane preparation",
        "Car accident help"
    ]
    
    init() {
        initializeModel()
    }
    
    private func initializeModel() {
        Task {
            let testResponse = await llmService.initializeModel()
            
            await MainActor.run {
                if let response = testResponse, response.starts(with: "Error") {
                    self.modelError = response
                } else {
                    self.isModelInitialized = true
                    
                    // Add welcome message if there are no messages
                    if self.messages.isEmpty {
                        let welcomeMessage = EmergencyResponse(
                            message: "I'm survivAI, your emergency assistant. I can help with life-threatening situations without internet. What emergency are you facing?",
                            isUser: false
                        )
                        self.messages.append(welcomeMessage)
                    }
                }
            }
        }
    }
    
    func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard isModelInitialized else { return }
        
        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let emergencyResponse = EmergencyResponse(message: userMessage, isUser: true)
        
        messages.append(emergencyResponse)
        inputText = ""
        showWelcomeMessage = false
        
        generateResponse(for: userMessage)
    }
    
    func handleQuickQuestion(_ question: String) {
        inputText = question
        sendMessage()
    }
    
    private func generateResponse(for userPrompt: String) {
        isTyping = true
        
        Task {
            let response = await llmService.processPrompt(userPrompt)
            
            await MainActor.run {
                self.isTyping = false
                let aiResponse = EmergencyResponse(message: response, isUser: false)
                self.messages.append(aiResponse)
            }
        }
    }
} 
