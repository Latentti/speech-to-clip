//
//  OnboardingView.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-15.
//  Story 8.2: Create Onboarding Flow
//

import SwiftUI

/// Multi-step onboarding view for first-time users
///
/// Displays a 5-step guided flow:
/// 1. Welcome and app explanation
/// 2. Microphone permission request
/// 3. Accessibility permission request
/// 4. API key profile setup
/// 5. Success confirmation
struct OnboardingView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(0..<5) { index in
                    Circle()
                        .fill(index == coordinator.currentStep ? Color.accentColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Step content
            TabView(selection: $coordinator.currentStep) {
                WelcomeStepView(coordinator: coordinator)
                    .tag(0)

                MicrophoneStepView(coordinator: coordinator)
                    .tag(1)

                AccessibilityStepView(coordinator: coordinator)
                    .tag(2)

                APIKeyStepView(coordinator: coordinator)
                    .tag(3)

                SuccessStepView(coordinator: coordinator, dismiss: dismiss)
                    .tag(4)
            }
            .tabViewStyle(.automatic)
            .frame(width: 500, height: 400)
        }
        .frame(width: 500, height: 480)
    }
}

// MARK: - Step 1: Welcome

struct WelcomeStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App icon
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .cornerRadius(16)

            Text("Welcome to Speech-to-Clip")
                .font(.title)
                .fontWeight(.bold)

            Text("Transform your voice into text instantly with global hotkey-activated transcription.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    Text("Press hotkey to record your voice")
                }
                HStack {
                    Image(systemName: "waveform")
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    Text("Watch the Matrix visualizer come alive")
                }
                HStack {
                    Image(systemName: "doc.on.clipboard.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    Text("Transcribed text auto-pastes to your cursor")
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 60)

            Spacer()

            HStack {
                Button("Skip") {
                    coordinator.skip()
                }
                .buttonStyle(.link)

                Spacer()

                Button("Get Started") {
                    coordinator.moveToNextStep()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Step 2: Microphone Permission

struct MicrophoneStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var isRequestingPermission = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "mic.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Microphone Access")
                .font(.title2)
                .fontWeight(.bold)

            Text("Speech-to-Clip needs access to your microphone to record your voice for transcription.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            // Permission status
            Group {
                switch coordinator.microphonePermissionStatus {
                case .notDetermined:
                    Button(isRequestingPermission ? "Requesting..." : "Grant Microphone Access") {
                        Task {
                            isRequestingPermission = true
                            await coordinator.requestMicrophonePermission()
                            isRequestingPermission = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isRequestingPermission)

                case .authorized:
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Microphone access granted")
                            .foregroundColor(.secondary)
                    }

                case .denied:
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Text("Microphone access denied")
                                .foregroundColor(.secondary)
                        }
                        Button("Open System Settings") {
                            coordinator.openSystemSettings(for: .microphone)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                case .restricted:
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Microphone access restricted by system")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            HStack {
                Button("Back") {
                    coordinator.moveToPreviousStep()
                }
                .buttonStyle(.link)

                Button("Skip") {
                    coordinator.skip()
                }
                .buttonStyle(.link)

                Spacer()

                Button("Continue") {
                    coordinator.moveToNextStep()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Step 3: Accessibility Permission

struct AccessibilityStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "hand.tap.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Accessibility Access")
                .font(.title2)
                .fontWeight(.bold)

            Text("To automatically paste transcribed text, Speech-to-Clip needs accessibility permissions.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 8) {
                Text("Note: macOS requires manual approval for accessibility features.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 40)
            }

            // Permission status
            Group {
                switch coordinator.accessibilityPermissionStatus {
                case .notDetermined, .denied:
                    VStack(spacing: 12) {
                        if coordinator.accessibilityPermissionStatus == .denied {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.orange)
                                Text("Accessibility access not granted")
                                    .foregroundColor(.secondary)
                            }
                        }

                        Button("Open System Settings") {
                            coordinator.openSystemSettings(for: .accessibility)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Text("Once granted, click 'Refresh Status' below")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Refresh Status") {
                            coordinator.refreshPermissions()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                case .authorized:
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Accessibility access granted")
                            .foregroundColor(.secondary)
                    }

                case .restricted:
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Accessibility access restricted by system")
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            HStack {
                Button("Back") {
                    coordinator.moveToPreviousStep()
                }
                .buttonStyle(.link)

                Button("Skip") {
                    coordinator.skip()
                }
                .buttonStyle(.link)

                Spacer()

                Button("Continue") {
                    coordinator.moveToNextStep()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Step 4: API Key Setup

struct APIKeyStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var apiKey: String = ""
    @State private var profileName: String = "Default Profile"
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("OpenAI API Key")
                .font(.title2)
                .fontWeight(.bold)

            Text("Enter your OpenAI API key to enable Whisper transcription.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 12) {
                Text("Profile Name")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("e.g., Default Profile", text: $profileName)
                    .textFieldStyle(.roundedBorder)

                Text("API Key")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SecureField("sk-...", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                if showError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, 60)

            Link("Get an API key from OpenAI", destination: URL(string: "https://platform.openai.com/api-keys")!)
                .font(.caption)

            Spacer()

            HStack {
                Button("Back") {
                    coordinator.moveToPreviousStep()
                }
                .buttonStyle(.link)

                Button("Skip for Now") {
                    coordinator.skip()
                }
                .buttonStyle(.link)

                Spacer()

                Button(coordinator.hasAPIKey ? "Continue" : "Save & Continue") {
                    if apiKey.isEmpty {
                        // Allow skipping without API key
                        coordinator.moveToNextStep()
                    } else {
                        // Save API key
                        do {
                            try coordinator.saveAPIKey(apiKey, profileName: profileName)
                            showError = false
                            coordinator.moveToNextStep()
                        } catch {
                            showError = true
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .onAppear {
            coordinator.refreshAPIKeyStatus()
        }
    }
}

// MARK: - Step 5: Success

struct SuccessStepView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("You're All Set!")
                .font(.title)
                .fontWeight(.bold)

            Text("Speech-to-Clip is ready to use. Press your hotkey to start recording.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "command")
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    Text("Default hotkey: Control+Space")
                }
                HStack {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.accentColor)
                        .frame(width: 24)
                    Text("Customize settings from the menu bar")
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 60)

            Spacer()

            HStack {
                Spacer()

                Button("Get Started") {
                    coordinator.complete()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Spacer()
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(coordinator: OnboardingCoordinator.preview)
    }
}
#endif
