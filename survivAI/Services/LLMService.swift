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
    
    // RAG Service (knowledge base + memory)
    private var ragService: RAGService?
    
    // Private initializer for singleton
    private init() {
        // Initialize RAG service
        initializeRAGService()
        
        // Check if model is ready
        DispatchQueue.global(qos: .background).async { [weak self] in
            let testResponse = self?.llmWrapper.runPrompt("test") ?? ""
            DispatchQueue.main.async {
                // Check if the response indicates model is properly loaded
                let isModelLoaded = !testResponse.isEmpty && !testResponse.contains("Error:")
                self?.isReady = isModelLoaded
                
                if !isModelLoaded {
                    self?.lastError = testResponse
                    print("LLM Service initialization failed: \(testResponse)")
                } else {
                    print("LLM Service initialized successfully")
                }
            }
        }
    }
    
    // MARK: - RAG Service Initialization
    
    private func initializeRAGService() {
        // Get paths for databases
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let memoryDBPath = documentsPath.appendingPathComponent("ai_memory.db").path
        
        // Try to get knowledge DB from bundle
        var knowledgeDBPath: String?
        if let bundlePath = Bundle.main.path(forResource: "emergency_knowledge", ofType: "db", inDirectory: "Resources") {
            knowledgeDBPath = bundlePath
            print("✓ Found knowledge database in bundle: \(bundlePath)")
        } else if let bundlePath = Bundle.main.path(forResource: "emergency_knowledge", ofType: "db") {
            knowledgeDBPath = bundlePath
            print("✓ Found knowledge database in root bundle: \(bundlePath)")
        } else {
            print("⚠️ Warning: Knowledge database not found in bundle. RAG features will use fallback.")
        }
        
        // Initialize RAG service if knowledge DB exists
        if let kdbPath = knowledgeDBPath {
            ragService = RAGService(knowledgeDBPath: kdbPath, memoryDBPath: memoryDBPath)
            print("✓ RAG service initialized")
        } else {
            print("⚠️ RAG service not available - using fallback prompts")
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
            if let error = lastError {
                throw LLMServiceError.processingError(error)
            }
            throw LLMServiceError.modelNotReady
        }
        
        // Get memory service to store conversation
        let memoryService = ragService?.getMemoryService()
        let sessionId = memoryService?.getCurrentSessionId()
        
        // Store user message in memory if available
        let messageId = memoryService?.storeConversation(message: prompt, isUser: true, sessionId: sessionId)
        
        // Extract facts from user message
        if let msgId = messageId {
            memoryService?.extractAndStoreMemories(from: prompt, sessionId: sessionId, messageId: msgId)
        }
        
        // Build context-aware system prompt using RAG + memory
        var systemPrompt: String
        if let ragService = ragService, let sid = sessionId {
            systemPrompt = ragService.buildContextForQuery(prompt, sessionId: sid)
            print("Using RAG-enhanced system prompt")
        } else {
            systemPrompt = RAGService.fallbackSystemPrompt()
            print("Using fallback system prompt")
        }
        
        // Set the dynamic system prompt
        llmWrapper.setSystemPrompt(systemPrompt)
        
        // Get response from wrapper
        guard let response = llmWrapper.runPrompt(prompt) else {
            throw LLMServiceError.emptyResponse
        }
        
        // Check if response contains an error
        if response.contains("Error:") {
            throw LLMServiceError.processingError(response)
        }
        
        // Store AI response in memory
        memoryService?.storeConversation(message: response, isUser: false, sessionId: sessionId)
        
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
    
    // MARK: - Memory Management
    
    /// Get memory statistics
    func getMemoryStats() -> (conversations: Int, facts: Int, sessions: Int) {
        if let memoryService = ragService?.getMemoryService() {
            let stats = memoryService.getMemoryStats()
            return (conversations: stats.conversationCount, facts: stats.factCount, sessions: stats.sessionCount)
        }
        return (0, 0, 0)
    }
    
    /// Clear current session memories
    func clearCurrentSession() -> Bool {
        return ragService?.getMemoryService()?.clearCurrentSession() ?? false
    }
    
    /// Clear all memories
    func clearAllMemories() -> Bool {
        return ragService?.getMemoryService()?.clearAllMemories() ?? false
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
