//
//  ProfilesTab.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 7.3: Implement Profiles Settings Tab
//

import SwiftUI

/// Profiles settings tab for managing API key profiles
///
/// This view provides controls for:
/// - Viewing all profiles with active indicator
/// - Adding new profiles (name, API key, language)
/// - Editing existing profiles
/// - Deleting profiles with confirmation
/// - Switching active profile
///
/// All profile operations use ProfileManager service and auto-persist
/// to UserDefaults (metadata) and Keychain (API keys).
///
/// - Note: Story 7.3 - Profiles settings tab UI
/// - Note: Story 7.2 - ProfileManager and Profile model
struct ProfilesTab: View {
    // MARK: - Properties

    /// Reference to app state for settings binding
    @EnvironmentObject var appState: AppState

    /// Profile manager for CRUD operations
    private let profileManager = ProfileManager()

    /// List of all profiles
    @State private var profiles: [Profile] = []

    /// Currently active profile
    @State private var activeProfile: Profile?

    /// Sheet state for adding new profile
    @State private var showingAddSheet = false

    /// Alert state for delete confirmation
    @State private var showingDeleteAlert = false

    /// Alert state for errors
    @State private var showingErrorAlert = false

    /// Error message to display
    @State private var errorMessage = ""

    /// Profile selected for editing (using item-based sheet)
    @State private var editingProfile: Profile?

    /// Profile selected for deletion
    @State private var profileToDelete: Profile?

    // MARK: - Body

