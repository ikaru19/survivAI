import SwiftUI

struct ChatBubble: Shape {
    var isFromUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let cornerRadius: CGFloat = 16
        var path = Path()
        
        // Define corner radii based on whether message is from user
        let topLeftRadius = cornerRadius
        let topRightRadius = cornerRadius
        let bottomLeftRadius = isFromUser ? cornerRadius : 2
        let bottomRightRadius = isFromUser ? 2 : cornerRadius
        
        // Start from top left
        path.move(to: CGPoint(x: rect.minX + topLeftRadius, y: rect.minY))
        
        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - topRightRadius, y: rect.minY))
        
        // Top right corner
        path.addArc(
            center: CGPoint(x: rect.maxX - topRightRadius, y: rect.minY + topRightRadius),
            radius: topRightRadius,
            startAngle: Angle(degrees: -90),
            endAngle: Angle(degrees: 0),
            clockwise: false
        )
        
        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRightRadius))
        
        // Bottom right corner
        path.addArc(
            center: CGPoint(x: rect.maxX - bottomRightRadius, y: rect.maxY - bottomRightRadius),
            radius: bottomRightRadius,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + bottomLeftRadius, y: rect.maxY))
        
        // Bottom left corner
        path.addArc(
            center: CGPoint(x: rect.minX + bottomLeftRadius, y: rect.maxY - bottomLeftRadius),
            radius: bottomLeftRadius,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )
        
        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeftRadius))
        
        // Top left corner
        path.addArc(
            center: CGPoint(x: rect.minX + topLeftRadius, y: rect.minY + topLeftRadius),
            radius: topLeftRadius,
            startAngle: Angle(degrees: 180),
            endAngle: Angle(degrees: 270),
            clockwise: false
        )
        
        path.closeSubpath()
        
        return path
    }
} 