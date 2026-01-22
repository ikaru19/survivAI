import Foundation
import SQLite3

/// Represents a semantic fact extracted from conversations
struct SemanticFact {
    let id: Int
    let sessionId: String
    let factType: FactType
    let factText: String
    let sourceMessageId: Int?
    let extractedAt: Date
    let importance: Float
    let embedding: [Float]
    
    enum FactType: String {
        case location
        case condition
        case resource
        case environment
        case temporal
    }
}

/// Represents a stored conversation message
struct ConversationMessage {
    let id: Int
    let sessionId: String
    let message: String
    let isUser: Bool
    let timestamp: Date
    let category: String?
    let urgencyLevel: String?
}

/// Service for managing AI memory - conversation history and semantic memory
class MemoryService {
    private var db: OpaquePointer?
    private let dbPath: String
    private var currentSessionId: String?
    
    // Session configuration
    private let defaultExpiryHours: Int = 48
    
    init?(dbPath: String) {
        self.dbPath = dbPath
        
        // Open or create the database
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
            print("Error: Failed to open memory database at \(dbPath)")
            if let db = db {
                print("SQLite error: \(String(cString: sqlite3_errmsg(db)))")
                sqlite3_close(db)
            }
            return nil
        }
        
        print("✓ Memory database opened: \(dbPath)")
        
        // Create tables if they don't exist
        guard createTables() else {
            print("Error: Failed to create memory database tables")
            close()
            return nil
        }
        
        // Load or create session
        loadOrCreateSession()
        
        // Clean up expired sessions
        cleanupExpiredSessions()
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
    
    // MARK: - Database Setup
    
    private func createTables() -> Bool {
        let tables = [
            """
            CREATE TABLE IF NOT EXISTS conversations (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                message TEXT NOT NULL,
                is_user INTEGER NOT NULL,
                timestamp INTEGER NOT NULL,
                category TEXT,
                urgency_level TEXT
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS semantic_memory (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                fact_type TEXT NOT NULL,
                fact_text TEXT NOT NULL,
                source_message_id INTEGER,
                extracted_at INTEGER NOT NULL,
                embedding BLOB,
                importance REAL DEFAULT 1.0,
                FOREIGN KEY (source_message_id) REFERENCES conversations(id)
            )
            """,
            """
            CREATE TABLE IF NOT EXISTS sessions (
                session_id TEXT PRIMARY KEY,
                started_at INTEGER NOT NULL,
                last_active INTEGER NOT NULL,
                auto_expire_at INTEGER,
                user_cleared INTEGER DEFAULT 0
            )
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_conversations_session
            ON conversations(session_id, timestamp)
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_memory_session
            ON semantic_memory(session_id, fact_type)
            """,
            """
            CREATE INDEX IF NOT EXISTS idx_sessions_expiry
            ON sessions(auto_expire_at)
            """
        ]
        
        for sql in tables {
            if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
                if let db = db {
                    print("Error creating table: \(String(cString: sqlite3_errmsg(db)))")
                }
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Session Management
    
    /// Get the current session ID
    func getCurrentSessionId() -> String {
        return currentSessionId ?? UUID().uuidString
    }
    
    /// Load existing active session or create a new one
    private func loadOrCreateSession() {
        // Try to load most recent non-expired session
        let query = """
            SELECT session_id FROM sessions
            WHERE auto_expire_at > ? AND user_cleared = 0
            ORDER BY last_active DESC
            LIMIT 1
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            createNewSession()
            return
        }
        
        defer { sqlite3_finalize(statement) }
        
        let now = Int(Date().timeIntervalSince1970)
        sqlite3_bind_int64(statement, 1, Int64(now))
        
        if sqlite3_step(statement) == SQLITE_ROW {
            currentSessionId = String(cString: sqlite3_column_text(statement, 0))
            updateSessionActivity()
            print("✓ Loaded existing session: \(currentSessionId!)")
        } else {
            createNewSession()
        }
    }
    
    /// Create a new session
    private func createNewSession() {
        let sessionId = UUID().uuidString
        let now = Int(Date().timeIntervalSince1970)
        let expireAt = now + (defaultExpiryHours * 3600)
        
        let sql = """
            INSERT INTO sessions (session_id, started_at, last_active, auto_expire_at)
            VALUES (?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, (sessionId as NSString).utf8String, -1, nil)
        sqlite3_bind_int64(statement, 2, Int64(now))
        sqlite3_bind_int64(statement, 3, Int64(now))
        sqlite3_bind_int64(statement, 4, Int64(expireAt))
        
        if sqlite3_step(statement) == SQLITE_DONE {
            currentSessionId = sessionId
            print("✓ Created new session: \(sessionId)")
        }
    }
    
    /// Update session last_active timestamp
    private func updateSessionActivity() {
        guard let sessionId = currentSessionId else { return }
        
        let sql = "UPDATE sessions SET last_active = ? WHERE session_id = ?"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        
        defer { sqlite3_finalize(statement) }
        
        let now = Int(Date().timeIntervalSince1970)
        sqlite3_bind_int64(statement, 1, Int64(now))
        sqlite3_bind_text(statement, 2, (sessionId as NSString).utf8String, -1, nil)
        
        sqlite3_step(statement)
    }
    
    /// Clean up expired sessions and their data
    private func cleanupExpiredSessions() {
        let now = Int(Date().timeIntervalSince1970)
        
        // Get expired session IDs
        var expiredSessions: [String] = []
        let selectSql = "SELECT session_id FROM sessions WHERE auto_expire_at < ? OR user_cleared = 1"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, selectSql, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int64(statement, 1, Int64(now))
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let sessionId = String(cString: sqlite3_column_text(statement, 0))
                expiredSessions.append(sessionId)
            }
        }
        sqlite3_finalize(statement)
        
        // Delete data for expired sessions
        for sessionId in expiredSessions {
            _ = clearSession(sessionId)
        }
        
        if !expiredSessions.isEmpty {
            print("✓ Cleaned up \(expiredSessions.count) expired sessions")
        }
    }
    
