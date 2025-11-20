# Speech to Clip v0.3.0 - Local Whisper Integration

**Release Date:** November 19, 2025

## 🎉 Major New Feature: Local Whisper Integration

This release introduces **Local Whisper** - a privacy-first, offline transcription option that keeps your audio data completely on your Mac. No internet required, no API costs, and absolute privacy.

### 🔒 Privacy-First Transcription

**Local Whisper Mode** allows you to transcribe speech entirely offline using whisper.cpp running on your local machine:

- ✅ **100% Private** - Audio never leaves your Mac
- ✅ **Works Offline** - No internet connection required
- ✅ **Zero API Costs** - Completely free after setup
- ✅ **Fast on Apple Silicon** - Optimized for M1/M2/M3/M4 Macs
- ✅ **Open Source** - Fully auditable code with automated privacy tests

### 🆕 New Features

#### Dual Transcription Engines
- **Local Whisper** - Privacy-focused, offline transcription via whisper.cpp
- **OpenAI API** - Cloud-based transcription (existing feature)
- Switch between engines per profile based on your needs

#### Enhanced Profile System
- Profiles now support transcription engine selection
- Configure different engines for different use cases
- Each profile can have its own whisper.cpp port configuration
- Seamless switching between Local Whisper and OpenAI API

#### Comprehensive Error Handling
- User-friendly error messages with recovery suggestions
- Automatic retry capability for failed transcriptions
- Direct links to setup documentation in error dialogs
- Clear distinction between connection, timeout, and transcription errors

#### Privacy Verification
- Automated privacy tests enforce localhost-only connections
- No external network calls possible in Local Whisper mode
- Open-source code allows community audit
- Privacy guarantees documented and verifiable

### 📚 Documentation

New comprehensive documentation for Local Whisper:

- **[Setup Guide](docs/local-whisper-setup.md)** - Step-by-step installation instructions
- **[Architecture Document](docs/architecture-localwhisper.md)** - Technical implementation details
- **[Privacy Guarantees](docs/privacy-guarantees.md)** - Verifiable privacy claims and testing
- Updated README with Local Whisper feature overview

### 🛠️ Technical Improvements

- New `WhisperCppClient` actor for thread-safe localhost communication
- Robust error handling with `WhisperCppError` type
- Multipart form-data encoding for whisper.cpp API compatibility
- Health check endpoint for server availability detection
- Configurable timeouts (5s health check, 60s transcription)
- Profile validation and migration for new transcription engine field

### 🧪 Testing

- Comprehensive unit tests for WhisperCppClient
- MockURLProtocol-based network testing (no real network calls)
- Privacy verification tests (localhost-only validation)
- Profile serialization and migration tests
- Error handling and recovery tests

### 🐛 Bug Fixes

- Fixed GitHub repository URLs in README (changed from placeholder to actual repository)
- Improved profile switching to clear retry state
- Enhanced error message clarity and actionability

## 📦 Installation

### Option 1: Download DMG (Recommended)

1. Download `speech-to-clip-0.3.0.dmg`
2. Open the DMG file
3. Drag **Speech to Clip.app** to your Applications folder
4. Launch from Applications

### Option 2: Build from Source

```bash
git clone https://github.com/Latentti/speech-to-clip.git
cd speech-to-clip/speech-to-clip
open speech-to-clip.xcodeproj
# Build and run in Xcode (⌘R)
```

## 🚀 Getting Started with Local Whisper

### Quick Setup

1. **Install whisper.cpp:**
   ```bash
   git clone https://github.com/ggerganov/whisper.cpp.git
   cd whisper.cpp
   make
   bash ./models/download-ggml-model.sh base
   ```

2. **Start whisper.cpp server:**
   ```bash
   ./server -m models/ggml-base.bin --port 8080
   ```

3. **Configure Speech to Clip:**
   - Open Settings → Profiles
   - Create new profile or edit existing
   - Select "Local Whisper" as transcription engine
   - Set port to 8080 (or your custom port)
   - Save profile

4. **Start transcribing!**
   - Press `Control+Space` (or your custom hotkey)
   - Speak your message
   - Audio stays on your Mac, transcribed locally

For detailed setup instructions, see [Local Whisper Setup Guide](docs/local-whisper-setup.md).

## 🔐 Privacy Guarantees

When using Local Whisper mode:
- ❌ No audio data sent externally
- ❌ No transcription text sent externally
- ❌ No telemetry or analytics
- ❌ No API keys required
- ✅ All processing happens on localhost (127.0.0.1)
- ✅ Works completely offline
- ✅ Open source and auditable

[Read full privacy guarantees →](docs/privacy-guarantees.md)

## 📊 Comparison: Local vs Cloud

| Feature | Local Whisper | OpenAI API |
|---------|--------------|------------|
| **Privacy** | ✅ Audio stays local | ⚠️ Sent to OpenAI |
| **Offline** | ✅ Works offline | ❌ Internet required |
| **Cost** | ✅ Free | 💰 $0.006/minute |
| **Speed** | ⚡ Fast (Apple Silicon) | 🌐 Network dependent |
| **Setup** | ⚙️ Manual installation | ✅ Just add API key |
| **Accuracy** | ⭐⭐⭐⭐ Very good | ⭐⭐⭐⭐⭐ Excellent |

**Your data, your choice.** Use Local Whisper for privacy, OpenAI API for convenience.

## 🔄 Upgrade Notes

### From v0.2.x

- Existing profiles will continue to work with OpenAI API
- No breaking changes to existing functionality
- To use Local Whisper, create a new profile or update existing profile settings
- Profile format automatically migrated to include transcription engine field

### Configuration Changes

- Profiles now include `transcriptionEngine` field (defaults to "openai")
- Local Whisper profiles require `whisperCppPort` field (defaults to 8080)
- Profile validation ensures engine-specific requirements are met

## 📝 Requirements

- **macOS**: 14.0 (Sonoma) or later
- **For Local Whisper**:
  - whisper.cpp server running locally
  - Whisper model downloaded (base, medium, or large recommended)
  - Available port (default: 8080)
- **For OpenAI API**:
  - OpenAI API key
  - Internet connection

## 🙏 Acknowledgments

- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - High-performance local Whisper implementation by Georgi Gerganov
- [OpenAI Whisper](https://openai.com/research/whisper) - Original Whisper model
- Community feedback and testing

## 🐛 Known Issues

- Test file `WhisperCppClientTests.swift` needs manual addition to Xcode test target (development only)
- DMG not yet code-signed (macOS may show security warning on first launch)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/Latentti/speech-to-clip/issues)
- **Documentation**: [README](https://github.com/Latentti/speech-to-clip)
- **Email**: ari.hietamaki@latentti.fi

---

**Full Changelog**: https://github.com/Latentti/speech-to-clip/compare/v0.2.0...v0.3.0

Made with ❤️ for privacy-conscious productivity enthusiasts
