import Foundation

/// Service that combines knowledge base (RAG) and semantic memory to build context for LLM
class RAGService {
    private let vectorDB: VectorDBService?
    private let memoryService: MemoryService?
    private let maxContextTokens: Int = 200 // Token budget for retrieved context
    
    init(knowledgeDBPath: String, memoryDBPath: String) {
        self.vectorDB = VectorDBService(dbPath: knowledgeDBPath)
        self.memoryService = MemoryService(dbPath: memoryDBPath)
        
        if vectorDB == nil {
            print("Warning: Knowledge database not available")
        }
        if memoryService == nil {
            print("Warning: Memory service not available")
        }
    }
    
    /// Build a context-aware system prompt for the query
    /// - Parameters:
    ///   - query: User's query/message
    ///   - sessionId: Current session ID
    /// - Returns: System prompt with relevant knowledge and memories injected
    func buildContextForQuery(_ query: String, sessionId: String? = nil) -> String {
        // 1. Analyze query to determine category
        let category = EmergencyCategory.detectCategory(from: query)
        
        // 2. Retrieve relevant knowledge chunks
        let knowledgeChunks = retrieveKnowledge(query: query, category: category)
        
        // 3. Retrieve relevant memories
        let memories = retrieveMemories(query: query, sessionId: sessionId)
        
        // 4. Build the system prompt
        return buildSystemPrompt(
            knowledgeChunks: knowledgeChunks,
            memories: memories,
            category: category
        )
    }
    
    // MARK: - Knowledge Retrieval
    
    private func retrieveKnowledge(query: String, category: EmergencyCategory) -> [KnowledgeChunk] {
        guard let vectorDB = vectorDB else {
            return []
        }
        
        // Try category-specific search first
        var chunks = vectorDB.search(query: query, category: category.rawValue, limit: 3)
        
        // If not enough results, do a general search
        if chunks.count < 2 {
            let generalChunks = vectorDB.search(query: query, limit: 4)
            chunks = Array(Set(chunks + generalChunks)).prefix(4).map { $0 }
        }
        
        return chunks
    }
    
    // MARK: - Memory Retrieval
    
    private func retrieveMemories(query: String, sessionId: String?) -> [SemanticFact] {
        guard let memoryService = memoryService else {
            return []
        }
        
        let sid = sessionId ?? memoryService.getCurrentSessionId()
        return memoryService.retrieveRelevantMemories(for: query, sessionId: sid, limit: 3)
    }
    
    // MARK: - Prompt Building
    
    private func buildSystemPrompt(knowledgeChunks: [KnowledgeChunk], memories: [SemanticFact], category: EmergencyCategory) -> String {
        var prompt = "<|im_start|>system\n"
        
        // Base role definition (minimal)
        prompt += "You are an emergency survival assistant. "
        prompt += "Respond with EXACTLY 5 bullet points. "
        prompt += "Each bullet: • ACTION IN CAPS - brief explanation.\n"
        
        // Add relevant knowledge if available
        if !knowledgeChunks.isEmpty {
            prompt += "\nRELEVANT KNOWLEDGE:\n"
            for (index, chunk) in knowledgeChunks.prefix(3).enumerated() {
                prompt += "\(index + 1). \(chunk.context)\n"
            }
        }
        
        // Add memories if available
        if !memories.isEmpty {
            prompt += "\nCONTEXT FROM PREVIOUS CONVERSATION:\n"
            for memory in memories {
                prompt += "- \(memory.factText)\n"
            }
            prompt += "Use this context to provide continuity in your response.\n"
        }
        
        // Guidance based on category
        if !memories.isEmpty || !knowledgeChunks.isEmpty {
            prompt += "\nProvide specific, actionable advice considering the above information.\n"
        }
        
        prompt += "<|im_end|>"
        
        return prompt
    }
    
    // MARK: - Helper Methods
    
    /// Estimate token count (rough approximation: 1 token ≈ 4 characters)
    private func estimateTokens(_ text: String) -> Int {
        return text.count / 4
    }
    
    /// Truncate context to fit within token budget
    private func truncateToTokenBudget(_ text: String, maxTokens: Int) -> String {
        let estimatedTokens = estimateTokens(text)
        if estimatedTokens <= maxTokens {
            return text
        }
        
        let maxChars = maxTokens * 4
        let truncated = String(text.prefix(maxChars))
        return truncated + "..."
    }
    
    /// Get memory service for external access
    func getMemoryService() -> MemoryService? {
        return memoryService
    }
    
    /// Get vector DB service for external access
    func getVectorDBService() -> VectorDBService? {
        return vectorDB
    }
}

// MARK: - Fallback System Prompts

extension RAGService {
    /// Get a basic fallback system prompt when databases are unavailable
    static func fallbackSystemPrompt() -> String {
        return """
        <|im_start|>system
        You are an emergency survival assistant.
        Respond with EXACTLY 5 bullet points.
        Each bullet: • ACTION IN CAPS - brief explanation.
        Provide clear, actionable emergency guidance.
        <|im_end|>
        """
    }
}
