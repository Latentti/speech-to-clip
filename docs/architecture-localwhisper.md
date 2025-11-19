# Local Whisper Integration - Architecture Document

**Project:** speech-to-clip
**Feature:** Local Whisper Integration
**Author:** Winston (Architect Agent)
**Date:** 2025-11-19
**Version:** 1.0

---

## Executive Summary

This architecture document defines the technical implementation for adding Local Whisper support to speech-to-clip, a deployed macOS application. The integration enables users to choose between cloud-based OpenAI API and local whisper.cpp processing on a per-profile basis.

**Key Architectural Choices:**
1. **whisper.cpp** with Metal/Core ML acceleration for Apple Silicon optimization
2. **HTTP REST API** via native URLSession (localhost-only, zero external dependencies)
3. **Zero audio conversion** - existing WAV format works perfectly
4. **Per-profile configuration** - engine settings stored in Profile struct
5. **Swift Concurrency** (async/await) matching existing OpenAI implementation

**Privacy Guarantee:** Architecture ensures zero external network calls when Local Whisper is active, verified through automated testing.

**Performance Target:** Near real-time transcription (≤1.0x ratio) on Apple Silicon with Metal acceleration.

---

## Project Context

**Feature Overview:**
Add Local Whisper as an alternative transcription engine to the existing speech-to-clip macOS application, enabling privacy-conscious users to process audio locally while maintaining the existing OpenAI API option.

**Integration Type:** Brownfield feature addition to deployed application

**Key Architectural Drivers:**
1. **Privacy-First:** Zero network calls when Local Whisper active (verifiable)
2. **Apple Silicon Performance:** Near real-time transcription (≤1.0x ratio)
3. **Backward Compatibility:** Existing OpenAI users unaffected
4. **Power User Focus:** Expose necessary technical controls

---

## Architectural Decisions

### Decision #1: Whisper Implementation - whisper.cpp

**Decision:** Use **whisper.cpp** as the Local Whisper implementation

**Rationale:**
- **Apple Silicon Optimization:** Native Metal and Core ML support provides 3x+ speedup on M1/M2/M3
- **Performance:** Achieves near real-time transcription (0.3s for 11s audio on M2 Pro)
- **Built-in HTTP Server:** Native server mode with OpenAI-compatible API (`./server`)
- **Lightweight:** C++ implementation, minimal dependencies
- **Active Development:** Well-maintained by ggml-org, strong community

**Verified Current Version:** Latest stable (2024)

**Implementation Notes:**
- whisper.cpp provides `/v1/audio/transcriptions` endpoint (OpenAI-compatible)
- Supports concurrent requests
- Dynamic model loading via `/load` endpoint
- Multiple hardware acceleration: Metal (Apple Silicon), CPU optimized

**Affects Epics:**
- Epic 2: Local Whisper Integration Core
- Epic 4: Testing & Validation (performance benchmarking)

---

### Decision #2: Communication Protocol - HTTP via URLSession

**Decision:** Use **URLSession** to communicate with whisper.cpp HTTP server via localhost

**Protocol Details:**
- **Endpoint:** `http://localhost:[port]/v1/audio/transcriptions`
- **Method:** POST with multipart/form-data
- **Connection:** localhost only (127.0.0.1) - no external network
- **Default Port:** Configurable in profile settings (e.g., 8080)

**Rationale:**
- **Zero Dependencies:** Native Swift URLSession, no external libraries
- **Privacy Guarantee:** Localhost-only connections ensure no external network traffic
- **Full Control:** Direct control over request/response handling
- **OpenAI Compatibility:** whisper.cpp endpoint matches OpenAI API format

**Implementation Pattern:**
```swift
// Pseudocode structure
let url = URL(string: "http://localhost:\(port)/v1/audio/transcriptions")
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

// Multipart form: audio file + model parameter
let body = createMultipartBody(audioData: data, model: modelName)
request.httpBody = body

let task = URLSession.shared.dataTask(with: request) { data, response, error in
    // Handle response
}
```

