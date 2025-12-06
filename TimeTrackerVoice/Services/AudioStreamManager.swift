import Foundation
import AVFoundation
import Combine

/// Manages real-time audio streaming using AVAudioEngine
/// This provides ultra-low latency audio capture and playback for full-duplex voice conversation
class AudioStreamManager: ObservableObject {
    static let shared = AudioStreamManager()
    
    // Audio Engine
    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    
    // Audio Format - OpenAI expects 24kHz, 16-bit PCM mono
    private let sampleRate: Double = 24000
    private let channels: UInt32 = 1
    
    // State
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var audioLevel: Float = 0
    
    // Callbacks
    var onAudioChunk: ((Data) -> Void)?
    
    // Audio queue for playback
    private var audioQueue: [Data] = []
    private var isProcessingQueue = false
    
    private init() {
        setupAudioSession()
        setupAudioEngine()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            
            // PlayAndRecord allows simultaneous input and output (full duplex)
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [
                .defaultToSpeaker,
                .allowBluetooth,
                .allowBluetoothA2DP,
                .mixWithOthers
            ])
            
            // Set preferred sample rate
            try session.setPreferredSampleRate(sampleRate)
            try session.setPreferredIOBufferDuration(0.005) // 5ms buffer for low latency
            
            try session.setActive(true)
            
            print("✅ Audio session configured for full-duplex")
        } catch {
            print("❌ Failed to setup audio session: \(error)")
        }
    }
    
    private func setupAudioEngine() {
        // Add player node for audio playback
        audioEngine.attach(playerNode)
        
        // Connect player to main mixer
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
        
        print("✅ Audio engine configured")
    }
    
    // MARK: - Recording (Microphone Input)
    
    func startRecording() {
        guard !isRecording else { return }
        
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Create converter to convert from device format to our target format
        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                         sampleRate: sampleRate,
                                         channels: channels,
                                         interleaved: true)!
        
        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            print("❌ Failed to create audio converter")
            return
        }
        
        // Install tap on input node to receive audio chunks
        inputNode.installTap(onBus: 0, bufferSize: 2400, format: inputFormat) { [weak self] buffer, time in
            guard let self = self else { return }
            
            // Calculate audio level for UI
            self.calculateAudioLevel(buffer: buffer)
            
            // Convert to our target format
            let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * self.sampleRate / inputFormat.sampleRate)
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else { return }
            
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }
            
            converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
            
            if let error = error {
                print("❌ Conversion error: \(error)")
                return
            }
            
            // Convert buffer to Data
            if let data = self.bufferToData(outputBuffer) {
                // Send to callback (which will send to WebSocket)
                DispatchQueue.main.async {
                    self.onAudioChunk?(data)
                }
            }
        }
        
        // Start the engine
        do {
            try audioEngine.start()
            isRecording = true
            print("🎙️ Recording started")
        } catch {
            print("❌ Failed to start audio engine: \(error)")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        audioEngine.inputNode.removeTap(onBus: 0)
        
        if !isPlaying {
            audioEngine.stop()
        }
        
        isRecording = false
        audioLevel = 0
        print("🛑 Recording stopped")
    }
    
    // MARK: - Playback (Speaker Output)
    
    /// Queue audio data for playback
    func queueAudio(_ data: Data) {
        audioQueue.append(data)
        processAudioQueue()
    }
    
    /// Clear audio queue (for interruption)
    func clearAudioQueue() {
        audioQueue.removeAll()
        playerNode.stop()
        isPlaying = false
    }
    
    private func processAudioQueue() {
        guard !isProcessingQueue, !audioQueue.isEmpty else { return }
        
        isProcessingQueue = true
        isPlaying = true
        
        // Ensure engine is running
        if !audioEngine.isRunning {
            do {
                try audioEngine.start()
            } catch {
                print("❌ Failed to start audio engine for playback: \(error)")
                isProcessingQueue = false
                return
            }
        }
        
        // Process all queued audio
        while !audioQueue.isEmpty {
            let data = audioQueue.removeFirst()
            
            if let buffer = dataToBuffer(data) {
                playerNode.scheduleBuffer(buffer)
            }
        }
        
        // Start playing if not already
        if !playerNode.isPlaying {
            playerNode.play()
        }
        
        isProcessingQueue = false
        
        // Check for more audio after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            if self?.audioQueue.isEmpty == true && self?.playerNode.isPlaying == false {
                self?.isPlaying = false
            } else if self?.audioQueue.isEmpty == false {
                self?.processAudioQueue()
            }
        }
    }
    
    // MARK: - Helpers
    
    private func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let int16Data = buffer.int16ChannelData else { return nil }
        
        let frameLength = Int(buffer.frameLength)
        let data = Data(bytes: int16Data[0], count: frameLength * 2) // 2 bytes per sample
        
        return data
    }
    
    private func dataToBuffer(_ data: Data) -> AVAudioPCMBuffer? {
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                   sampleRate: sampleRate,
                                   channels: channels,
                                   interleaved: true)!
        
        let frameCount = AVAudioFrameCount(data.count / 2) // 2 bytes per sample
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        data.withUnsafeBytes { rawBufferPointer in
            if let baseAddress = rawBufferPointer.baseAddress {
                memcpy(buffer.int16ChannelData![0], baseAddress, data.count)
            }
        }
        
        // Convert to float format for player node
        let floatFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: channels)!
        guard let floatBuffer = AVAudioPCMBuffer(pcmFormat: floatFormat, frameCapacity: frameCount),
              let converter = AVAudioConverter(from: format, to: floatFormat) else {
            return nil
        }
        
        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        converter.convert(to: floatBuffer, error: &error, withInputFrom: inputBlock)
        
        return floatBuffer
    }
    
    private func calculateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        
        let frameLength = Int(buffer.frameLength)
        var sum: Float = 0
        
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frameLength)
        
        DispatchQueue.main.async {
            self.audioLevel = min(average * 10, 1.0) // Normalize to 0-1
        }
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        stopRecording()
        clearAudioQueue()
        audioEngine.stop()
    }
}

