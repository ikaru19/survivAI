import Foundation
import Combine

/// Protocol to define the LLM service interface
protocol LLMServiceProtocol {
    func processPrompt(_ prompt: String) async -> String
    func initializeModel() async -> String?
}

/// Service that manages communication with the LLM wrapper
class LLMService: ObservableObject, LLMServiceProtocol {
    // Singleton instance
    static let shared = LLMService()
    
    // Published properties
    @Published var isReady: Bool = false
    @Published var lastError: String? = nil
    
    // Private instance of LLMWrapper
    private let llmWrapper = LLMWrapper()
    
    // Private initializer for singleton
    private init() {
        // Check if model is ready
        DispatchQueue.global(qos: .background).async { [weak self] in
            let testResponse = self?.llmWrapper.runPrompt("test") ?? ""
            DispatchQueue.main.async {
                self?.isReady = !testResponse.isEmpty
            }
        }
    }
    
    /// Get a response from the LLM for a given prompt
    /// - Parameter prompt: The user's prompt
    /// - Returns: The AI response
    /// - Throws: An error if processing fails
    func getResponse(for prompt: String) throws -> String {
        // Log the request
        print("Processing prompt: \(prompt)")
        
        // Check if LLM is ready
        guard isReady else {
            throw LLMServiceError.modelNotReady
        }
        
        // Get response from wrapper
        guard let response = llmWrapper.runPrompt(prompt) else {
            throw LLMServiceError.emptyResponse
        }
        
        return response
    }
    
    // Implementation of protocol methods for backward compatibility
    func processPrompt(_ prompt: String) async -> String {
        do {
            return try getResponse(for: prompt)
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
    
    func initializeModel() async -> String? {
        // Return existing isReady state
        if isReady {
            return "Ready"
        } else {
            // Try to initialize
            if let testResponse = llmWrapper.runPrompt("test") {
                return "Error: Model failed to initialize"
            } else {
                // Update isReady
                DispatchQueue.main.async {
                    self.isReady = true
                }
                return "Ready"
            }
        }
    }
}

/// Custom errors for LLM service
enum LLMServiceError: Error, LocalizedError {
    case modelNotReady
    case emptyResponse
    case processingError(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotReady:
            return "The AI model is not ready yet. Please try again in a moment."
        case .emptyResponse:
            return "The AI couldn't generate a response. Please try rephrasing your emergency."
        case .processingError(let message):
            return "Error processing request: \(message)"
        }
    }
} 
