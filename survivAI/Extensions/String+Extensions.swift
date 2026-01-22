import Foundation

extension String {
    func hasPrefix(_ prefix: String) -> Bool {
        return self.starts(with: prefix)
    }
    
    var isNotEmpty: Bool {
        return !self.isEmpty
    }
    
    func trimmed() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 