**Connection Detection:**
- Test connection with lightweight health check or OPTIONS request
- Timeout: 5 seconds for connection, 60 seconds for transcription
- Error handling: Clear distinction between "service not running" vs "transcription failed"

**Affects Epics:**
- Epic 2: Local Whisper Integration Core (connection layer)
- Epic 3: Error Handling (connection failures, timeouts)

---

### Decision #3: Audio Format Handling - Zero Conversion Required

**Decision:** **Direct passthrough of existing WAV format** - no audio conversion needed

**Current Audio Pipeline (Discovered from Codebase):**
- **Source:** AudioRecorder.swift captures audio via AVAudioEngine
- **Format:** WAV (RIFF WAVE container)
- **Specifications:**
  - Sample Rate: 16 kHz
  - Channels: 1 (mono)
  - Bit Depth: 16-bit PCM
  - Internal: Converts from Float32 PCM to Int16 PCM with proper WAV headers
- **Size Limit:** 25 MB (OpenAI requirement, maintain for consistency)

**Rationale:**
- ✅ **Zero Conversion:** Existing WAV format is optimal for both OpenAI and whisper.cpp
- ✅ **Performance:** No transcoding overhead
- ✅ **Quality:** 16 kHz mono is ideal for speech recognition
- ✅ **Proven:** Format already validated in AudioFormatService.swift

**Implementation Details:**
```swift
// Current flow (from AudioRecorder.swift):
// 1. AVAudioEngine captures → Float32 PCM buffers
// 2. convertPCMBufferToWAV() → 16-bit WAV with proper headers
// 3. stopRecording() → Returns Data (WAV bytes)

// For whisper.cpp integration:
// Same Data can be sent directly to localhost HTTP endpoint
// No format conversion layer needed
```

**Compatibility Notes:**
- whisper.cpp accepts: WAV, MP3, M4A, FLAC, OGG
- OpenAI accepts: WAV, MP3, M4A, FLAC, WebM, OGG
- **Our WAV (16kHz mono PCM)** is optimal for both

**Code References:**
- AudioRecorder.swift:74-94 (recording format setup)
- AudioRecorder.swift:331-389 (WAV conversion implementation)
- WhisperClient.swift:234-239 (OpenAI multipart form encoding)
- AudioFormatService.swift:43-73 (WAV validation)

**Affects Epics:**
- Epic 2: Local Whisper Integration Core (audio handling - simplified!)
- Epic 4: Testing & Validation (verify format compatibility)

---

### Decision #4: Profile System Extension - Per-Profile Configuration

**Decision:** Extend existing Profile struct with **per-profile transcription engine settings**

**Current Profile Architecture (Discovered from Codebase):**
- **Model:** Profile struct (Codable, UUID-based identifiers)
- **Storage:** UserDefaults for metadata, Keychain for API keys
- **Management:** ProfileManager handles CRUD operations
- **Active Profile:** Tracked in ProfileManager, used by AppState

**Schema Extension:**
```swift
// Profile.swift - Add these fields to existing Profile struct:
struct Profile: Identifiable, Codable, Equatable {
    // ... existing fields (id, name, language, createdAt, updatedAt) ...

    // NEW: Transcription engine configuration
    var transcriptionEngine: TranscriptionEngine = .openai
    var whisperModelName: String? = nil           // e.g., "base", "medium", "large"
    var whisperServerPort: Int = 8080             // Default localhost port
}

// NEW: Transcription engine enum
enum TranscriptionEngine: String, Codable, CaseIterable {
    case openai = "OpenAI API"
    case localWhisper = "Local Whisper"
}
```

**Migration Strategy:**
- **Backward Compatible:** Codable defaults handle existing profiles
- **Existing Profiles:** Automatically get `transcriptionEngine = .openai`
- **No Data Loss:** All existing profiles continue working unchanged
- **Validation:** ProfileManager validates whisperServerPort range (1024-65535)

**Rationale:**
- ✅ **Per-Profile Flexibility:** Power users can have different setups (work vs personal)
- ✅ **Clean Separation:** Engine choice lives with profile, not global settings
- ✅ **Easy Switching:** Profile switching already works, engine switches automatically
- ✅ **Zero Impact:** Existing OpenAI users unaffected