    var body: some View {
        Form {
            // MARK: Profile List

            Section {
                if profiles.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("No profiles yet")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Text("Create a profile to store your API key and preferences")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    // Profile list
                    ForEach(profiles) { profile in
                        profileRow(for: profile)
                    }
                }

                // Add Profile button
                Button(action: {
                    showingAddSheet = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Profile")
                    }
                }
                .buttonStyle(.borderless)
                .padding(.top, 8)
            } header: {
                Text("API Key Profiles")
                    .font(.headline)
            } footer: {
                Text("Profiles store your OpenAI API key and default language. Click a profile to make it active.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding()
        .onAppear {
            loadProfiles()
        }
        .sheet(isPresented: $showingAddSheet) {
            AddProfileSheet(
                profileManager: profileManager,
                onProfileCreated: {
                    loadProfiles()
                },
                onError: { error in
                    errorMessage = error
                    showingErrorAlert = true
                }
            )
        }
        .sheet(item: $editingProfile) { profile in
            EditProfileSheet(
                profile: profile,
                profileManager: profileManager,
                onProfileUpdated: {
                    loadProfiles()
                },
                onError: { error in
                    errorMessage = error
                    showingErrorAlert = true
                }
            )
        }
        .alert("Delete Profile?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    deleteProfile(profile)
                }
            }
        } message: {
            if let profile = profileToDelete {
                Text("Are you sure you want to delete '\(profile.name)'? This action cannot be undone.")
            }
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Views

    /// Profile row view with active indicator and action buttons
    @ViewBuilder
    private func profileRow(for profile: Profile) -> some View {
        HStack(spacing: 12) {
            // Active indicator
            Button(action: {
                setActiveProfile(profile)
            }) {
                Image(systemName: profile.id == activeProfile?.id ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(profile.id == activeProfile?.id ? .accentColor : .secondary)
                    .font(.system(size: 20))
            }
            .buttonStyle(.borderless)
            .help("Set as active profile")

            // Profile info
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.body)

                Text(WhisperLanguage(rawValue: profile.language)?.displayName ?? profile.language)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Engine indicator
            Image(systemName: profile.transcriptionEngine == .openai ? "cloud" : "desktopcomputer")
                .font(.caption)
                .foregroundColor(.secondary)
                .help(profile.transcriptionEngine.rawValue)

            // Action buttons
            Button("Edit") {
                print("🔍 Edit button clicked for profile: \(profile.name), id: \(profile.id)")
                editingProfile = profile
                print("🔍 editingProfile set to: \(editingProfile?.name ?? "nil")")
            }
            .buttonStyle(.borderless)

            Button("Delete") {
                profileToDelete = profile
                showingDeleteAlert = true
            }
            .buttonStyle(.borderless)
            .foregroundColor(.red)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    /// Loads all profiles from ProfileManager
    private func loadProfiles() {
        do {
            profiles = try profileManager.getAllProfiles()
            activeProfile = try profileManager.getActiveProfile()
            print("✅ Loaded \(profiles.count) profiles")
        } catch {
            print("❌ Failed to load profiles: \(error.localizedDescription)")
            errorMessage = "Failed to load profiles: \(error.localizedDescription)"
            showingErrorAlert = true
        }
    }

    /// Sets the specified profile as active
    private func setActiveProfile(_ profile: Profile) {
        do {
            try profileManager.setActiveProfile(id: profile.id)
            activeProfile = profile

            // Update AppState.currentProfile so transcription uses the correct profile
            appState.currentProfile = profile

            // Story 12.3: Clear retry state on profile switch
            // Prevents retrying with wrong profile's audio data
            appState.retryAudioData = nil
            appState.retryCount = 0

            print("✅ Set active profile: \(profile.name)")
        } catch {
            print("❌ Failed to set active profile: \(error.localizedDescription)")
            if let profileError = error as? ProfileError {
                errorMessage = profileError.errorDescription ?? "Failed to set active profile"
                if let suggestion = profileError.recoverySuggestion {
                    errorMessage += "\n\n\(suggestion)"
                }
            } else {
                errorMessage = "Failed to set active profile: \(error.localizedDescription)"
            }
            showingErrorAlert = true
        }
    }

    /// Deletes the specified profile
    private func deleteProfile(_ profile: Profile) {
        do {
            try profileManager.deleteProfile(id: profile.id)
            print("✅ Deleted profile: \(profile.name)")
            loadProfiles()
        } catch {
            print("❌ Failed to delete profile: \(error.localizedDescription)")
            if let profileError = error as? ProfileError {
                errorMessage = profileError.errorDescription ?? "Failed to delete profile"
                if let suggestion = profileError.recoverySuggestion {
                    errorMessage += "\n\n\(suggestion)"
                }
            } else {
                errorMessage = "Failed to delete profile: \(error.localizedDescription)"
            }
            showingErrorAlert = true
        }
    }
}

// MARK: - Add Profile Sheet

/// Sheet view for adding a new profile
private struct AddProfileSheet: View {
    // MARK: - Properties

    let profileManager: ProfileManager
    let onProfileCreated: () -> Void
    let onError: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var profileName = ""
    @State private var apiKey = ""
    @State private var selectedLanguage = "en"
    @State private var transcriptionEngine: TranscriptionEngine = .openai
    @State private var whisperModelName = ""
    @State private var whisperServerPort = 8080

    @FocusState private var focusedField: Field?

    private enum Field {
        case name, apiKey, modelName, serverPort
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Profile")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Form
            Form {
                Section {
                    TextField("Profile Name", text: $profileName)
                        .focused($focusedField, equals: .name)

                    Picker("Language:", selection: $selectedLanguage) {
                        ForEach(WhisperLanguage.sortedByDisplayName) { language in
                            Text(language.displayName)
                                .tag(language.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Transcription Engine:", selection: $transcriptionEngine) {
                        ForEach(TranscriptionEngine.allCases, id: \.self) { engine in
                            Label(engine.rawValue, systemImage: engine == .openai ? "cloud" : "desktopcomputer")
                                .tag(engine)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // OpenAI Configuration
                if transcriptionEngine == .openai {
                    Section {
                        SecureField("API Key", text: $apiKey)
                            .focused($focusedField, equals: .apiKey)
                    } header: {
                        Text("OpenAI Configuration")
                    } footer: {
                        Text("Your API key is securely stored in the system Keychain")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Local Whisper Configuration
                if transcriptionEngine == .localWhisper {
                    Section {
                        TextField("Model Name (optional)", text: $whisperModelName)
                            .focused($focusedField, equals: .modelName)
                            .help("e.g., base, medium, large")

                        TextField("Server Port", value: $whisperServerPort, format: .number)
                            .focused($focusedField, equals: .serverPort)
                            .help("Default: 8080")

                        Text("For less common languages, Medium or Large models recommended")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Local Whisper Configuration")
                    }
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer buttons
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Add") {
                    addProfile()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(!isValid)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 450, height: 300)
        .onAppear {
            focusedField = .name
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        let nameValid = !profileName.trimmingCharacters(in: .whitespaces).isEmpty

        // API Key required only for OpenAI
        if transcriptionEngine == .openai {
            return nameValid && !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            // For Local Whisper, only name is required
            return nameValid
        }
    }

    // MARK: - Actions

    private func addProfile() {
        let trimmedName = profileName.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            onError("Profile name cannot be empty")
            return
        }

        // Validate API key for OpenAI
        let trimmedKey: String
        if transcriptionEngine == .openai {
            trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)
            guard !trimmedKey.isEmpty else {
                onError("API key cannot be empty for OpenAI transcription")
                return
            }
        } else {
            // For Local Whisper, use a placeholder API key
            trimmedKey = "local-whisper-placeholder"
        }

        // Convert empty model name to nil
        let modelName = whisperModelName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : whisperModelName.trimmingCharacters(in: .whitespaces)

        do {
            _ = try profileManager.createProfile(
                name: trimmedName,
                apiKey: trimmedKey,
                language: selectedLanguage,
                transcriptionEngine: transcriptionEngine,
                whisperModelName: modelName,
                whisperServerPort: whisperServerPort
            )
            print("✅ Created profile: \(trimmedName) with engine: \(transcriptionEngine.rawValue)")
            dismiss()
            onProfileCreated()
        } catch {
            print("❌ Failed to create profile: \(error.localizedDescription)")
            dismiss()

            if let profileError = error as? ProfileError {
                var message = profileError.errorDescription ?? "Failed to create profile"
                if let suggestion = profileError.recoverySuggestion {
                    message += "\n\n\(suggestion)"
                }
                onError(message)
            } else {
                onError("Failed to create profile: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Edit Profile Sheet

/// Sheet view for editing an existing profile
private struct EditProfileSheet: View {
    // MARK: - Properties

    let profile: Profile
    let profileManager: ProfileManager
    let onProfileUpdated: () -> Void
    let onError: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var profileName: String
    @State private var apiKey = ""
    @State private var selectedLanguage: String
    @State private var updateApiKey = false
    @State private var transcriptionEngine: TranscriptionEngine
    @State private var whisperModelName: String
    @State private var whisperServerPort: Int

    @FocusState private var focusedField: Field?

    private enum Field {
        case name, apiKey, modelName, serverPort
    }

    // MARK: - Initialization

    init(profile: Profile, profileManager: ProfileManager, onProfileUpdated: @escaping () -> Void, onError: @escaping (String) -> Void) {
        self.profile = profile
        self.profileManager = profileManager
        self.onProfileUpdated = onProfileUpdated
        self.onError = onError

        // Initialize state with profile values
        _profileName = State(initialValue: profile.name)
        _selectedLanguage = State(initialValue: profile.language)
        _transcriptionEngine = State(initialValue: profile.transcriptionEngine)
        _whisperModelName = State(initialValue: profile.whisperModelName ?? "")
        _whisperServerPort = State(initialValue: profile.whisperServerPort)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Edit Profile: \(profile.name)")
                    .font(.headline)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Form
            Form {
                Section {
                    TextField("Profile Name", text: $profileName)
                        .focused($focusedField, equals: .name)

                    Picker("Language:", selection: $selectedLanguage) {
                        ForEach(WhisperLanguage.sortedByDisplayName) { language in
                            Text(language.displayName)
                                .tag(language.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Transcription Engine:", selection: $transcriptionEngine) {
                        ForEach(TranscriptionEngine.allCases, id: \.self) { engine in
                            Label(engine.rawValue, systemImage: engine == .openai ? "cloud" : "desktopcomputer")
                                .tag(engine)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // OpenAI Configuration
                if transcriptionEngine == .openai {
                    Section {
                        Toggle("Update API Key", isOn: $updateApiKey)

                        if updateApiKey {
                            SecureField("New API Key", text: $apiKey)
                                .focused($focusedField, equals: .apiKey)
                        }
                    } header: {
                        Text("OpenAI Configuration")
                    } footer: {
                        Text("Leave 'Update API Key' off to keep the existing API key unchanged")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Local Whisper Configuration
                if transcriptionEngine == .localWhisper {
                    Section {
                        TextField("Model Name (optional)", text: $whisperModelName)
                            .focused($focusedField, equals: .modelName)
                            .help("e.g., base, medium, large")

                        TextField("Server Port", value: $whisperServerPort, format: .number)
                            .focused($focusedField, equals: .serverPort)
                            .help("Default: 8080")

                        Text("For less common languages, Medium or Large models recommended")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } header: {
                        Text("Local Whisper Configuration")
                    }
                }
            }
            .formStyle(.grouped)
            .padding()

            Divider()

            // Footer buttons
            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])

                Button("Save") {
                    updateProfile()
                }
                .keyboardShortcut(.return, modifiers: [])
                .disabled(!isValid)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(width: 500, height: 400)
        .onAppear {
            print("🔍 EditProfileSheet appeared for profile: \(profile.name), language: \(profile.language)")
            print("🔍 Initial values - name: \(profileName), language: \(selectedLanguage)")
            focusedField = .name
        }
    }

    // MARK: - Validation

    private var isValid: Bool {
        let nameValid = !profileName.trimmingCharacters(in: .whitespaces).isEmpty

        // For OpenAI: validate API key if updating
        if transcriptionEngine == .openai {
            let keyValid = !updateApiKey || !apiKey.trimmingCharacters(in: .whitespaces).isEmpty
            return nameValid && keyValid
        } else {
            // For Local Whisper, only name is required
            return nameValid
        }
    }

    // MARK: - Actions

    private func updateProfile() {
        let trimmedName = profileName.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            onError("Profile name cannot be empty")
            return
        }

        // Validate API key if updating for OpenAI
        if transcriptionEngine == .openai && updateApiKey {
            let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)
            guard !trimmedKey.isEmpty else {
                onError("API key cannot be empty for OpenAI transcription")
                return
            }
        }

        // Convert empty model name to nil
        let modelName = whisperModelName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : whisperModelName.trimmingCharacters(in: .whitespaces)

        do {
            try profileManager.updateProfile(
                id: profile.id,
                name: trimmedName,
                apiKey: updateApiKey ? apiKey.trimmingCharacters(in: .whitespaces) : nil,
                language: selectedLanguage,
                transcriptionEngine: transcriptionEngine,
                whisperModelName: modelName,
                whisperServerPort: whisperServerPort
            )
            print("✅ Updated profile: \(trimmedName) with engine: \(transcriptionEngine.rawValue)")
            dismiss()
            onProfileUpdated()
        } catch {
            print("❌ Failed to update profile: \(error.localizedDescription)")
            dismiss()

            if let profileError = error as? ProfileError {
                var message = profileError.errorDescription ?? "Failed to update profile"
                if let suggestion = profileError.recoverySuggestion {
                    message += "\n\n\(suggestion)"
                }
                onError(message)
            } else {
                onError("Failed to update profile: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Preview

struct ProfilesTab_Previews: PreviewProvider {
    static var previews: some View {
        ProfilesTab()
            .environmentObject(AppState())
            .frame(width: 600, height: 400)
    }
}
