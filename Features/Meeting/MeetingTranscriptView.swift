//
//  MeetingTranscriptView.swift
//  speech-to-clip
//
//  Created on 2026-09-15.
//  Meeting transcription: live transcript window content
//

import SwiftUI

/// Live view of a meeting transcript
///
/// Follows the look of the rest of the app: grouped sections with headline
/// titles and secondary captions, the lime green recording color used by the
/// menu bar icon and wave visualizer, yellow while audio is still being
/// processed, orange for warnings and red for errors.
struct MeetingTranscriptView: View {
    @ObservedObject var session: MeetingSession
    /// Called when "Keep window on top" is toggled
    let onPinnedChange: (Bool) -> Void

    @State private var autoScroll = true
    @State private var pinned = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            recordingSection
            vocabularySection
            transcriptSection
        }
        .padding()
        .frame(minWidth: 380, minHeight: 480)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Recording

    private var recordingSection: some View {
        MeetingSectionBox(title: "Recording") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: statusSymbol)
                        .foregroundColor(statusColor)
                    Text(statusTitle)
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(elapsedText(at: context.date))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Button(action: toggleMeeting) {
                        Text(session.state == .idle ? "Start" : "Stop")
                            .frame(minWidth: 60)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(session.state == .starting || session.state == .stopping)
                }

                LevelMeterRow(
                    speaker: .me,
                    level: session.micLevel,
                    isActive: session.isMicrophoneActive,
                    isStalled: session.microphoneStalled
                )
                LevelMeterRow(
                    speaker: .others,
                    level: session.systemLevel,
                    isActive: session.isSystemAudioActive,
                    isStalled: session.systemAudioStalled
                )

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(progressText(at: context.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let error = session.errorMessage {
                    HStack(alignment: .top, spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                if let status = session.statusMessage {
                    Text(status)
                        .font(.caption)
                        .foregroundColor(session.statusIsWarning ? .orange : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Vocabulary

    private var vocabularySection: some View {
        MeetingSectionBox(title: "Vocabulary") {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Names and terms, separated by commas", text: $session.vocabulary)
                    .textFieldStyle(.roundedBorder)
                Text("Written to the top of the transcript so that memo processing spells names correctly.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Transcript

    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Transcript")
                .font(.headline)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if session.turns.isEmpty {
                            Text(emptyText)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        }
                        ForEach(session.turns) { turn in
                            TurnRow(turn: turn, meetingStart: session.startedAt ?? Date())
                                .id(turn.id)
                        }
                    }
                    .padding(12)
                    .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
                .onChange(of: session.segments.count) { _, _ in
                    guard autoScroll, let last = session.turns.last else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }

            HStack {
                Toggle("Auto-scroll", isOn: $autoScroll)
                Toggle("Keep window on top", isOn: $pinned)
                    .onChange(of: pinned) { _, isPinned in
                        onPinnedChange(isPinned)
                    }
                Spacer()
                if let folder = session.folderURL {
                    Button("Show in Finder") {
                        let transcript = folder.appendingPathComponent(MeetingStorage.transcriptFileName)
                        NSWorkspace.shared.activateFileViewerSelecting([transcript])
                    }
                    .buttonStyle(.borderless)
                }
            }
            .toggleStyle(.checkbox)
            .font(.caption)

            if let folder = session.folderURL {
                Text(folder.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    // MARK: - Helpers

    private var statusSymbol: String {
        switch session.state {
        case .idle: return session.startedAt == nil ? "circle" : "checkmark.circle.fill"
        case .starting, .stopping: return "hourglass"
        case .running: return "record.circle.fill"
        }
    }

    private var statusColor: Color {
        switch session.state {
        case .idle: return session.startedAt == nil ? .secondary : .green
        case .starting, .stopping: return .yellow
        case .running: return MeetingPalette.recording
        }
    }

    private var statusTitle: String {
        switch session.state {
        case .idle: return session.startedAt == nil ? "Not recording" : "Finished"
        case .starting: return "Starting…"
        case .running: return "Recording"
        case .stopping: return "Transcribing remaining audio…"
        }
    }

    private var emptyText: String {
        session.state == .running
            ? "Text appears here a few seconds after someone speaks."
            : "Start a meeting to see its transcript here."
    }

    private func elapsedText(at date: Date) -> String {
        guard let start = session.startedAt else { return "00:00:00" }
        let end = session.state == .running || session.state == .starting ? date : (session.endedAt ?? date)
        let total = max(0, Int(end.timeIntervalSince(start)))
        return String(format: "%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }

    private func progressText(at date: Date) -> String {
        var parts = ["Queue: \(session.pendingCount)"]
        if let last = session.lastSegmentAt {
            parts.append("latest text \(max(0, Int(date.timeIntervalSince(last)))) s ago")
        } else if session.state == .running {
            parts.append("no text yet")
        }
        return parts.joined(separator: " · ")
    }

    private func toggleMeeting() {
        switch session.state {
        case .idle:
            Task { await session.start() }
        case .running:
            session.stop()
        case .starting, .stopping:
            break
        }
    }
}

// MARK: - Palette

/// Colors shared with the rest of the app
enum MeetingPalette {
    /// Recording color of the menu bar icon (#32CD32)
    static let recording = Color(red: 0.196, green: 0.804, blue: 0.196)
}

private extension MeetingSpeaker {
    var symbolName: String {
        switch self {
        case .me: return "mic.fill"
        case .others: return "speaker.wave.2.fill"
        }
    }

    var color: Color {
        switch self {
        case .me: return .accentColor
        case .others: return .secondary
        }
    }
}

// MARK: - Section Box

/// Titled rounded box matching the grouped sections of the Settings window
private struct MeetingSectionBox<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            content
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
        }
    }
}

// MARK: - Level Meter Row

private struct LevelMeterRow: View {
    let speaker: MeetingSpeaker
    let level: Float
    let isActive: Bool
    let isStalled: Bool

    var body: some View {
        HStack(spacing: 8) {
            Label(speaker.rawValue, systemImage: speaker.symbolName)
                .font(.caption)
                .foregroundColor(speaker.color)
                .frame(width: 70, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isStalled ? Color.red : MeetingPalette.recording)
                        .frame(width: geometry.size.width * displayLevel)
                }
            }
            .frame(height: 8)
            Text(stateText)
                .font(.caption2)
                .foregroundColor(isStalled ? .red : .secondary)
                .frame(width: 60, alignment: .trailing)
        }
    }

    /// RMS mapped to a -50…0 dB scale
    private var displayLevel: CGFloat {
        guard level > 0 else { return 0 }
        let decibels = 20 * log10(Double(level))
        return CGFloat(min(1, max(0, (decibels + 50) / 50)))
    }

    private var stateText: String {
        if !isActive { return "off" }
        return isStalled ? "no audio" : "listening"
    }
}

// MARK: - Turn Row

private struct TurnRow: View {
    let turn: TranscriptTurn
    let meetingStart: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(timeText)
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                Label(turn.speaker.rawValue, systemImage: turn.speaker.symbolName)
                    .font(.caption.bold())
                    .foregroundColor(turn.speaker.color)
            }
            Text(turn.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: meetingStart.addingTimeInterval(turn.startTime))
    }
}
