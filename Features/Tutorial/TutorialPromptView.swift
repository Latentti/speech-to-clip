//
//  TutorialPromptView.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-15.
//  Story 8.4: Implement First Recording Tutorial
//

import SwiftUI

/// Tutorial prompt view shown after onboarding completion
///
/// Displays "Try it now!" guidance with:
/// - Current hotkey (formatted as ⌃ Space)
/// - Step-by-step instructions
/// - What to expect (visualizer, transcription, paste)
///
/// Story 8.4 AC 1: Tutorial prompt after onboarding
struct TutorialPromptView: View {
    let hotkey: HotkeyConfig
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Header icon and title
            VStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)

                Text("Try it now!")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding(.top, 16)

            // Hotkey display
            VStack(spacing: 6) {
                Text("Your hotkey:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(hotkey.displayString)
                    .font(.system(size: 28, weight: .medium, design: .rounded))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.accentColor.opacity(0.1))
                    )
            }

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(
                    number: 1,
                    icon: "mic.fill",
                    text: "Press \(hotkey.displayString) to start recording"
                )

                InstructionRow(
                    number: 2,
                    icon: "waveform",
                    text: "Speak your message clearly"
                )

                InstructionRow(
                    number: 3,
                    icon: "mic.slash.fill",
                    text: "Press \(hotkey.displayString) again to stop"
                )

                InstructionRow(
                    number: 4,
                    icon: "doc.on.clipboard.fill",
                    text: "Your transcribed text will be pasted automatically"
                )
            }
            .padding(.horizontal, 16)

            // What to expect
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("What to expect")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }

                Text("When you stop recording, your speech will be transcribed using Whisper AI and automatically pasted into your active application.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)

            Spacer()

            // Dismiss button
            Button(action: onDismiss) {
                Text("Let's try it!")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 500, height: 560)
    }
}

// MARK: - Instruction Row Component

struct InstructionRow: View {
    let number: Int
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            // Step number badge
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 28, height: 28)

                Text("\(number)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.accentColor)
            }

            // Icon and text
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                    .frame(width: 18)

                Text(text)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    TutorialPromptView(
        hotkey: .default,
        onDismiss: {
            print("Tutorial dismissed")
        }
    )
}
