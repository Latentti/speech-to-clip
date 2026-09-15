//
//  MeetingWindowController.swift
//  speech-to-clip
//
//  Created on 2026-09-15.
//  Meeting transcription: live transcript window
//

import AppKit
import SwiftUI

/// Owns the live meeting transcript window
///
/// The window is created on first use and kept when closed, so the transcript
/// of the latest meeting stays available. Size and position are remembered.
final class MeetingWindowController {
    private static let frameAutosaveName = "MeetingTranscriptWindow"

    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Palaverin transkripti"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 360, height: 400)

        let view = MeetingTranscriptView(session: .shared) { [weak window] pinned in
            window?.level = pinned ? .floating : .normal
        }
        window.contentView = NSHostingView(rootView: view)

        if !window.setFrameUsingName(Self.frameAutosaveName) {
            window.center()
        }
        window.setFrameAutosaveName(Self.frameAutosaveName)

        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
