# TimeTracker Voice - Native iOS

A native iOS voice assistant for task management, built with Swift and SwiftUI. Features ChatGPT-like full-duplex voice conversation powered by OpenAI's Realtime API.

## Features

- 🎙️ **Real-time voice streaming** - Ultra-low latency with AVAudioEngine
- 🔊 **Full duplex audio** - Talk and listen simultaneously
- ⚡ **Instant response** - Server-side VAD detects when you stop speaking
- 📱 **Background support** - Voice continues in background
- 🎯 **Native experience** - Built with SwiftUI for iOS 17+

## What You Can Do

- Ask about your schedule ("What do I have today?")
- Create tasks ("Add gym tomorrow at 7am")
- Update tasks ("Mark today's meeting as done")
- Delete tasks ("Remove the dentist appointment")

## Requirements

- iOS 17.0+
- Xcode 15.0+
- OpenAI API key with Realtime API access
- Supabase account (same as web app)

## Setup

### 1. Install XcodeGen (if not installed)

```bash
brew install xcodegen
```

### 2. Generate Xcode Project

```bash
cd TimeTracker-iOS
xcodegen generate
```

### 3. Open in Xcode

```bash
open TimeTrackerVoice.xcodeproj
```

### 4. Configure Signing

1. Select the project in Xcode
2. Go to "Signing & Capabilities"
3. Select your Team
4. Enable "Automatically manage signing"

### 5. Add OpenAI API Key

When you first run the app, it will prompt for your OpenAI API key.
You can also set it programmatically in `Config.swift`.

### 6. Run

1. Select your device or simulator
2. Press Cmd + R

## Project Structure

```
TimeTrackerVoice/
├── App/
│   ├── TimeTrackerVoiceApp.swift  # App entry point
│   └── Config.swift               # Configuration
├── Views/
│   ├── VoiceView.swift            # Main voice interface
│   ├── VoiceOrbView.swift         # Animated orb
│   └── AuthView.swift             # Login screen
├── Services/
│   ├── AudioStreamManager.swift   # AVAudioEngine streaming
│   ├── RealtimeAPIClient.swift    # OpenAI WebSocket
│   ├── AuthManager.swift          # Supabase auth
│   └── TaskManager.swift          # Task CRUD
├── Models/
│   ├── Task.swift                 # Data models
│   └── VoiceState.swift           # Voice states
└── Resources/
    └── Info.plist                 # App configuration
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      SwiftUI Views                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  VoiceView ──────► VoiceOrbView                             │
│      │                                                       │
│      ▼                                                       │
│  RealtimeAPIClient ◄────────► AudioStreamManager            │
│      │                              │                        │
│      │                              ▼                        │
│      │                        AVAudioEngine                  │
│      │                        (Real-time I/O)                │
│      │                                                       │
│      ▼                                                       │
│  OpenAI Realtime API ◄──── WebSocket ────► Function Calls   │
│                                                  │           │
│                                                  ▼           │
│  TaskManager ◄────────────────────────────── Supabase       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Key Technologies

| Component | Technology |
|-----------|------------|
| UI | SwiftUI |
| Audio | AVAudioEngine |
| Networking | URLSession WebSocket |
| Backend | Supabase |
| AI | OpenAI Realtime API |

## Compared to React Native

| Feature | React Native | Native iOS |
|---------|--------------|------------|
| Audio latency | 200-500ms | ~20-50ms |
| Full duplex | Limited | Native support |
| Background audio | Very limited | Full support |
| Battery | Poor | Excellent |
| App size | ~50MB | ~5MB |

## Related Projects

- [TimeTracker Web](../Personal%20Management%20Time) - Web app
- [TimeTracker Voice (RN)](../TimeTracker-Voice) - React Native version

## License

MIT

