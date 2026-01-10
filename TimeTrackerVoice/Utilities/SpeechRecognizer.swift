import Foundation
import Speech
import AVFoundation

/// Speech-to-text recognizer using Apple Speech Framework
@MainActor
class SpeechRecognizer: ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var isAvailable = false
    @Published var error: String?
    
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private let audioEngine = AVAudioEngine()
    
    // Use Hebrew recognizer, fallback to device locale
    private let speechRecognizer: SFSpeechRecognizer? = {
        // Try Hebrew first
        if let hebrew = SFSpeechRecognizer(locale: Locale(identifier: "he-IL")), hebrew.isAvailable {
            return hebrew
        }
        // Fallback to device locale
        return SFSpeechRecognizer()
    }()
    
    init() {
        checkPermissions()
    }
    
    // MARK: - Permissions
    
    private func checkPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                switch status {
                case .authorized:
                    self?.isAvailable = self?.speechRecognizer?.isAvailable ?? false
                    print("🎤 Speech recognition authorized")
                case .denied:
                    self?.error = "Speech recognition denied"
                    self?.isAvailable = false
                case .restricted:
                    self?.error = "Speech recognition restricted"
                    self?.isAvailable = false
                case .notDetermined:
                    self?.isAvailable = false
                @unknown default:
                    self?.isAvailable = false
                }
            }
        }
    }
    
    // MARK: - Recording
    
    func startRecording() {
        guard !isRecording else { return }
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            error = "Speech recognition not available"
            return
        }
        
        // Reset state
        transcript = ""
        error = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            self.error = "Audio session error: \(error.localizedDescription)"
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            error = "Unable to create recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.taskHint = .dictation
        
        // Get the audio input node
        let inputNode = audioEngine.inputNode
        
        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.transcript = result.bestTranscription.formattedString
                }
                
                if let error = error {
                    print("❌ Recognition error: \(error.localizedDescription)")
                    // Don't show error for normal end of speech
                    if (error as NSError).code != 203 && (error as NSError).code != 216 {
                        self?.error = error.localizedDescription
                    }
                }
            }
        }
        
        // Configure audio input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            print("🎤 Recording started")
        } catch {
            self.error = "Audio engine error: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
        print("🎤 Recording stopped")
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("⚠️ Error deactivating audio session: \(error)")
        }
    }
    
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
}
