import SwiftUI
import Combine

/// Observes keyboard show/hide events and provides the current keyboard height
final class KeyboardObserver: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var isKeyboardVisible: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Keyboard will show
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .compactMap { notification -> CGFloat? in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height
            }
            .sink { [weak self] height in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.keyboardHeight = height
                    self?.isKeyboardVisible = true
                }
            }
            .store(in: &cancellables)
        
        // Keyboard will hide
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    self?.keyboardHeight = 0
                    self?.isKeyboardVisible = false
                }
            }
            .store(in: &cancellables)
    }
}

