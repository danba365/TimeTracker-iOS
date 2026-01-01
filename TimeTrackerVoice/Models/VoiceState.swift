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
            return "לחץ להתחיל / Tap to start"
        case .listening:
            return "מקשיב... / Listening..."
        case .processing:
            return "חושב... / Thinking..."
        case .speaking:
            return "מדבר... / Speaking..."
        case .error:
            return "אירעה שגיאה / Error occurred"
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

