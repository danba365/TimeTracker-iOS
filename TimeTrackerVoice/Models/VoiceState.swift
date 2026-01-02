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
            return L10n.tapToStart
        case .listening:
            return L10n.listening
        case .processing:
            return L10n.thinking
        case .speaking:
            return L10n.speaking
        case .error:
            return L10n.errorOccurred
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