**UI Changes Required:**
```swift
// ProfilesTab.swift - Add to profile edit/create sheets:
Picker("Transcription Engine", selection: $transcriptionEngine) {
    ForEach(TranscriptionEngine.allCases, id: \.self) { engine in
        Text(engine.rawValue).tag(engine)
    }
}

// Conditionally show Local Whisper fields:
if transcriptionEngine == .localWhisper {
    TextField("Model Name", text: $whisperModelName)
        .textContentType(.none)
        .help("e.g., base, small, medium, large")

    TextField("Server Port", value: $whisperServerPort, format: .number)
        .textContentType(.none)
        .help("whisper.cpp server port (default: 8080)")
}
```

**AppState Integration:**
```swift
// AppState.swift - transcribeAudio() routing:
let profile = currentProfile
switch profile.transcriptionEngine {
case .openai:
    // Existing OpenAI path
    let apiKey = try keychainService.retrieve(for: profile.id)
    text = try await transcriptionService.transcribe(...)

case .localWhisper:
    // NEW: Local Whisper path
    text = try await whisperCppService.transcribe(
        audioData: audioData,
        model: profile.whisperModelName ?? "base",
        port: profile.whisperServerPort,
        language: profile.language
    )
}
```

**Code References:**
- Profile.swift (model definition)
- ProfileManager.swift:114-164 (CRUD operations)
- ProfilesTab.swift:41-186 (UI implementation)
- AppState.swift:404-422 (transcription integration)
- KeychainService.swift (API key storage)

**Affects Epics:**
- Epic 1: Profile System Enhancement (schema extension, UI updates, migration)
- Epic 2: Local Whisper Integration Core (routing logic in AppState)

---

### Decision #5: Background Processing - Swift Concurrency (async/await)

**Decision:** Use **Swift Concurrency (async/await)** for Local Whisper transcription, matching existing OpenAI implementation

**Current Threading Model (Discovered from Codebase):**
- TranscriptionService.swift:68 - `async func transcribe(...)`
- WhisperClient.swift:62 - `async func transcribe(...)`
- AppState.swift - calls transcription with `await` in Task blocks

**Implementation Pattern for whisper.cpp:**
```swift
// WhisperCppClient.swift - NEW service
actor WhisperCppClient {
    func transcribe(
        audioData: Data,
        model: String,
        port: Int,
        language: String
    ) async throws -> String {
        let url = URL(string: "http://localhost:\(port)/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60.0  // 60s for transcription

        // Multipart form-data body
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)",
                        forHTTPHeaderField: "Content-Type")
        request.httpBody = createMultipartBody(
            audioData: audioData,
            model: model,
            language: language,
            boundary: boundary
        )

        // async/await network call
        let (data, response) = try await URLSession.shared.data(for: request)

        // Parse response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperCppError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw WhisperCppError.transcriptionFailed(statusCode: httpResponse.statusCode)
        }

        let result = try JSONDecoder().decode(WhisperResponse.self, from: data)
        return result.text
    }
}
```

**Rationale:**
- ✅ **Consistency:** Matches existing OpenAI transcription flow
- ✅ **Main Thread Safe:** UI remains responsive during transcription
- ✅ **Modern Swift:** Structured concurrency, no completion handlers
- ✅ **Actor Isolation:** WhisperCppClient as actor prevents data races
- ✅ **Cancellation Support:** Task cancellation works automatically

**Timeout Strategy:**
- **Connection Test:** 5 seconds (detect if server running)
- **Transcription:** 60 seconds (generous for large models)
- **User Can Cancel:** Task cancellation stops network request