    // MARK: - Conversation Storage
    
    /// Store a conversation message
    @discardableResult
    func storeConversation(message: String, isUser: Bool, sessionId: String? = nil) -> Int? {
        let sid = sessionId ?? getCurrentSessionId()
        let now = Int(Date().timeIntervalSince1970)
        
        let sql = """
            INSERT INTO conversations (session_id, message, is_user, timestamp)
            VALUES (?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, (sid as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (message as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 3, isUser ? 1 : 0)
        sqlite3_bind_int64(statement, 4, Int64(now))
        
        if sqlite3_step(statement) == SQLITE_DONE {
            updateSessionActivity()
            return Int(sqlite3_last_insert_rowid(db))
        }
        
        return nil
    }
    
    /// Get recent conversation history
    func getRecentConversations(limit: Int = 10, sessionId: String? = nil) -> [ConversationMessage] {
        let sid = sessionId ?? getCurrentSessionId()
        var messages: [ConversationMessage] = []
        
        let sql = """
            SELECT id, session_id, message, is_user, timestamp, category, urgency_level
            FROM conversations
            WHERE session_id = ?
            ORDER BY timestamp DESC
            LIMIT ?
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return messages
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, (sid as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(limit))
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let sessionId = String(cString: sqlite3_column_text(statement, 1))
            let message = String(cString: sqlite3_column_text(statement, 2))
            let isUser = sqlite3_column_int(statement, 3) == 1
            let timestamp = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 4)))
            
            let category = sqlite3_column_text(statement, 5) != nil ?
                String(cString: sqlite3_column_text(statement, 5)) : nil
            let urgencyLevel = sqlite3_column_text(statement, 6) != nil ?
                String(cString: sqlite3_column_text(statement, 6)) : nil
            
            messages.append(ConversationMessage(
                id: id,
                sessionId: sessionId,
                message: message,
                isUser: isUser,
                timestamp: timestamp,
                category: category,
                urgencyLevel: urgencyLevel
            ))
        }
        
        return messages.reversed() // Return in chronological order
    }
    
    // MARK: - Semantic Memory Extraction & Storage
    
    /// Extract and store semantic facts from a message
    func extractAndStoreMemories(from message: String, sessionId: String? = nil, messageId: Int? = nil) {
        let sid = sessionId ?? getCurrentSessionId()
        let facts = extractFacts(from: message)
        
        for (factType, factText, importance) in facts {
            storeFact(
                factType: factType,
                factText: factText,
                sessionId: sid,
                sourceMessageId: messageId,
                importance: importance
            )
        }
        
        if !facts.isEmpty {
            print("✓ Extracted \(facts.count) facts from message")
        }
    }
    
    /// Extract facts using pattern matching
    private func extractFacts(from message: String) -> [(SemanticFact.FactType, String, Float)] {
        var facts: [(SemanticFact.FactType, String, Float)] = []
        let lowercased = message.lowercased()
        
        // Location patterns
        let locationPatterns: [(String, Float)] = [
            ("in the ([a-z]+)", 1.0),
            ("at the ([a-z]+)", 1.0),
            ("near ([a-z]+)", 0.9),
            ("(forest|mountain|desert|city|building|room|vehicle|car)", 1.0)
        ]
        
        for (pattern, importance) in locationPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(lowercased.startIndex..., in: lowercased)
                if let match = regex.firstMatch(in: lowercased, range: range) {
                    if let range = Range(match.range(at: 1), in: lowercased) {
                        let location = String(lowercased[range])
                        facts.append((.location, "location: \(location)", importance))
                    } else if match.numberOfRanges == 1 {
                        if let range = Range(match.range, in: lowercased) {
                            let location = String(lowercased[range])
                            facts.append((.location, "location: \(location)", importance))
                        }
                    }
                }
            }
        }
        
        // Condition patterns
        let conditionPatterns: [(String, Float)] = [
            ("(broken|fractured) ([a-z]+)", 1.5),
            ("bleeding from ([a-z]+)", 1.5),
            ("(injured|hurt) ([a-z]+)", 1.3),
            ("can't (breathe|move|walk|see)", 1.8),
            ("(hypothermia|frostbite|heat stroke|dehydration)", 1.5)
        ]
        
        for (pattern, importance) in conditionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(lowercased.startIndex..., in: lowercased)
                if let match = regex.firstMatch(in: lowercased, range: range) {
                    if let range = Range(match.range, in: lowercased) {
                        let condition = String(lowercased[range])
                        facts.append((.condition, "condition: \(condition)", importance))
                    }
                }
            }
        }
        
        // Resource patterns
        let resourcePatterns: [(String, Float)] = [
            ("have ([a-z]+)", 0.8),
            ("got ([a-z]+)", 0.8),
            ("no (water|food|phone|signal|shelter)", 1.2),
            ("found ([a-z]+)", 0.9)
        ]
        
        for (pattern, importance) in resourcePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(lowercased.startIndex..., in: lowercased)
                if let match = regex.firstMatch(in: lowercased, range: range) {
                    if let range = Range(match.range(at: 1), in: lowercased) {
                        let resource = String(lowercased[range])
                        facts.append((.resource, "resource: \(resource)", importance))
                    }
                }
            }
        }
        
        // Environment patterns
        let environmentPatterns: [(String, Float)] = [
            ("(snowing|raining|hot|cold|windy|dark)", 1.0),
            ("getting (dark|cold|hot|late)", 1.1),
            ("(night|day|morning|evening|afternoon)", 0.7)
        ]
        
        for (pattern, importance) in environmentPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let range = NSRange(lowercased.startIndex..., in: lowercased)
                if let match = regex.firstMatch(in: lowercased, range: range) {
                    if let range = Range(match.range, in: lowercased) {
                        let environment = String(lowercased[range])
                        facts.append((.environment, "environment: \(environment)", importance))
                    }
                }
            }
        }
        
        return facts
    }
    
    /// Store a semantic fact
    private func storeFact(factType: SemanticFact.FactType, factText: String, sessionId: String, sourceMessageId: Int?, importance: Float) {
        let sql = """
            INSERT INTO semantic_memory (session_id, fact_type, fact_text, source_message_id, extracted_at, importance)
            VALUES (?, ?, ?, ?, ?, ?)
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return
        }
        
        defer { sqlite3_finalize(statement) }
        
        let now = Int(Date().timeIntervalSince1970)
        
        sqlite3_bind_text(statement, 1, (sessionId as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 2, (factType.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_text(statement, 3, (factText as NSString).utf8String, -1, nil)
        
        if let msgId = sourceMessageId {
            sqlite3_bind_int(statement, 4, Int32(msgId))
        } else {
            sqlite3_bind_null(statement, 4)
        }
        
        sqlite3_bind_int64(statement, 5, Int64(now))
        sqlite3_bind_double(statement, 6, Double(importance))
        
        sqlite3_step(statement)
    }
    
    /// Retrieve relevant memories for a query
    func retrieveRelevantMemories(for query: String, sessionId: String? = nil, limit: Int = 3) -> [SemanticFact] {
        let sid = sessionId ?? getCurrentSessionId()
        var facts: [SemanticFact] = []
        
        // Simple keyword-based retrieval for now
        // In production, use embeddings for semantic search
        let sql = """
            SELECT id, session_id, fact_type, fact_text, source_message_id, extracted_at, importance
            FROM semantic_memory
            WHERE session_id = ?
            ORDER BY importance DESC, extracted_at DESC
            LIMIT ?
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            return facts
        }
        
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_text(statement, 1, (sid as NSString).utf8String, -1, nil)
        sqlite3_bind_int(statement, 2, Int32(limit))
        
        while sqlite3_step(statement) == SQLITE_ROW {
            let id = Int(sqlite3_column_int(statement, 0))
            let sessionId = String(cString: sqlite3_column_text(statement, 1))
            let factTypeStr = String(cString: sqlite3_column_text(statement, 2))
            let factText = String(cString: sqlite3_column_text(statement, 3))
            
            let sourceMessageId = sqlite3_column_type(statement, 4) != SQLITE_NULL ?
                Int(sqlite3_column_int(statement, 4)) : nil
            
            let extractedAt = Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(statement, 5)))
            let importance = Float(sqlite3_column_double(statement, 6))
            
            if let factType = SemanticFact.FactType(rawValue: factTypeStr) {
                facts.append(SemanticFact(
                    id: id,
                    sessionId: sessionId,
                    factType: factType,
                    factText: factText,
                    sourceMessageId: sourceMessageId,
                    extractedAt: extractedAt,
                    importance: importance,
                    embedding: []
                ))
            }
        }
        
        return facts
    }
    
    // MARK: - Memory Management
    
    /// Clear all memories for the current session
    func clearCurrentSession() -> Bool {
        guard let sessionId = currentSessionId else { return false }
        return clearSession(sessionId)
    }
    
    /// Clear all memories for a specific session
    func clearSession(_ sessionId: String) -> Bool {
        let sqls = [
            "DELETE FROM semantic_memory WHERE session_id = ?",
            "DELETE FROM conversations WHERE session_id = ?",
            "DELETE FROM sessions WHERE session_id = ?"
        ]
        
        for sql in sqls {
            var statement: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
                sqlite3_bind_text(statement, 1, (sessionId as NSString).utf8String, -1, nil)
                sqlite3_step(statement)
            }
            sqlite3_finalize(statement)
        }
        
        return true
    }
    
    /// Clear all memories across all sessions
    func clearAllMemories() -> Bool {
        let sqls = [
            "DELETE FROM semantic_memory",
            "DELETE FROM conversations",
            "DELETE FROM sessions"
        ]
        
        for sql in sqls {
            if sqlite3_exec(db, sql, nil, nil, nil) != SQLITE_OK {
                return false
            }
        }
        
        createNewSession()
        return true
    }
    
    /// Get memory statistics
    func getMemoryStats() -> (conversationCount: Int, factCount: Int, sessionCount: Int) {
        var convCount = 0
        var factCount = 0
        var sessCount = 0
        
        // Get conversation count
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM conversations", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                convCount = Int(sqlite3_column_int(statement, 0))
            }
            sqlite3_finalize(statement)
        }
        
        // Get fact count
        statement = nil
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM semantic_memory", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                factCount = Int(sqlite3_column_int(statement, 0))
            }
            sqlite3_finalize(statement)
        }
        
        // Get session count
        statement = nil
        if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM sessions", -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_ROW {
                sessCount = Int(sqlite3_column_int(statement, 0))
            }
            sqlite3_finalize(statement)
        }
        
        return (convCount, factCount, sessCount)
    }
}
