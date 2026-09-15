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
/// Shows the growing transcript as speaker turns together with the signals
/// that let the user trust the capture: level meters for both sources, the
/// queue length and how long ago the latest text arrived.
struct MeetingTranscriptView: View {
    @ObservedObject var session: MeetingSession
    /// Called when "keep on top" is toggled
    let onPinnedChange: (Bool) -> Void

    @State private var autoScroll = true
    @State private var pinned = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            transcript
            Divider()
            footer
        }
        .frame(minWidth: 360, minHeight: 400)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(statusTitle)
                    .font(.headline)
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(elapsedText(at: context.date))
                        .font(.system(.title3, design: .monospaced))
                }
                Button(action: toggleMeeting) {
                    Text(session.state == .idle ? "Aloita" : "Lopeta")
                        .frame(minWidth: 60)
                }
                .buttonStyle(.borderedProminent)
                .tint(session.state == .idle ? Color.accentColor : Color.red)
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

            TextField("Sanasto: nimet ja termit pilkuilla eroteltuina", text: $session.vocabulary)
                .textFieldStyle(.roundedBorder)
                .font(.caption)
                .help("Kirjoitetaan transkriptin alkuun muistion koostamista varten, esim. Wärtsilä, CGI, Etteplan")

            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(progressText(at: context.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let error = session.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let status = session.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
    }

    // MARK: - Transcript

    private var transcript: some View {
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
            .onChange(of: session.segments.count) { _, _ in
                guard autoScroll, let last = session.turns.last else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle("Vieritä automaattisesti", isOn: $autoScroll)
                Toggle("Pidä päällimmäisenä", isOn: $pinned)
                    .onChange(of: pinned) { _, isPinned in
                        onPinnedChange(isPinned)
                    }
                Spacer()
            }
            .toggleStyle(.checkbox)
            .font(.caption)

            if let folder = session.folderURL {
                HStack {
                    Text(folder.path)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("Avaa kansio") {
                        let transcript = folder.appendingPathComponent(MeetingStorage.transcriptFileName)
                        NSWorkspace.shared.activateFileViewerSelecting([transcript])
                    }
                    .font(.caption)
                }
            }
        }
        .padding(12)
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch session.state {
        case .idle: return .secondary
        case .starting, .stopping: return .orange
        case .running: return .red
        }
    }

    private var statusTitle: String {
        switch session.state {
        case .idle: return session.startedAt == nil ? "Ei käynnissä" : "Päättynyt"
        case .starting: return "Käynnistetään…"
        case .running: return "Tallennetaan"
        case .stopping: return "Litteroidaan loppuun…"
        }
    }

    private var emptyText: String {
        session.state == .running
            ? "Teksti ilmestyy tähän muutaman sekunnin kuluttua puheesta."
            : "Aloita palaveri, niin transkripti muodostuu tähän."
    }

    private func elapsedText(at date: Date) -> String {
        guard let start = session.startedAt else { return "00:00:00" }
        let end = session.state == .running || session.state == .starting ? date : (session.endedAt ?? date)
        let total = max(0, Int(end.timeIntervalSince(start)))
        return String(format: "%02d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
    }

    private func progressText(at date: Date) -> String {
        var parts = ["Jonossa \(session.pendingCount)"]
        if let last = session.lastSegmentAt {
            parts.append("viimeisin teksti \(max(0, Int(date.timeIntervalSince(last)))) s sitten")
        } else if session.state == .running {
            parts.append("ei vielä tekstiä")
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

// MARK: - Speaker Colors

private extension MeetingSpeaker {
    var color: Color {
        switch self {
        case .me: return .blue
        case .others: return .green
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
            Text(speaker.rawValue)
                .font(.caption)
                .frame(width: 36, alignment: .leading)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isStalled ? Color.red : speaker.color)
                        .frame(width: geometry.size.width * displayLevel)
                }
            }
            .frame(height: 8)
            Text(stateText)
                .font(.caption2)
                .foregroundColor(isStalled || !isActive ? .red : .secondary)
                .frame(width: 70, alignment: .trailing)
        }
    }

    /// RMS mapped to a -50…0 dB scale
    private var displayLevel: CGFloat {
        guard level > 0 else { return 0 }
        let decibels = 20 * log10(Double(level))
        return CGFloat(min(1, max(0, (decibels + 50) / 50)))
    }

    private var stateText: String {
        if !isActive { return "ei käytössä" }
        return isStalled ? "ei ääntä" : "kuuntelee"
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
                Text(turn.speaker.rawValue)
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
