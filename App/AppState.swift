//
//  AppState.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-12.
//  Story 1.4: Implement Central AppState
//  Story 7.4: Implement Profile Switching
//

import SwiftUI
import Combine

/// Central application state manager
///
/// This is the single source of truth for all application state.
/// All UI components observe AppState for state changes via SwiftUI's
/// @ObservableObject pattern.
///
/// @MainActor ensures all state updates happen on the main thread,
/// which is required for SwiftUI UI updates.
///
/// Future stories will inject service dependencies (AudioRecorder,
/// TranscriptionService, HotkeyManager, etc.) via the init() method.
@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties

    /// Current state of the recording lifecycle
    /// Drives UI updates for menu bar icon and visualizer states
    @Published var recordingState: RecordingState = .idle

    /// Currently active API key profile
    /// nil indicates no profile is selected
    /// Full implementation in Epic 7: Profile & Keychain Management
    @Published var currentProfile: Profile? = nil

    /// User preferences and configuration settings
    /// Persisted via SettingsService (to be implemented in Epic 6)
    @Published var settings: AppSettings = AppSettings()

    /// Indicates if a long-running operation is in progress
    /// Used to disable UI controls or show loading indicators
    @Published var isProcessing: Bool = false

    /// Most recent error that occurred
    /// UI can observe this to display error messages to the user
    /// nil indicates no error
    @Published var lastError: Error? = nil

    /// Current audio amplitude during recording
    /// Range: 0.0 (silence) to 1.0 (maximum amplitude)
    /// Updated in real-time during recording for visual feedback
    /// Used by Matrix visualizer (Epic 3) to control stream intensity
    @Published var currentAmplitude: Double = 0.0

    /// Last recorded audio data
    /// Stored after recording completes for future transcription (Story 4.3)
    /// nil indicates no recording available
    @Published var lastRecordedAudio: Data? = nil

    /// Last transcribed text from successful transcription
    /// Story 4.4: Populated after successful transcription
    /// nil indicates no transcription available
    @Published var lastTranscribedText: String? = nil

    /// Temporary API key for OpenAI Whisper API
    /// Story 4.4: MVP solution - Epic 7 Story 7.1 will replace with KeychainService
    /// TODO: Replace with KeychainService.getActiveProfile() in Story 7.1
    @Published var apiKey: String = ""

    /// Indicates if the settings window is currently open
    /// Story 6.1: Single instance pattern - only one settings window at a time
    /// Used by menu bar to present/dismiss settings window
    @Published var settingsWindowOpen: Bool = false

    /// Current validation error message for settings
    /// Story 6.5: Published for reactive UI updates
    /// nil indicates no validation errors, non-nil contains error message to display
    @Published var validationError: String? = nil

    /// Indicates if the onboarding window should be shown
    /// Story 8.2: Shown on first launch when onboardingCompleted is false
    /// Set to true in init() if onboarding not completed, triggers sheet presentation
    @Published var showOnboarding: Bool = false

    /// Indicates if the tutorial prompt window should be shown
    /// Story 8.4: Shown after onboarding when tutorialCompleted is false
    /// Provides "Try it now!" guidance with hotkey instructions
    @Published var showTutorialPrompt: Bool = false

    /// Audio data stored for retry capability
    /// Story 12.3: Retained after WhisperCppError for retry without re-recording
    /// Cleared on successful transcription or profile switch
    @Published var retryAudioData: Data? = nil

    /// Number of retry attempts for current transcription
    /// Story 12.3: Tracks failed retry attempts (max 3)
    /// Reset to 0 on successful transcription
    /// Internal access for MenuBarController to display attempt count
    var retryCount: Int = 0

    /// Maximum number of retry attempts allowed
    /// Story 12.3: 3-retry limit prevents infinite loops
    /// Internal access for MenuBarController to display attempt limit
    let maxRetries: Int = 3

    // MARK: - Service Dependencies

    /// AudioRecorder instance for managing audio recording lifecycle
    /// Lazy initialization allows passing self reference for amplitude publishing
    private lazy var audioRecorder: AudioRecorder = {
        // Initialize with self reference for automatic amplitude publishing
        return AudioRecorder(appState: self)
    }()

    /// TranscriptionService instance for transcribing audio to text
    /// Story 4.4: Lazy initialization with default dependencies (WhisperClient, AudioFormatService)
    /// Orchestrates audio validation and Whisper API transcription
    private lazy var transcriptionService: TranscriptionService = {
        return TranscriptionService()
    }()

    /// ClipboardService instance for copying text to system clipboard
    /// Story 5.1: Lazy initialization - copies transcribed text as fallback if auto-paste fails
    /// Auto-paste will be added in Story 5.2
    private lazy var clipboardService: ClipboardService = {
        return ClipboardService()
    }()

    /// ActiveAppDetector instance for detecting active application and text input capability
    /// Story 5.4: Lazy initialization - detects if active app accepts text input before pasting
    private lazy var activeAppDetector: ActiveAppDetector = {
        return ActiveAppDetector()
    }()

    /// PasteManager instance for simulating paste via accessibility API
    /// Story 5.4: Lazy initialization - automatically pastes transcribed text to active app
    private lazy var pasteManager: PasteManager = {
        return PasteManager()
    }()

    /// Visualizer window instance for displaying visual feedback during recording
    /// Story 3.1: Create Floating Visualizer Window
    /// Story 3.7: Initialized eagerly to ensure WaveRenderer subscribes before state changes
    private var visualizerWindow: VisualizerWindow!

    /// SettingsService instance for persisting user settings to UserDefaults
    /// Story 6.4: Lazy initialization - loads and saves settings atomically
    /// Handles encoding/decoding with graceful error handling (never crashes)
    private lazy var settingsService: SettingsService = {
        return SettingsService()
    }()

    /// ProfileManager instance for managing user profiles
    /// Story 7.4: Loads active profile on app launch and manages profile switching
    private let profileManager = ProfileManager()

    /// PermissionManager instance for checking system permissions
    /// Story 8.2: Used to check microphone and accessibility permissions before recording
    /// Story 8.1: Provides permission status checks and system settings deep linking
    private lazy var permissionManager: PermissionManager = {
        return PermissionManager()
    }()

    // MARK: - Singleton

    /// Shared singleton instance of AppState
    ///
    /// Story 6.2: Converted to singleton pattern to ensure MenuBarController and SwiftUI App
    /// share the same AppState instance. This fixes Settings window not opening issue.
    ///
    /// Previously: MenuBarController created its own AppState instance (line 35 in MenuBarController.swift)
    /// which was separate from the SwiftUI @StateObject instance, causing settingsWindowOpen
    /// to update the wrong instance.
    static let shared = AppState()

    // MARK: - Initialization

    /// Initialize AppState with service dependencies
    ///
    /// Story 2.4: AudioRecorder lazy initialized with self for amplitude publishing
    /// Story 3.1: VisualizerWindow initialized eagerly with self for state observation
    /// Story 3.7: Eager initialization ensures WaveRenderer catches first recording state change
    /// Story 6.2: Kept internal (not private) to allow test instantiation
    /// Story 6.4: Load persisted settings before UI initialization
    /// Story 7.4: Load active profile on app launch
    ///
    /// Note: Tests can create AppState() instances for isolated testing.
    /// Production code should use AppState.shared singleton.
    init() {
        // Story 6.4: Load persisted settings before UI initialization
        // If settings exist in UserDefaults, load them; otherwise use defaults
        if let loadedSettings = settingsService.loadSettings() {
            self.settings = loadedSettings
            print("✅ Loaded settings from UserDefaults")
        } else {
            // Use default AppSettings (already initialized in property declaration)
            print("ℹ️ No saved settings found - using defaults")
        }

        // Story 8.2: Check if onboarding should be shown (first launch)
        // Show onboarding if onboardingCompleted flag is false
        if !settings.onboardingCompleted {
            self.showOnboarding = true
            print("ℹ️ First launch detected - onboarding will be shown")
        }

        // Story 8.4: Set up observer for onboarding completion to show tutorial
        // When onboarding finishes, check if we should show tutorial prompt
        setupOnboardingCompletionObserver()

        // Story 7.4: Load active profile on app launch (AC 3)
        // This populates currentProfile with the user's active profile (if exists)
        do {
            self.currentProfile = try profileManager.getActiveProfile()
            if let profile = self.currentProfile {
                print("✅ Loaded active profile: \(profile.name)")
            } else {
                print("ℹ️ No active profile configured")
            }
        } catch {
            // Profile loading failed - log and continue with nil profile
            print("⚠️ Failed to load active profile: \(error.localizedDescription)")
            self.currentProfile = nil
        }

        // Initialize VisualizerWindow eagerly to ensure state subscriptions are set up
        // before any state changes occur (particularly important for first recording)
        self.visualizerWindow = VisualizerWindow(appState: self)

        // AudioRecorder remains lazy-initialized on first access with self reference
    }

    // MARK: - Settings Window Management

    /// Open the settings window
    ///
    /// Sets settingsWindowOpen to true, which triggers the settings window presentation.
    /// If the window is already open, this brings it to front (handled by SwiftUI).
    ///
    /// Story 6.1: Settings window structure and lifecycle
    func openSettings() {
        print("⚙️ Opening settings window...")
        settingsWindowOpen = true
    }

    /// Close the settings window
    ///
    /// Sets settingsWindowOpen to false, which dismisses the settings window.
    ///
    /// Story 6.1: Settings window structure and lifecycle
    func closeSettings() {
        print("⚙️ Closing settings window...")
        settingsWindowOpen = false
    }

    /// Save current settings to UserDefaults
    ///
    /// Validates settings before persisting. Invalid settings are not saved
    /// and validation errors are published to validationError for UI display.
    ///
    /// Story 6.4: Settings persistence with auto-save
    /// Story 6.5: Validation integration - validate before save
    func saveCurrentSettings() {
        // Validate settings before saving
        let validation = settingsService.validateSettings(settings)

        if validation.isValid {
            // Valid settings - save to UserDefaults
            settingsService.saveSettings(settings)
            validationError = nil // Clear any previous errors
            print("💾 Settings validated and saved")
        } else {
            // Invalid settings - don't save, publish error
            validationError = validation.errorMessages.first
            print("⚠️ Settings validation failed: \(validation.errorMessages)")
        }
    }

    // MARK: - Recording Lifecycle Methods

    /// Start audio recording
    ///
    /// Initiates the recording lifecycle by updating state to .recording and
    /// starting the AudioRecorder. If recording fails, state reverts to .idle
    /// and error is published to lastError.
    ///
    /// Thread safety: @MainActor ensures this runs on main thread for state updates
    func startRecording() {
        // Check if already recording
        guard case .idle = recordingState else {
            print("⚠️ Cannot start recording - current state: \(recordingState)")
            return
        }

        // Story 8.2 & 8.3: Check permissions before recording
        let microphoneStatus = permissionManager.checkPermission(for: .microphone)
        let accessibilityStatus = permissionManager.checkPermission(for: .accessibility)

        // Microphone is required - block recording if denied (Story 8.3 AC 2)
        if microphoneStatus == .denied {
            print("❌ Cannot start recording - microphone permission denied")
            print("   User needs to grant permission in System Settings → Privacy & Security → Microphone")

            // Story 8.3: Show user-friendly alert with "Open System Settings" button
            AlertHelper.showPermissionDeniedAlert(for: .microphone, permissionManager: permissionManager)

            // Set error state for observing UI components
            lastError = NSError(
                domain: "com.speech-to-clip.permissions",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Microphone access denied. Please grant permission in System Settings."]
            )

            // IMPORTANT: Do NOT transition to .recording state - stay in .idle (Story 8.3 AC 2)
            return
        }

        // Accessibility is optional for recording but required for auto-paste
        // Log warning if denied but allow recording to continue (Story 8.3 AC 1)
        if accessibilityStatus == .denied {
            print("⚠️ Accessibility permission denied - auto-paste will not be available")
            print("   Text will be copied to clipboard instead (manual paste with ⌘V)")
        }

        // Update state to recording
        // Note: VisualizerWindow is already initialized in init() to ensure
        // state subscriptions are ready before this first state change (Story 3.7)
        recordingState = .recording(startTime: Date.now)
        print("🎤 Starting recording...")

        // Start audio recorder
        do {
            try audioRecorder.startRecording()
            print("✅ Recording started successfully")
        } catch {
            // Recording failed - revert state and publish error
            print("❌ Failed to start recording: \(error.localizedDescription)")
            recordingState = .idle
            lastError = error
        }
    }

    /// Stop audio recording
    ///
    /// Stops the recording lifecycle by stopping the AudioRecorder and updating
    /// state to .idle. The recorded audio data is stored in lastRecordedAudio
    /// for future transcription.
    ///
    /// Thread safety: @MainActor ensures this runs on main thread for state updates
    func stopRecording() {
        // Check if currently recording
        guard case .recording = recordingState else {
            print("⚠️ Cannot stop recording - current state: \(recordingState)")
            return
        }

        print("⏹️ Stopping recording...")

        // Stop audio recorder and get recorded data
        do {
            let audioData = try audioRecorder.stopRecording()
            print("✅ Recording stopped - captured \(audioData.count) bytes")

            // Store recorded audio for transcription
            lastRecordedAudio = audioData

            // Story 4.4: Trigger transcription automatically
            // Update state to processing (shows yellow wave visualizer)
            recordingState = .processing

            // Launch transcription in background task
            Task {
                await transcribeAudio()
            }

            print("🔄 Transcription started...")
        } catch {
            // Stop recording failed - update state to error
            print("❌ Failed to stop recording: \(error.localizedDescription)")
            recordingState = .error(error)
            lastError = error
            currentAmplitude = 0.0

            // Auto-reset to idle after 3 seconds to allow retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                // Only reset if still in error state (not if user started new recording)
                if case .error = self.recordingState {
                    self.recordingState = .idle
                    print("🔄 Auto-reset to idle state after stopRecording error")
                }
            }
        }
    }

    /// Transcribe the last recorded audio using TranscriptionService
    ///
    /// Story 4.4: Automatically called after stopRecording() completes
    /// Story 7.4: Use currentProfile.apiKey if available, fallback to settings.apiKey
    /// Orchestrates the full transcription flow:
    /// 1. Validates audio data exists
    /// 2. Validates API key is configured (from profile or settings)
    /// 3. Calls TranscriptionService.transcribe()
    /// 4. On success: updates lastTranscribedText and transitions to .success
    /// 5. On error: updates lastError and transitions to .error
    ///
    /// Thread safety: @MainActor ensures this runs on main thread for state updates
    @MainActor
    private func transcribeAudio() async {
        // Validate audio data exists
        guard let audioData = lastRecordedAudio else {
            print("❌ No audio data available for transcription")
            recordingState = .error(SpeechToClipError.audioFormatInvalid)
            lastError = SpeechToClipError.audioFormatInvalid
            currentAmplitude = 0.0
            return
        }

        // Story 7.4: Get API key from currentProfile if available, otherwise use settings (AC 3)
        let effectiveAPIKey: String
        if let profile = currentProfile {
            // Use profile's API key from Keychain
            do {
                let keychainService = KeychainService()
                effectiveAPIKey = try keychainService.retrieve(for: profile.id)
                print("🔑 Using API key from profile: \(profile.name)")
            } catch {
                // Failed to retrieve profile API key - fall back to settings
                print("⚠️ Failed to retrieve profile API key: \(error.localizedDescription)")
                effectiveAPIKey = apiKey
                print("🔑 Falling back to settings API key")
            }
        } else {
            // No profile configured - use settings API key
            effectiveAPIKey = apiKey
            print("🔑 Using API key from settings (no profile configured)")
        }

        // Story 11.5: Route transcription based on engine type
        do {
            let text: String

            // Determine which transcription engine to use based on profile configuration
            let engineType = currentProfile?.transcriptionEngine ?? .openai

            switch engineType {
            case .openai:
                // OpenAI transcription path (unchanged from original implementation)
                // Validate API key is configured
                guard !effectiveAPIKey.isEmpty else {
                    print("❌ API key missing")
                    recordingState = .error(SpeechToClipError.apiKeyMissing)
                    lastError = SpeechToClipError.apiKeyMissing
                    currentAmplitude = 0.0
                    return
                }

                // Check if translation mode is enabled
                if settings.enableTranslation {
                    print("🔄 Starting translation to English (OpenAI)...")
                    // Use translation endpoint (auto-detects source language)
                    text = try await transcriptionService.translate(
                        audioData: audioData,
                        apiKey: effectiveAPIKey
                    )
                } else {
                    print("🔄 Starting transcription (OpenAI)...")
                    // Call TranscriptionService with audio, API key, and language
                    // Use language from active profile, fallback to settings.defaultLanguage if no profile
                    let language = currentProfile?.language ?? settings.defaultLanguage.rawValue
                    text = try await transcriptionService.transcribe(
                        audioData: audioData,
                        apiKey: effectiveAPIKey,
                        language: language
                    )
                }

            case .localWhisper:
                // Local Whisper transcription path (NEW in Story 11.5)
                print("🔄 Starting transcription (Local Whisper)...")

                guard let profile = currentProfile else {
                    print("❌ No profile configured for Local Whisper")
                    recordingState = .error(SpeechToClipError.apiKeyMissing)
                    lastError = SpeechToClipError.apiKeyMissing
                    currentAmplitude = 0.0
                    return
                }

                // Create WhisperCppClient instance
                let whisperClient = WhisperCppClient()

                // Health check: verify server is running before attempting transcription
                let isAvailable = try await whisperClient.checkServerAvailability(port: profile.whisperServerPort)
                guard isAvailable else {
                    print("❌ Local Whisper server not running on port \(profile.whisperServerPort)")
                    throw WhisperCppError.serverNotRunning
                }
                print("✅ Local Whisper server available on port \(profile.whisperServerPort)")

                // Transcribe with whisper.cpp
                // Use model name from profile, default to "base" if not specified
                let modelName = profile.whisperModelName ?? "base"
                let language = profile.language

                print("🔄 Transcribing with model: \(modelName), language: \(language), translate: \(settings.enableTranslation)")
                text = try await whisperClient.transcribe(
                    audioData: audioData,
                    model: modelName,
                    port: profile.whisperServerPort,
                    language: language,
                    translate: settings.enableTranslation
                )
            }

            // Success: update transcribed text
            lastTranscribedText = text

            // Story 12.3: Clear retry state on successful transcription
            retryAudioData = nil
            retryCount = 0

            // Story 5.1: Copy to clipboard (non-blocking fallback)
            // Clipboard errors are logged but don't fail transcription
            do {
                try clipboardService.copyText(text)
                print("✅ Copied \(text.count) characters to clipboard")
            } catch {
                print("⚠️ Clipboard copy failed: \(error.localizedDescription)")
                // Don't fail transcription if clipboard fails - user can still see text in UI
            }

            // Story 5.4: Auto-paste to active application (non-blocking)
            // Paste errors are logged and notified to user but don't fail transcription
            do {
                // Detect active application and check if it accepts text input
                if let activeApp = try activeAppDetector.getActiveApplication() {
                    print("ℹ️ Active app: \(activeApp.appName) (accepts text: \(activeApp.acceptsTextInput))")

                    // Only attempt paste if the active app has a text field focused
                    if activeApp.acceptsTextInput {
                        try pasteManager.paste(text)
                        print("✅ Pasted \(text.count) characters to \(activeApp.appName)")
                    } else {
                        print("ℹ️ Skipping paste - \(activeApp.appName) does not have text field focused")
                    }
                } else {
                    print("ℹ️ No active application detected - skipping paste")
                }
            } catch let error as ActiveAppError {
                // Handle ActiveAppDetector errors with user notification
                print("⚠️ Active app detection failed: \(error.localizedDescription)")
                if case .accessibilityPermissionDenied = error {
                    // Story 8.3 AC 3: Show user-friendly notification about accessibility fallback
                    print("⚠️ Accessibility permission denied - paste unavailable")
                    AlertHelper.showAccessibilityFallbackNotification()
                }
            } catch let error as PasteError {
                // Silent fallback: text is already on clipboard, no need to notify user
                // Paste errors are expected when apps don't support programmatic paste
                print("⚠️ Paste failed (silent fallback to clipboard): \(error.localizedDescription)")

                // Only show permission error if accessibility permission is missing
                if case .permissionDenied = error {
                    print("⚠️ Accessibility permission denied - paste unavailable")
                    AlertHelper.showAccessibilityFallbackNotification()
                }
                // All other paste errors are silent - user has text on clipboard
            } catch {
                // Catch any other unexpected errors (silent fallback)
                print("⚠️ Unexpected paste error (silent fallback to clipboard): \(error.localizedDescription)")
            }

            // Transition to success state
            recordingState = .success
            currentAmplitude = 0.0
            print("✅ Transcription successful: \(text.count) characters")

            // Auto-reset to idle after 2 seconds to allow next recording
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                // Only reset if still in success state (not if user started new recording)
                if case .success = self.recordingState {
                    self.recordingState = .idle
                    print("🔄 Auto-reset to idle state")
                }
            }
        } catch {
            // Error: update error state and transition to error
            print("❌ Transcription failed: \(error.localizedDescription)")

            // Enhanced logging for WhisperCppError (Story 12.1)
            if let whisperError = error as? WhisperCppError {
                print("   Error type: WhisperCppError")
                if let recovery = whisperError.recoverySuggestion {
                    print("   Recovery suggestion:")
                    print(recovery)
                }

                // Story 12.3: Store audio data for retry on WhisperCppError only
                // Only store if this is not already a retry (avoid overwriting)
                if retryAudioData == nil {
                    retryAudioData = audioData
                    retryCount = 0
                    print("💾 Stored audio data for retry (\(audioData.count) bytes)")
                }
            }

            lastError = error
            recordingState = .error(error)
            currentAmplitude = 0.0

            // Auto-reset to idle after 3 seconds to allow retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                // Only reset if still in error state (not if user started new recording)
                if case .error = self.recordingState {
                    self.recordingState = .idle
                    print("🔄 Auto-reset to idle state after error")
                }
            }
        }
    }

    /// Retry transcription with stored audio data
    ///
    /// Story 12.3: Allows user to retry transcription after fixing Local Whisper error
    /// Uses current profile settings (not original) in case user switched profiles
    /// Increments retry count and enforces 3-retry limit
    ///
    /// Thread safety: @MainActor ensures this runs on main thread for state updates
    @MainActor
    func retryTranscription() async {
        // Guard: Check if audio data exists for retry
        guard let audioData = retryAudioData else {
            print("⚠️ No audio data available for retry")
            return
        }

        // Guard: Check retry count limit
        guard retryCount < maxRetries else {
            print("⚠️ Retry limit reached (\(maxRetries) attempts)")
            return
        }

        // Increment retry count
        retryCount += 1
        print("🔄 Retry attempt \(retryCount) of \(maxRetries)...")

        // Update state to processing
        recordingState = .processing

        // Retry transcription with stored audio
        // Note: Uses current profile settings, not original
        lastRecordedAudio = audioData
        await transcribeAudio()
    }

    /// Check if retry is available
    ///
    /// Story 12.3: Used by MenuBarController to determine if Retry button should be shown
    /// Returns true if audio data exists and retry limit not reached
    var canRetry: Bool {
        retryAudioData != nil && retryCount < maxRetries
    }

    // MARK: - Tutorial Management (Story 8.4)

    /// Tracks if we've already shown congratulations for first recording
    /// Prevents showing it multiple times if recordingState changes
    private var hasShownCongratulations = false

    /// Set up observer for onboarding completion to show tutorial prompt
    ///
    /// Story 8.4 AC 1: When onboarding finishes (showOnboarding changes from true to false),
    /// check if tutorial has been completed. If not, show tutorial prompt.
    private func setupOnboardingCompletionObserver() {
        // Track previous value to detect true -> false transition
        var previousShowOnboarding = showOnboarding

        $showOnboarding
            .sink { [weak self] isShowing in
                guard let self = self else { return }

                // When onboarding closes (changes from true to false)
                // Reload active profile and show tutorial if needed
                if previousShowOnboarding && !isShowing {
                    // Reload active profile (user may have created one during onboarding)
                    do {
                        self.currentProfile = try self.profileManager.getActiveProfile()
                        if let profile = self.currentProfile {
                            print("✅ Reloaded active profile after onboarding: \(profile.name)")
                        }
                    } catch {
                        print("⚠️ No active profile found after onboarding")
                    }

                    // Show tutorial if it hasn't been completed yet
                    if !self.settings.tutorialCompleted {
                        // Small delay to allow onboarding window to fully dismiss
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.showTutorialPrompt = true
                            print("ℹ️ Onboarding complete - showing tutorial prompt")
                        }
                    }
                }

                previousShowOnboarding = isShowing
            }
            .store(in: &cancellables)

        // Also observe recordingState for first successful recording
        $recordingState
            .sink { [weak self] state in
                guard let self = self else { return }

                // Story 8.4 AC 2: Detect first successful recording
                if case .success = state,
                   !self.settings.tutorialCompleted,
                   !self.hasShownCongratulations {
                    self.showCongratulationsAndMarkTutorialComplete()
                }
            }
            .store(in: &cancellables)
    }

    /// Mark tutorial as completed and persist settings
    ///
    /// Story 8.4 AC 2: Set tutorialCompleted = true after first successful recording
    func markTutorialComplete() {
        guard !settings.tutorialCompleted else {
            print("ℹ️ Tutorial already marked complete")
            return
        }

        settings.tutorialCompleted = true
        settingsService.saveSettings(settings)
        print("✅ Tutorial marked complete - will not show again")
    }

    /// Save current settings to persistent storage
    ///
    /// Used during onboarding to persist language selection and other settings changes
    func saveSettings() throws {
        try settingsService.saveSettings(settings)
    }

    /// Show congratulations message and mark tutorial complete
    ///
    /// Story 8.4 AC 2: After first successful transcription, show congratulations
    /// and mark tutorial as completed
    private func showCongratulationsAndMarkTutorialComplete() {
        hasShownCongratulations = true

        // Mark tutorial complete first
        markTutorialComplete()

        // Show congratulations alert
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Great job!"
        alert.informativeText = """
        You've completed your first recording successfully!

        You're all set to use speech-to-clip. Press \(settings.hotkey.displayString) anytime to record and transcribe your voice.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Awesome!")

        alert.runModal()
        print("🎉 Congratulations message shown")
    }

    /// Cancellable subscriptions for Combine observers
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Future Methods

    // Methods for state management will be added in future stories:
    // - pasteText() - Epic 5
    // - switchProfile() - Epic 7
}