**Error Handling:**
```swift
enum WhisperCppError: LocalizedError {
    case serverNotRunning
    case connectionTimeout
    case invalidResponse
    case transcriptionFailed(statusCode: Int)
    case invalidModel(String)

    var errorDescription: String? {
        switch self {
        case .serverNotRunning:
            return "Local Whisper server is not running"
        case .connectionTimeout:
            return "Connection to Local Whisper timed out"
        case .invalidResponse:
            return "Invalid response from Local Whisper"
        case .transcriptionFailed(let code):
            return "Transcription failed with status \(code)"
        case .invalidModel(let name):
            return "Invalid model name: \(name)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .serverNotRunning:
            return "Start whisper.cpp server with: ./server -m models/ggml-base.bin"
        // ... other suggestions
        }
    }
}
```

**Code References:**
- TranscriptionService.swift:68 (existing async pattern)
- WhisperClient.swift:62 (OpenAI implementation to mirror)
- AppState.swift:404-467 (transcription call site)

**Affects Epics:**
- Epic 2: Local Whisper Integration Core (WhisperCppClient implementation)
- Epic 3: Error Handling (async error propagation)

---

## Implementation Patterns

These patterns ensure consistency across all AI agent implementations.

### File Organization

**NEW Files to Create:**
```
speech-to-clip/
├── Core/
│   └── Transcription/
│       ├── WhisperCppClient.swift          // NEW: whisper.cpp HTTP client
│       ├── WhisperCppError.swift           // NEW: error types
│       └── TranscriptionEngine.swift       // NEW: engine enum (or in Profile.swift)
├── Models/
│   └── Profile.swift                       // MODIFY: add engine fields
└── Features/
    └── Settings/
        └── ProfilesTab.swift                // MODIFY: add engine UI
```

**Naming Convention:**
- Services end with `Client` (WhisperCppClient, not WhisperCppService)
- Errors end with `Error` (WhisperCppError)
- Match existing patterns (WhisperClient.swift, ProfileManager.swift)

---

### Error Handling Pattern

**Consistency Rule:** All transcription errors must conform to `LocalizedError`

```swift
// Pattern established by existing code:
enum WhisperCppError: Error, LocalizedError {
    case serverNotRunning
    case connectionTimeout
    case transcriptionFailed(statusCode: Int)

    var errorDescription: String? {
        // User-facing message
    }

    var recoverySuggestion: String? {
        // Actionable help text with link to docs
    }
}
```

**Error Display:**
- Use AppState.errorMessage (existing pattern)
- Present errors via `.alert()` modifier
- Include recovery suggestions with documentation links

---

### Connection Detection Pattern

**Health Check Before Transcription:**
```swift
// WhisperCppClient.swift
func checkServerAvailability(port: Int) async throws -> Bool {
    let url = URL(string: "http://localhost:\(port)/health")!
    var request = URLRequest(url: url)
    request.timeoutInterval = 5.0  // Quick check

    do {
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }
        return http.statusCode == 200
    } catch {
        throw WhisperCppError.serverNotRunning
    }
}
```

**Pattern:** Always test connection before sending audio data

---

### Multipart Form-Data Encoding Pattern

**Consistency Rule:** Match OpenAI API format for compatibility

```swift
// Helper function (similar to WhisperClient.swift pattern):
private func createMultipartBody(
    audioData: Data,
    model: String,
    language: String,
    boundary: String
) -> Data {
    var body = Data()

    // File part
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
    body.append("Content-Type: audio/wav\r\n\r\n")
    body.append(audioData)
    body.append("\r\n")

    // Model part
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
    body.append("\(model)\r\n")

    // Language part (optional for whisper.cpp)
    body.append("--\(boundary)\r\n")
    body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
    body.append("\(language)\r\n")

    // End boundary
    body.append("--\(boundary)--\r\n")

    return body
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
```

**Pattern:** Reuse multipart encoding helper, maintain boundary format

---

### Response Parsing Pattern

**whisper.cpp Response Format (OpenAI-compatible):**
```json
{
  "text": "Transcribed text here"
}
```

**Decoding:**
```swift
struct WhisperResponse: Codable {
    let text: String
}

// In transcribe() method:
let result = try JSONDecoder().decode(WhisperResponse.self, from: data)
return result.text
```

**Pattern:** Simple Codable structs, match OpenAI response format

---

### AppState Integration Pattern

