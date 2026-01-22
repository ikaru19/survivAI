import Foundation
import SQLite3

/// Represents a knowledge chunk from the emergency knowledge base
struct KnowledgeChunk: Hashable, Equatable {
    let id: String
    let category: String
    let keywords: String
    let context: String
    let priority: String
    let embedding: [Float]
    
    /// Calculate relevance score combining keyword match and semantic similarity
    func relevanceScore(queryEmbedding: [Float], keywordMatches: Int) -> Float {
        let semanticScore = cosineSimilarity(embedding, queryEmbedding)
        let keywordBonus = Float(keywordMatches) * 0.2
        return semanticScore + keywordBonus
    }
    
    // Hashable conformance - use id for hashing since it's unique
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // Equatable conformance - compare by id since it's unique
    static func == (lhs: KnowledgeChunk, rhs: KnowledgeChunk) -> Bool {
        return lhs.id == rhs.id
    }
}

/// Service for vector database operations on emergency knowledge base
class VectorDBService {
    private var db: OpaquePointer?
    private let embeddingDim = 384 // all-MiniLM-L6-v2 dimension
    
    /// Initialize the vector database service
    /// - Parameter dbPath: Path to the SQLite database file
    init?(dbPath: String) {
        // Open the database
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            print("Error: Failed to open knowledge database at \(dbPath)")
            if let db = db {
                print("SQLite error: \(String(cString: sqlite3_errmsg(db)))")
                sqlite3_close(db)
            }
            return nil
        }
        
        print("✓ Knowledge database opened: \(dbPath)")
        
