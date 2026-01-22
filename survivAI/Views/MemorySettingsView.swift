import SwiftUI

/// View for displaying and managing AI memory
struct MemorySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var memoryStats: (conversations: Int, facts: Int, sessions: Int) = (0, 0, 0)
    @State private var showClearAlert = false
    @State private var showClearSessionAlert = false
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    
    var body: some View {
        NavigationView {
            List {
                // Memory Statistics Section
                Section(header: Text("Memory Statistics")) {
                    HStack {
                        Text("Conversations")
                        Spacer()
                        Text("\(memoryStats.conversations)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Extracted Facts")
                        Spacer()
                        Text("\(memoryStats.facts)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Active Sessions")
                        Spacer()
                        Text("\(memoryStats.sessions)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Memory Content Section
                Section(header: Text("Stored Memories")) {
                    NavigationLink(destination: StoredMemoriesView()) {
                        Label("View All Memories", systemImage: "brain")
                    }
                }
                
                // Memory Actions Section
                Section(header: Text("Memory Management")) {
                    Button(action: {
                        showClearSessionAlert = true
                    }) {
                        Label("Clear Current Session", systemImage: "trash")
                            .foregroundColor(.orange)
                    }
                    .alert("Clear Current Session?", isPresented: $showClearSessionAlert) {
                        Button("Cancel", role: .cancel) {}
                        Button("Clear", role: .destructive) {
                            clearCurrentSession()
                        }
                    } message: {
                        Text("This will remove all memories from the current session. This action cannot be undone.")
                    }
                    
                    Button(action: {
                        showClearAlert = true
                    }) {
                        Label("Clear All Memories", systemImage: "trash.fill")
                            .foregroundColor(.red)
                    }
                    .alert("Clear All Memories?", isPresented: $showClearAlert) {
                        Button("Cancel", role: .cancel) {}
                        Button("Clear All", role: .destructive) {
                            clearAllMemories()
                        }
                    } message: {
                        Text("This will permanently delete all stored memories, conversations, and sessions. This action cannot be undone.")
                    }
                }
                
                // Info Section
                Section(header: Text("About Memory")) {
                    Text("survivAI stores key facts from your conversations to provide better context in ongoing emergencies. Memories automatically expire after 48 hours.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("AI Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadStats()
            }
            .overlay(
                Group {
                    if showSuccessMessage {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text(successMessage)
                                    .font(.subheadline)
                            }
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(10)
                            .shadow(radius: 10)
                            .padding(.bottom, 20)
                        }
                        .transition(.move(edge: .bottom))
                        .animation(.easeInOut, value: showSuccessMessage)
                    }
                }
            )
        }
    }
    
    private func loadStats() {
        memoryStats = LLMService.shared.getMemoryStats()
    }
    
    private func clearCurrentSession() {
        if LLMService.shared.clearCurrentSession() {
            showSuccess("Current session cleared")
            loadStats()
        }
    }
    
    private func clearAllMemories() {
        if LLMService.shared.clearAllMemories() {
            showSuccess("All memories cleared")
            loadStats()
        }
    }
    
    private func showSuccess(_ message: String) {
        successMessage = message
        showSuccessMessage = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSuccessMessage = false
        }
    }
}

/// View to display all stored memories
struct StoredMemoriesView: View {
    @State private var memories: [SemanticFact] = []
    @State private var conversations: [ConversationMessage] = []
    @State private var selectedTab = 0
    
    var body: some View {
        VStack {
            Picker("View", selection: $selectedTab) {
                Text("Facts").tag(0)
                Text("Conversations").tag(1)
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            
            if selectedTab == 0 {
                factsView
            } else {
                conversationsView
            }
        }
        .navigationTitle("Stored Memories")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadMemories()
        }
    }
    
    private var factsView: some View {
        Group {
            if memories.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "brain")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No memories yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("The AI will extract and remember key facts from your conversations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(memories, id: \.id) { fact in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            factTypeIcon(fact.factType)
                            Text(fact.factType.rawValue.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(timeAgo(fact.extractedAt))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text(fact.factText)
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private var conversationsView: some View {
        Group {
            if conversations.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "message")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    Text("No conversations yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                List(conversations, id: \.id) { message in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: message.isUser ? "person.fill" : "brain")
                                .foregroundColor(message.isUser ? .blue : .green)
                                .font(.caption)
                            Text(message.isUser ? "You" : "AI")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(timeAgo(message.timestamp))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text(message.message)
                            .font(.body)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private func factTypeIcon(_ type: SemanticFact.FactType) -> some View {
        let icon: String
        let color: Color
        
        switch type {
        case .location:
            icon = "location.fill"
            color = .blue
        case .condition:
            icon = "heart.fill"
            color = .red
        case .resource:
            icon = "bag.fill"
            color = .orange
        case .environment:
            icon = "cloud.fill"
            color = .gray
        case .temporal:
            icon = "clock.fill"
            color = .purple
        }
        
        return Image(systemName: icon)
            .foregroundColor(color)
            .font(.caption)
    }
    
    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
    
    private func loadMemories() {
        // Note: This is a placeholder - we need to add methods to LLMService to retrieve these
        // For now, just showing empty state
        memories = []
        conversations = []
    }
}

struct MemorySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        MemorySettingsView()
    }
}