**Routing Logic in transcribeAudio():**
```swift
// AppState.swift - modify existing transcribeAudio() method
guard let profile = currentProfile else {
    throw AppError.noActiveProfile
}

let transcribedText: String

switch profile.transcriptionEngine {
case .openai:
    // Existing OpenAI path (unchanged)
    let apiKey = try keychainService.retrieve(for: profile.id)
    transcribedText = try await transcriptionService.transcribe(
        audioData: audioData,
        apiKey: apiKey,
        language: profile.language
    )

case .localWhisper:
    // NEW: whisper.cpp path
    let whisperClient = WhisperCppClient()

    // Health check first
    let isAvailable = try await whisperClient.checkServerAvailability(
        port: profile.whisperServerPort
    )
    guard isAvailable else {
        throw WhisperCppError.serverNotRunning
    }

    transcribedText = try await whisperClient.transcribe(
        audioData: audioData,
        model: profile.whisperModelName ?? "base",
        port: profile.whisperServerPort,
        language: profile.language
    )
}

// Common path continues (copy to clipboard, etc.)
text = transcribedText
```

**Pattern:** Switch on engine type, maintain existing OpenAI path unchanged

---

### UI Conditional Display Pattern

**ProfilesTab.swift - Engine-Specific Fields:**
```swift
Form {
    TextField("Profile Name", text: $name)

    Picker("Language", selection: $language) { ... }

    // NEW: Engine picker
    Picker("Transcription Engine", selection: $transcriptionEngine) {
        ForEach(TranscriptionEngine.allCases, id: \.self) { engine in
            Text(engine.rawValue).tag(engine)
        }
    }

    // Conditional sections based on engine
    switch transcriptionEngine {
    case .openai:
        Section("OpenAI Configuration") {
            SecureField("API Key", text: $apiKey)
                .textContentType(.password)
        }

    case .localWhisper:
        Section("Local Whisper Configuration") {
            TextField("Model Name", text: $modelName)
                .help("e.g., base, small, medium, large")

            TextField("Server Port", value: $serverPort, format: .number)
                .help("Default: 8080")

            Text("For less common languages, Medium or Large models recommended for best quality")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
```

**Pattern:** Use `switch` for mutually exclusive UI sections

---

### Testing Pattern

**Unit Tests:**
```swift
// WhisperCppClientTests.swift
final class WhisperCppClientTests: XCTestCase {
    func testMultipartBodyCreation() async throws {
        // Test multipart encoding
    }

    func testServerAvailabilityCheck() async throws {
        // Mock server response
    }

    func testTranscriptionWithValidResponse() async throws {
        // Mock successful transcription
    }

    func testErrorHandlingWhenServerDown() async throws {
        // Verify proper error thrown
    }
}
```

**Integration Tests:**
- Test with actual whisper.cpp server (if available)
- Fallback to mocked responses for CI/CD

**Pattern:** Follow existing test patterns in speech-to-clipTests/

---

### Privacy Validation Pattern

**Network Monitoring Test:**
```swift
// Integration test to verify no external calls
func testLocalWhisperNoExternalNetwork() async throws {
    let profile = Profile(
        name: "Test",
        language: "en",
        transcriptionEngine: .localWhisper,
        whisperModelName: "base",
        whisperServerPort: 8080
    )

    // Monitor network activity
    let networkMonitor = NetworkMonitor()
    networkMonitor.startMonitoring()

    try await appState.transcribe(with: profile)

    // Assert: No external network calls
    XCTAssertTrue(networkMonitor.allCallsWereLocalhost)
}
```

**Pattern:** Automated privacy verification in test suite

---

## Architecture Decision Records (ADR)

### ADR-001: Whisper Implementation - whisper.cpp
**Status:** Accepted
**Context:** Need to choose Local Whisper implementation
**Decision:** Use whisper.cpp for Apple Silicon optimization
**Consequences:** 3x+ performance, Metal acceleration, minimal dependencies

