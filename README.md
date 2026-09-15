# Speech to Clip

**Privacy-first speech-to-text for macOS.** Transcribe your voice with AI-powered accuracy—choose between **100% local processing** (private, offline) or **cloud API** (convenient, fast). Your data, your choice.

![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%2014.0+-lightgrey.svg)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

## 🔥 Dual Transcription Engines

Speech to Clip supports **two powerful transcription options**—pick what matters most to you:

### 🔒 Local Whisper (Privacy-First)
- ✅ **100% Private** - Audio never leaves your Mac
- ✅ **Completely Offline** - No internet required
- ✅ **Zero Cost** - Free after setup (no API fees)
- ✅ **Fast on Apple Silicon** - Optimized for M1/M2/M3/M4
- ✅ **Open Source & Auditable** - Verify privacy yourself

[📚 Setup Guide](docs/local-whisper-setup.md) • [🔐 Privacy Guarantees](docs/privacy-guarantees.md)

### ☁️ OpenAI API (Cloud-Based)
- ⚡ **Maximum Accuracy** - Best-in-class transcription quality
- 🌐 **Convenient** - Just add API key and go
- 🚀 **Fast Setup** - No local installation needed
- 💰 **Pay-per-use** - $0.006 per minute

**Switch between engines anytime** using profiles—perfect for different scenarios.

## ✨ Core Features

- 🎤 **Voice Recording** - Press a hotkey (default: Control+Space) to start/stop recording
- 🎙️ **Meeting Transcription** - Live local transcript of Teams, Google Meet and Slack huddle meetings, saved to a file
- 🌊 **Wave Visualizer** - Floating wave animation on screen edge that responds to your voice amplitude
- ✨ **AI Proofreading** - Optional GPT-4o-mini powered spelling, punctuation, and capitalization correction
- 🌐 **Translation Mode** - Translate speech to English from any supported language
- 📋 **Smart Auto-Paste** - Intelligently pastes text with seamless clipboard fallback
- 💚 **Custom Menubar Icon** - Elegant S-curve waveform that turns lime green when recording
- ⚙️ **Multiple Profiles** - Create profiles for different engines, languages, and use cases
- 🔐 **Secure Storage** - API keys stored safely in macOS Keychain
- 🚀 **Guided Onboarding** - First-time setup with permission checks
- 💬 **Helpful Errors** - Clear, actionable error messages with recovery steps

## Why Speech to Clip?

**Most speech-to-text tools force you to choose:** either sacrifice your privacy by sending audio to the cloud, or deal with complicated local setups. Speech to Clip gives you **both options** with a beautiful, simple interface.

- **Privacy-conscious users** → Use Local Whisper for guaranteed data privacy
- **Convenience-focused users** → Use OpenAI API for instant setup
- **Hybrid workflows** → Switch between engines with different profiles

Built with ❤️ for people who care about their data and productivity.

## Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.0 or later (for building from source)
- **OpenAI API Key**: Required for transcription ([Get one here](https://platform.openai.com/api-keys))
- **Permissions**:
  - Microphone access (for recording)
  - Accessibility access (for auto-paste)

## Installation

### Option 1: Build from Source

1. **Clone the repository**
   ```bash
   git clone https://github.com/Latentti/speech-to-clip.git
   cd speech-to-clip/speech-to-clip
   ```

2. **Open in Xcode**
   ```bash
   open speech-to-clip.xcodeproj
   ```

3. **Build and run**
   - Select the `Speech to Clip` scheme
   - Click Run (⌘R) or Product → Run
   - The app will appear in your menu bar

### Option 2: Download Pre-built Binary

*Coming soon - Check the [Releases](https://github.com/Latentti/speech-to-clip/releases) page*

## Quick Start

### First Launch

1. **Launch the app** - It will appear as an icon in your menu bar
2. **Complete onboarding**:
   - Grant microphone permission
   - Grant accessibility permission
   - Add your OpenAI API key in Settings
3. **Try your first recording**:
   - Click anywhere in a text field
   - Press `Control+Space` to start recording
   - Speak clearly - watch the wave visualizer respond to your voice
   - Press `Control+Space` again to stop
   - Wait for transcription (wave continues during processing)
   - Text appears automatically in your active field!

### Local Whisper Setup (Optional)

For privacy-first, offline transcription without sending audio to external servers:

📚 **[Local Whisper Setup Guide](docs/local-whisper-setup.md)** - Complete walkthrough for installing whisper.cpp and configuring local transcription

**Benefits:**
- 🔒 Audio never leaves your Mac
- ✅ Works completely offline
- 💰 Free (no API costs)
- ⚡ Fast on Apple Silicon

### Configuration

Click the menu bar icon → **Settings** to configure:

- **General Tab**:
  - Language selection (55+ languages supported)
  - Translation mode (translate any language to English)
  - Launch at login
  - Notification preferences

- **Hotkey Tab**:
  - Customize your recording hotkey
  - Default: Control+Space
  - Supports: Command, Option, Control, Shift combinations

- **Proofreading Tab**:
  - Enable/disable AI proofreading
  - Select OpenAI profile for proofreading API key
  - Uses GPT-4o-mini for fast, accurate corrections

- **Profiles Tab**:
  - Create multiple profiles with different:
    - Transcription engine (OpenAI API or Local Whisper)
    - API keys (useful for team accounts)
    - Language settings
    - Custom configurations
  - Switch profiles on the fly

- **About Tab**:
  - View application version
  - MIT License information
  - Author credits and GitHub repository link

## Usage

### Basic Recording Flow

1. **Focus** on any text input field (TextEdit, Slack, email, etc.)
2. **Press hotkey** (`Control+Space`) to start recording
3. **Speak** your message - watch the wave visualizer respond to your voice
4. **Press hotkey** again to stop recording
5. **Wait** for transcription (usually 1-3 seconds) - wave continues animating
6. **Done** - text is copied to clipboard and automatically pasted at your cursor

**Note:** The app uses intelligent paste detection:
- Text is **always copied to clipboard** as a fallback
- Auto-paste attempts to paste automatically in supported applications
- If auto-paste doesn't work, simply press `⌘V` to paste manually
- No error messages for paste failures - clipboard fallback is seamless

### Tips for Best Results

- **Speak clearly** and at a normal pace
- **Minimize background noise** for better accuracy
- **Use correct language** - set it in Settings → General
- **Check your internet** - transcription requires an active connection
- **Watch the visualizer** - amplitude feedback shows recording is working

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Control+Space` | Start/Stop Recording (customizable) |
| `⌘,` | Open Settings |
| `⌘Q` | Quit Application |

## 🎙️ Meeting Transcription

Transcribe Teams, Google Meet and Slack huddle meetings live with Local Whisper. Your microphone is labeled **Me** and everything the Mac plays (the other participants) **Others**.

1. Make sure a Local Whisper profile exists and the whisper.cpp server is running
2. Menu bar → **Start Meeting Transcription**
3. Follow the transcript in the **Meeting Transcript** window
4. Menu bar or window → **Stop Meeting Transcription**

Transcripts are saved to `~/Documents/Meetings/<yyyy-MM-dd_HHmm> <title>/transcript.md`. They are raw material for memo writing: words are kept as transcribed, and names, terms and proofreading are left to the memo step.

**How it works**
- System audio is captured with a Core Audio process tap (macOS 14.4+). macOS asks once for permission to record system audio; screen recording permission is not needed
- Audio is cut into speech chunks at pauses (at most 25 s) and silent chunks are skipped, so whisper does not invent text for silence
- Whisper segments with low confidence are dropped
- Every chunk is saved to `.pending/` before transcription; chunks left by a crash are transcribed on the next launch
- Microphone lines that repeat the other participants (speaker echo) are dropped
- When the meeting ends, fragments are joined into speaker turns in chronological order
- **Title**: added to the transcript heading and the folder name so that a memo project can find the meetings of one client
- **Settings → General → Meeting Transcription**: choose which Local Whisper profile meetings use

**Notes**
- The dictation hotkey is disabled during a meeting
- Transcripts are text only; audio is not kept
- With speakers, a one- or two-word interjection of your own that overlaps someone else may be dropped as echo

## Project Structure

```
speech-to-clip/
├── speech-to-clip/              # Main application
│   ├── App/                     # App lifecycle & entry point
│   │   └── AppDelegate.swift    # Menu bar setup & app initialization
│   ├── Models/                  # Data models
│   │   ├── AppSettings.swift    # App-level settings (hotkey, preferences)
│   │   ├── Profile.swift        # Profile model (language, API key per profile)
│   │   ├── HotkeyConfig.swift   # Hotkey configuration (Codable wrapper)
│   │   └── SpeechToClipError.swift  # Error types with user-friendly messages
│   ├── Core/                    # Core business logic
│   │   ├── Proofreading/        # AI proofreading
│   │   │   ├── ProofreadingService.swift  # GPT-4o-mini API client
│   │   │   └── ProofreadingError.swift    # Error types with recovery suggestions
│   │   └── Transcription/       # Speech-to-text
│   │       └── WhisperCppClient.swift     # Local Whisper client
│   ├── Services/                # Business logic services
│   │   ├── AudioRecorder.swift  # AVFoundation audio recording
│   │   ├── TranscriptionService.swift  # Whisper API integration
│   │   ├── ClipboardManager.swift  # Clipboard operations
│   │   ├── PasteService.swift   # Auto-paste with Accessibility API
│   │   ├── KeychainService.swift  # Secure API key storage
│   │   ├── ProfileManager.swift  # Profile CRUD operations
│   │   ├── SettingsService.swift  # Settings persistence & validation
│   │   └── PermissionService.swift  # Permission checks & requests
│   ├── Views/                   # SwiftUI views
│   │   ├── Visualizer/          # Wave visualizer
│   │   │   ├── VisualizerWindow.swift
│   │   │   ├── VisualizerContentView.swift
│   │   │   ├── WaveVisualizerView.swift
│   │   │   └── WaveRenderer.swift
│   │   ├── Settings/            # Settings window
│   │   │   ├── SettingsWindow.swift
│   │   │   ├── GeneralTab.swift
│   │   │   ├── HotkeyTab.swift
│   │   │   ├── ProfilesTab.swift
│   │   │   └── AboutTab.swift
│   │   └── Onboarding/          # First-run onboarding
│   │       ├── OnboardingWindow.swift
│   │       ├── WelcomeView.swift
│   │       ├── PermissionsView.swift
│   │       ├── APIKeyView.swift
│   │       └── TutorialView.swift
│   ├── State/                   # Global app state
│   │   └── AppState.swift       # @Observable state container
│   └── Helpers/                 # Utility code
│       ├── AlertHelper.swift    # User-facing alerts
│       └── WhisperLanguage.swift  # Language enum (55+ languages)
├── speech-to-clipTests/         # Unit & integration tests
│   ├── ServicesTests/           # Service layer tests
│   ├── ModelsTests/             # Model tests
│   ├── FeatureTests/            # Feature integration tests
│   └── HelpersTests/            # Helper utility tests
└── speech-to-clipUITests/       # UI tests (basic)
```

## Architecture

### Design Patterns

- **MVVM** (Model-View-ViewModel) - SwiftUI views with observable state
- **Service Layer** - Business logic separated from UI
- **Dependency Injection** - Services injected into AppState
- **Observer Pattern** - Swift's `@Observable` for reactive state
- **Repository Pattern** - ProfileManager, SettingsService for data access

### Key Components

**AppState** - Central state container holding:
- Current recording status
- Active profile
- Settings configuration
- All service instances

**Services** - Independent, testable business logic:
- `AudioRecorder` - Manages AVAudioEngine recording with amplitude detection
- `TranscriptionService` - Whisper API client with audio format conversion
- `ProofreadingService` - GPT-4o-mini text correction (spelling, punctuation, capitalization)
- `PasteService` - Accessibility API for programmatic paste
- `KeychainService` - Secure credential storage
- `PermissionService` - Runtime permission checks

**Visualizer** - Wave animation:
- Custom AppKit NSWindow for floating overlay (50px × full screen height)
- Canvas-based wave rendering at 60fps
- Real-time amplitude → wave intensity mapping
- Smooth fade in/out transitions

### Data Flow

```
User presses hotkey
    ↓
AppState toggles recording
    ↓
AudioRecorder starts/stops AVAudioEngine
    ↓ (amplitude data)
WaveRenderer adjusts visualizer intensity (green wave)
    ↓ (on stop)
AudioRecorder saves .m4a file
    ↓
TranscriptionService converts to MP3 & sends to Whisper API
    ↓ (yellow wave during processing)
API returns transcribed text
    ↓
ProofreadingService corrects text via GPT-4o-mini (if enabled)
    ↓ (orange wave during proofreading)
ClipboardManager copies to clipboard
    ↓
PasteService simulates Cmd+V in active app
```

## Development

### Prerequisites

- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- Swift 5.9+

### Dependencies

Managed via Swift Package Manager:

- [HotKey](https://github.com/soffes/HotKey) - Global hotkey registration
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) - Keychain wrapper

### Building

```bash
# Clone the repository
git clone https://github.com/Latentti/speech-to-clip.git
cd speech-to-clip/speech-to-clip

# Open in Xcode
open speech-to-clip.xcodeproj

# Build (⌘B)
# Run (⌘R)
```

### Running Tests

```bash
# Run all tests in Xcode (⌘U)

# Or via command line:
xcodebuild test \
  -scheme "Speech to Clip" \
  -sdk macosx \
  -destination 'platform=macOS'
```

**Test Coverage**:
- ✅ Unit tests for all services
- ✅ Model validation tests
- ✅ Settings persistence tests
- ✅ Error message quality tests
- ✅ Keychain integration tests
- ✅ Profile management tests

### Project Configuration

**Info.plist Permissions**:
- `NSMicrophoneUsageDescription` - Required for audio recording
- `NSAppleEventsUsageDescription` - Required for auto-paste

**Build Settings**:
- Minimum Deployment: macOS 14.0
- Swift Language Version: 5.9
- Code Signing: Development team required

## Troubleshooting

### Common Issues

**"No API key configured"**
- Solution: Open Settings → Profiles → Add your OpenAI API key

**"Microphone permission denied"**
- Solution: Open System Settings → Privacy & Security → Microphone → Enable for Speech to Clip

**"Auto-paste not working in some applications"**
- Solution: Text is automatically copied to clipboard - just press `⌘V` to paste manually
- Note: Some applications (like Microsoft Outlook) don't support programmatic paste
- The app intelligently detects text fields in most apps (browsers, terminals, code editors, chat apps)
- Accessibility permission is required for auto-paste: System Settings → Privacy & Security → Accessibility

**"Network error"**
- Solution: Check your internet connection and try again

**"Recording not starting"**
- Check microphone permission granted
- Try clicking the menu bar icon → Test Recording
- Check Console.app for error logs

**"Hotkey not working"**
- Check Settings → Hotkey tab for conflicts
- Try a different key combination
- Restart the app

### Debug Logs

The app logs to the macOS Console. To view:

1. Open **Console.app**
2. Select your Mac in the sidebar
3. Search for `speech-to-clip`
4. Filter by category: `com.latentti.speech-to-clip`

Log levels:
- ✅ Info - Normal operations
- ⚠️ Warning - Recoverable issues
- ❌ Error - Failures requiring attention

## Roadmap

**Completed:**
- [x] Multi-language translation support (v0.2.0)
- [x] Offline mode with Local Whisper (v0.3.0)
- [x] AI Proofreading with GPT-4o-mini (v0.3.2)
- [x] Meeting transcription with Local Whisper (v0.4.0)

**Potential future enhancements:**
- [ ] Transcription history with searchable archive
- [ ] Audio editing before transcription
- [ ] Batch file transcription
- [ ] Custom Whisper prompt templates
- [ ] Alternative AI providers (AssemblyAI, Deepgram)
- [ ] Advanced voice activity detection

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Guidelines

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Write tests for new functionality
4. Ensure all tests pass (`⌘U` in Xcode)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

**Created by:** Latentti Oy

**UI Visualization Design:** Janne Passi

## Acknowledgments

- [OpenAI Whisper](https://openai.com/research/whisper) - Automatic speech recognition
- [HotKey](https://github.com/soffes/HotKey) - Global hotkey registration library
- [KeychainAccess](https://github.com/kishikawakatsumi/KeychainAccess) - Keychain wrapper

## Support

- **Issues**: [GitHub Issues](https://github.com/Latentti/speech-to-clip/issues)
- **Email**: ari.hietamaki@latentti.fi

---

Made with ❤️ for productivity enthusiasts
