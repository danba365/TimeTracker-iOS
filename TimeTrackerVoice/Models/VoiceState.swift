import Foundation

enum VoiceState {
    case idle
    case listening
    case processing
    case speaking
    case error
    
    var statusText: String {
        switch self {
        case .idle:
            return "Tap to start"
        case .listening:
            return "Listening..."
        case .processing:
            return "Thinking..."
        case .speaking:
            return "Speaking..."
        case .error:
            return "Error occurred"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .listening, .processing, .speaking:
            return true
        case .idle, .error:
            return false
        }
    }
}