### ADR-002: Communication Protocol - HTTP/URLSession
**Status:** Accepted
**Context:** How to communicate with Local Whisper
**Decision:** HTTP REST API via native URLSession to localhost
**Consequences:** Zero dependencies, privacy-safe (localhost-only), OpenAI-compatible

### ADR-003: Audio Format - Direct WAV Passthrough
**Status:** Accepted
**Context:** Audio format for Local Whisper
**Decision:** No conversion - use existing 16kHz mono WAV
**Consequences:** Zero overhead, optimal quality, proven format

### ADR-004: Profile Storage - Per-Profile Engine Selection
**Status:** Accepted
**Context:** Where to store transcription engine preference
**Decision:** Extend Profile struct with engine settings
**Consequences:** Per-profile flexibility, clean separation, easy switching

### ADR-005: Threading Model - Swift Concurrency
**Status:** Accepted
**Context:** Background processing for transcription
**Decision:** async/await matching existing OpenAI implementation
**Consequences:** Consistent codebase, modern Swift, UI responsiveness

---

## Epic to Architecture Mapping

### Epic 1: Profile System Enhancement
**Architecture Components:**
- Profile.swift (model extension)
- ProfileManager.swift (validation)
- ProfilesTab.swift (UI updates)
- UserDefaults migration

**Key Decisions:**
- Decision #4: Per-profile configuration

---

### Epic 2: Local Whisper Integration Core
**Architecture Components:**
- WhisperCppClient.swift (new)
- WhisperCppError.swift (new)
- AppState.swift (routing logic)
- TranscriptionEngine.swift (enum)

**Key Decisions:**
- Decision #1: whisper.cpp
- Decision #2: HTTP/URLSession
- Decision #3: WAV passthrough
- Decision #5: async/await

---

### Epic 3: Error Handling & User Feedback
**Architecture Components:**
- WhisperCppError conforming to LocalizedError
- AppState error display
- UI alert modifiers

**Key Patterns:**
- Error handling pattern
- Recovery suggestions with doc links

---

### Epic 4: Testing & Validation
**Architecture Components:**
- WhisperCppClientTests.swift
- Privacy validation tests
- Integration tests

**Key Patterns:**
- Testing pattern
- Privacy validation pattern

---

### Epic 5: Documentation & Community
**Architecture Deliverable:**
- This architecture document
- Privacy data flow diagram
- GitHub documentation

---

## Data Flow Diagrams

### OpenAI API Flow (Existing - Unchanged)
```
User → Audio Recording → AudioRecorder → WAV Data
                                           ↓
Profile (OpenAI) → Keychain (API Key) → WhisperClient
                                           ↓
                                    OpenAI API (external)
                                           ↓
                                    Transcribed Text
                                           ↓
                                    Clipboard + UI
```

### Local Whisper Flow (New)
```
User → Audio Recording → AudioRecorder → WAV Data
                                           ↓
Profile (Local Whisper) → WhisperCppClient
                              ↓
                    localhost:port/v1/audio/transcriptions
                              ↓
                    whisper.cpp server (local process)
                              ↓
                    Transcribed Text
                              ↓
                    Clipboard + UI

🔒 Privacy Guarantee: No external network calls
```

### Profile Switching Flow
```
User selects Profile → ProfileManager.setActiveProfile()
                              ↓
                    AppState.currentProfile updates
                              ↓
                    UI reflects active engine
                              ↓
User triggers transcription → AppState.transcribeAudio()
                              ↓
            Switch on profile.transcriptionEngine
                      ↙              ↘
              .openai                 .localWhisper
                 ↓                         ↓
         WhisperClient              WhisperCppClient
```

---

## Security Considerations

### Privacy Architecture
1. **Localhost-Only:** All whisper.cpp connections hardcoded to 127.0.0.1
2. **No External DNS:** URL construction prevents external hosts
3. **Code Audit:** Open source allows community verification
4. **Network Monitoring:** Automated tests verify no external calls

### Data Protection
- **Audio Data:** Never persisted when using Local Whisper
- **Transcriptions:** Not sent to external services
- **API Keys:** Not needed for Local Whisper (Keychain unused)

