//
//  AppLog.swift
//  speech-to-clip
//
//  Created on 2026-10-03.
//  Unified log output for the dictation path
//

import Foundation
import os

/// Logging for the dictation path.
///
/// The app runs as a menu bar app (LSUIElement), so the `print` output of the
/// recording code goes nowhere once the app is launched from Finder. Two real
/// bugs - a silent tap format mismatch and a hotkey that appeared dead - could
/// only be guessed at because of that. These messages reach the unified log:
///
///     log show --predicate 'subsystem == "com.latentti.speech-to-clip"' --last 10m
///
/// Keep the messages free of transcribed text; the subsystem is readable by
/// anything on the machine.
nonisolated enum AppLog {
    /// Hotkey press, recording lifecycle and audio device problems
    static let dictation = Logger(subsystem: "com.latentti.speech-to-clip", category: "Dictation")
}
