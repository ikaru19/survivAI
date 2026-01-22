import SwiftUI

struct AppHeader: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top header with app title and icon
            HStack {
                // Emergency cross icon
                Image(systemName: "tree.circle")
                    .foregroundColor(.white)
                    .font(.system(size: 24))
                    .padding(8)
                    .background(Color.red)
                    .clipShape(Circle())
                    .shadow(color: Color.red.opacity(0.3), radius: 5)
                
                // App title with slight glow effect
                Text("survivAI")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.red)
                    .shadow(color: Color.red.opacity(0.3), radius: 1)
                
                Spacer()
                
                // Info button for emergency tips
                Button(action: {
                    // Action for emergency tips (implement if needed)
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.red)
                        .font(.system(size: 22))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(
                Color.white
                    .shadow(color: Color.black.opacity(0.1), radius: 2, y: 2)
            )
            
            // Emergency status banner (only show in real emergencies)
            emergencyStatusBanner
        }
    }
    
    // Dynamic emergency banner - in a real app, this would show based on app state
    // For example, if user has indicated a life-threatening emergency
    private var emergencyStatusBanner: some View {
        // You can make this conditional based on app state
        // This is just a placeholder for demonstration
        let showEmergencyBanner = false
        
        return Group {
            if showEmergencyBanner {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                    Text("EMERGENCY MODE ACTIVE")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal)
                .background(Color.red)
            }
        }
    }
} 