### Threat Model
- **Mitigation:** Man-in-the-middle attacks prevented (localhost)
- **Mitigation:** Data exfiltration prevented (no network)
- **Out of Scope:** whisper.cpp server security (user responsibility)

---

## Performance Considerations

### Apple Silicon Optimization
- **whisper.cpp Metal Support:** GPU acceleration via Metal Performance Shaders
- **Core ML Integration:** Neural Engine utilization for inference
- **Expected Performance:** 3x+ faster than CPU-only (verified from research)

### Memory Management
- **Audio Buffers:** Existing AudioRecorder handles memory efficiently
- **Async Processing:** No blocking UI thread
- **Model Loading:** whisper.cpp handles (user manages model files)

### Benchmarking Strategy
```swift
// Performance test example
func testTranscriptionPerformance() async throws {
    let audioData = loadTestAudio(duration: 60) // 1 minute
    let startTime = Date()

    let text = try await whisperClient.transcribe(
        audioData: audioData,
        model: "medium",
        port: 8080,
        language: "en"
    )

    let elapsed = Date().timeIntervalSince(startTime)
    XCTAssertLessThanOrEqual(elapsed, 60.0) // Real-time target
}
```

---

## Deployment & Rollout

### User Requirements
Users must install and run whisper.cpp server separately:
```bash
# Example user setup (documented in GitHub)
git clone https://github.com/ggerganov/whisper.cpp
cd whisper.cpp
make server
./server -m models/ggml-base.bin --port 8080
```

### App Distribution
- **macOS Version:** Maintain existing minimum version
- **No Bundled Binary:** whisper.cpp not included (user installs)
- **Migration:** Automatic (existing profiles get .openai default)

### Feature Flag (Optional)
Consider feature flag for gradual rollout:
```swift
// Optional: Environment-based feature flag
#if DEBUG
let localWhisperEnabled = true
#else
let localWhisperEnabled = ProcessInfo.processInfo.environment["ENABLE_LOCAL_WHISPER"] == "true"
#endif
```

---

## Next Steps

### Implementation Phase

**Story Priority Order (Recommended):**

1. **Profile System Extension**
   - Add TranscriptionEngine enum
   - Extend Profile struct
   - Update ProfilesTab UI
   - Test migration

2. **WhisperCppClient Core**
   - Create WhisperCppClient.swift
   - Implement transcribe() method
   - Create WhisperCppError types
   - Unit tests

3. **AppState Integration**
   - Add engine routing logic
   - Update transcribeAudio()
   - Error handling
   - Integration tests

4. **Testing & Validation**
   - Privacy verification tests
   - Performance benchmarks
   - Manual testing with whisper.cpp

5. **Documentation**
   - GitHub setup guide
   - Privacy guarantees doc
   - Troubleshooting guide

---

## References

### External Documentation
- **whisper.cpp GitHub:** https://github.com/ggerganov/whisper.cpp
- **whisper.cpp Server Docs:** https://github.com/ggerganov/whisper.cpp#server
- **OpenAI Whisper:** https://github.com/openai/whisper

### Internal Code References
- `speech-to-clip/Core/Audio/AudioRecorder.swift` (audio recording and WAV format)
- `speech-to-clip/Core/Transcription/WhisperCppClient.swift` (Local Whisper HTTP client implementation)
- `speech-to-clip/Core/Transcription/WhisperCppError.swift` (error types for Local Whisper)
- `speech-to-clip/Models/Profile.swift` (profile model with transcriptionEngine field)
- `speech-to-clip/Services/ProfileManager.swift` (profile CRUD operations)
- `speech-to-clip/App/AppState.swift:463-498` (Local Whisper transcription routing)
- `speech-to-clipTests/CoreTests/Transcription/WhisperCppClientTests.swift` (unit tests with privacy validation)

### Related Documents
- PRD-LocalWhisper.md (requirements)
- Epic definitions (to be created)

---

**Document Status:** ✅ Complete - Ready for Implementation

**Last Updated:** 2025-11-19
**Next Review:** After Epic 1 completion

---
