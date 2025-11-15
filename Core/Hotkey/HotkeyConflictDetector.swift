//
//  HotkeyConflictDetector.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 6.3: Implement Hotkey Capture Control
//

import Foundation
import AppKit
import HotKey

/// Detects conflicts between proposed hotkeys and system shortcuts
///
/// Checks hotkey combinations against known macOS system shortcuts
/// and returns appropriate warnings or blocks for hard conflicts.
struct HotkeyConflictDetector {
    // MARK: - Conflict Types

    enum ConflictResult: Equatable {
        case none
        case warning(String)
        case blocked(String)
    }

    // MARK: - Hard Conflicts (Never Allow)

    /// System shortcuts that should never be overridden
    private static let hardConflicts: [(Key, NSEvent.ModifierFlags, String)] = [
        (.q, .command, "Quit Application (⌘Q)"),
        (.w, .command, "Close Window (⌘W)"),
        (.tab, .command, "Application Switcher (⌘Tab)"),
    ]

    // MARK: - Soft Conflicts (Warn But Allow)

    /// System shortcuts that can be overridden but should warn user
    private static let softConflicts: [(Key, NSEvent.ModifierFlags, String)] = [
        (.space, .command, "Spotlight Search (⌘Space)"),
        (.upArrow, .control, "Mission Control (⌃↑)"),
        (.downArrow, .control, "Application Windows (⌃↓)"),
        (.leftArrow, .control, "Move Left a Space (⌃←)"),
        (.rightArrow, .control, "Move Right a Space (⌃→)"),
        (.h, .command, "Hide Window (⌘H)"),
        (.m, .command, "Minimize Window (⌘M)"),
    ]

    // MARK: - Conflict Detection

    /// Detect conflicts for a given hotkey combination
    ///
    /// - Parameters:
    ///   - key: The main key for the hotkey
    ///   - modifiers: The modifier flags
    /// - Returns: ConflictResult indicating severity
    func detectConflict(key: Key, modifiers: NSEvent.ModifierFlags) -> ConflictResult {
        // Normalize modifiers (remove device-dependent flags)
        let normalizedModifiers = modifiers.intersection([.command, .option, .control, .shift])

        // Check hard conflicts first
        for (conflictKey, conflictModifiers, description) in Self.hardConflicts {
            if key == conflictKey && normalizedModifiers == conflictModifiers {
                return .blocked("This shortcut conflicts with \(description), which cannot be overridden.")
            }
        }

        // Check soft conflicts
        for (conflictKey, conflictModifiers, description) in Self.softConflicts {
            if key == conflictKey && normalizedModifiers == conflictModifiers {
                return .warning("This shortcut conflicts with \(description). The system shortcut will be overridden if you continue.")
            }
        }

        // Multi-modifier combinations are generally safe
        let modifierCount = [
            normalizedModifiers.contains(.command),
            normalizedModifiers.contains(.option),
            normalizedModifiers.contains(.control),
            normalizedModifiers.contains(.shift)
        ].filter { $0 }.count

        if modifierCount >= 3 {
            return .none // Very unlikely to conflict
        }

        // No known conflicts
        return .none
    }
}