        // Verify database structure
        guard verifyDatabase() else {
            print("Error: Database structure validation failed")
            close()
            return nil
        }
    }
    
    deinit {
        close()
    }
    
    /// Close the database connection
    func close() {
        if let db = db {
            sqlite3_close(db)
            self.db = nil
        }
    }
    
    /// Verify database has required tables and structure
    private func verifyDatabase() -> Bool {
        var statement: OpaquePointer?
        let query = "SELECT name FROM sqlite_master WHERE type='table' AND name='knowledge'"
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) == SQLITE_ROW {
            return true
        }
        
        return false
    }
    
    /// Search for relevant knowledge chunks using hybrid keyword + semantic search
    /// - Parameters:
    ///   - query: The search query text
    ///   - category: Optional category filter
    ///   - limit: Maximum number of results to return
    /// - Returns: Array of knowledge chunks sorted by relevance
    func search(query: String, category: String? = nil, limit: Int = 5) -> [KnowledgeChunk] {
        var results: [KnowledgeChunk] = []
        
        // Extract keywords from query for keyword matching
        let keywords = extractKeywords(from: query)
        
        // Build SQL query with optional category filter
        var sql = """
            SELECT k.id, k.category, k.keywords, k.context, k.priority, k.embedding
            FROM knowledge k
        """
        
        if let cat = category {
            sql += " WHERE k.category = ?"
        }
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("Error preparing search query")
            return results
        }
        
        defer { sqlite3_finalize(statement) }
        
        // Bind category parameter if provided
        if let cat = category {
            sqlite3_bind_text(statement, 1, (cat as NSString).utf8String, -1, nil)
        }
        
        // For simple implementation, we'll do semantic similarity in-memory
        // In production, consider using specialized vector search extensions
        var candidates: [(chunk: KnowledgeChunk, keywordMatches: Int)] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let category = String(cString: sqlite3_column_text(statement, 1))
            let keywords = String(cString: sqlite3_column_text(statement, 2))
            let context = String(cString: sqlite3_column_text(statement, 3))
            let priority = String(cString: sqlite3_column_text(statement, 4))
            
            // Deserialize embedding
            let embeddingBlob = sqlite3_column_blob(statement, 5)
            let embeddingSize = sqlite3_column_bytes(statement, 5)
            let embedding = deserializeEmbedding(data: embeddingBlob, size: Int(embeddingSize))
            
            let chunk = KnowledgeChunk(
                id: id,
                category: category,
                keywords: keywords,
                context: context,
                priority: priority,
                embedding: embedding
            )
            
            // Count keyword matches
            let keywordMatches = countKeywordMatches(keywords: keywords, query: query)
            candidates.append((chunk, keywordMatches))
        }
        
        // If we have a query embedding capability, rank by semantic similarity
        // For now, rank by keyword matches and priority
        candidates.sort { lhs, rhs in
            if lhs.keywordMatches != rhs.keywordMatches {
                return lhs.keywordMatches > rhs.keywordMatches
            }
            return priorityWeight(lhs.chunk.priority) > priorityWeight(rhs.chunk.priority)
        }
        
        results = candidates.prefix(limit).map { $0.chunk }
        
        print("Found \(results.count) knowledge chunks for query: \(query)")
        return results
    }
    
    /// Search using FTS5 full-text search
    /// - Parameters:
    ///   - query: Search query
    ///   - limit: Maximum results
    /// - Returns: Array of matching knowledge chunks
    func fullTextSearch(query: String, limit: Int = 5) -> [KnowledgeChunk] {
        var results: [KnowledgeChunk] = []
        
        let sql = """
            SELECT k.id, k.category, k.keywords, k.context, k.priority, k.embedding
            FROM knowledge k
            JOIN knowledge_fts f ON k.rowid = f.rowid
            WHERE knowledge_fts MATCH ?
            ORDER BY rank
            LIMIT ?
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            print("Error preparing FTS query")
            return results
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, (query as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(limit))
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = String(cString: sqlite3_column_text(statement, 0))
            let category = String(cString: sqlite3_column_text(statement, 1))
            let keywords = String(cString: sqlite3_column_text(statement, 2))
            let context = String(cString: sqlite3_column_text(statement, 3))
            let priority = String(cString: sqlite3_column_text(statement, 4))
            
            let embeddingBlob = sqlite3_column_blob(statement, 5)
            let embeddingSize = sqlite3_column_bytes(statement, 5)
            let embedding = deserializeEmbedding(data: embeddingBlob, size: Int(embeddingSize))
            
            let chunk = KnowledgeChunk(
                id: id,
                category: category,
                keywords: keywords,
                context: context,
                priority: priority,
                embedding: embedding
            )
            
            results.append(chunk)
        }
        
        return results
    }
    
    /// Get all knowledge chunks for a specific category
    /// - Parameter category: The emergency category
    /// - Returns: Array of knowledge chunks
    func getByCategory(_ category: String) -> [KnowledgeChunk] {
        return search(query: "", category: category, limit: 100)
    }
    
    // MARK: - Helper Methods
    
    /// Deserialize embedding from BLOB data
    private func deserializeEmbedding(data: UnsafeRawPointer?, size: Int) -> [Float] {
        guard let data = data, size > 0 else {
            return []
        }
        
        let floatCount = size / MemoryLayout<Float>.size
        let buffer = data.assumingMemoryBound(to: Float.self)
        return Array(UnsafeBufferPointer(start: buffer, count: floatCount))
    }
    
    /// Extract keywords from query text
    private func extractKeywords(from text: String) -> [String] {
        let lowercased = text.lowercased()
        let words = lowercased.components(separatedBy: CharacterSet.alphanumerics.inverted)
        return words.filter { $0.count > 2 } // Filter out very short words
    }
    
    /// Count how many keywords from the chunk match the query
    private func countKeywordMatches(keywords: String, query: String) -> Int {
        let chunkKeywords = keywords.lowercased().components(separatedBy: ", ")
        let queryWords = query.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted)
        
        var matches = 0
        for chunkKeyword in chunkKeywords {
            for queryWord in queryWords {
                if queryWord.contains(chunkKeyword) || chunkKeyword.contains(queryWord) {
                    matches += 1
                    break
                }
            }
        }
        
        return matches
    }
    
    /// Get numeric weight for priority level
    private func priorityWeight(_ priority: String) -> Int {
        switch priority.lowercased() {
        case "critical": return 4
        case "high": return 3
        case "medium": return 2
        case "low": return 1
        default: return 0
        }
    }
}

// MARK: - Vector Math Utilities

/// Calculate cosine similarity between two vectors
func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
    guard a.count == b.count, !a.isEmpty else {
        return 0.0
    }
    
    var dotProduct: Float = 0.0
    var normA: Float = 0.0
    var normB: Float = 0.0
    
    for i in 0..<a.count {
        dotProduct += a[i] * b[i]
        normA += a[i] * a[i]
        normB += b[i] * b[i]
    }
    
    let denominator = sqrt(normA) * sqrt(normB)
    guard denominator > 0 else {
        return 0.0
    }
    
    return dotProduct / denominator
}

/// Calculate Euclidean distance between two vectors
func euclideanDistance(_ a: [Float], _ b: [Float]) -> Float {
    guard a.count == b.count, !a.isEmpty else {
        return Float.infinity
    }
    
    var sum: Float = 0.0
    for i in 0..<a.count {
        let diff = a[i] - b[i]
        sum += diff * diff
    }
    
    return sqrt(sum)
}
