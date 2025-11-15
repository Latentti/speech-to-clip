//
//  HotkeyConfig.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 6.3: Implement Hotkey Capture Control
//

import Foundation
import AppKit
import HotKey

/// Configuration for a global hotkey
///
/// Stores the key and modifiers for a customizable global hotkey.
/// Codable conformance enables persistence via UserDefaults (Story 6.4).
/// Default value matches current hardcoded hotkey: Control+Space.
struct HotkeyConfig: Codable, Equatable {
    // MARK: - Properties

    /// The main key for the hotkey (e.g., .space, .a, .f1)
    var key: Key

    /// The modifier flags (Command, Option, Control, Shift)
    var modifiers: NSEvent.ModifierFlags

    // MARK: - Default Configuration

    /// Default hotkey: Control+Space (matching Story 2.1 hardcoded value)
    static let `default` = HotkeyConfig(
        key: .space,
        modifiers: .control
    )

    // MARK: - Initialization

    init(key: Key, modifiers: NSEvent.ModifierFlags) {
        self.key = key
        self.modifiers = modifiers
    }

    // MARK: - Codable Conformance

    enum CodingKeys: String, CodingKey {
        case keyCode
        case modifierFlags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Decode key code as UInt32 (Carbon keycode)
        let keyCode = try container.decode(UInt32.self, forKey: .keyCode)
        guard let key = Key(carbonKeyCode: keyCode) else {
            throw DecodingError.dataCorruptedError(
                forKey: .keyCode,
                in: container,
                debugDescription: "Invalid Carbon keycode: \(keyCode)"
            )
        }
        self.key = key

        // Decode modifier flags as UInt (OptionSet rawValue)
        let modifierRawValue = try container.decode(UInt.self, forKey: .modifierFlags)
        self.modifiers = NSEvent.ModifierFlags(rawValue: modifierRawValue)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // Encode key as Carbon keycode
        try container.encode(key.carbonKeyCode, forKey: .keyCode)

        // Encode modifiers as OptionSet rawValue
        try container.encode(modifiers.rawValue, forKey: .modifierFlags)
    }

    // MARK: - Display Representation

    /// Human-readable string representation with modifier symbols
    /// Example: "⌃ Space", "⌘⌥⌃ A"
    var displayString: String {
        var components: [String] = []

        // Add modifier symbols in standard order
        if modifiers.contains(.control) {
            components.append("⌃")
        }
        if modifiers.contains(.option) {
            components.append("⌥")
        }
        if modifiers.contains(.shift) {
            components.append("⇧")
        }
        if modifiers.contains(.command) {
            components.append("⌘")
        }

        // Add key name
        components.append(key.displayName)

        return components.joined(separator: " ")
    }
}

// MARK: - Key Extension

extension Key {
    /// Human-readable name of the key
    var displayName: String {
        // Common keys with readable names
        switch self {
        case .space: return "Space"
        case .return: return "Return"
        case .tab: return "Tab"
        case .delete: return "Delete"
        case .escape: return "Escape"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        case .f1: return "F1"
        case .f2: return "F2"
        case .f3: return "F3"
        case .f4: return "F4"
        case .f5: return "F5"
        case .f6: return "F6"
        case .f7: return "F7"
        case .f8: return "F8"
        case .f9: return "F9"
        case .f10: return "F10"
        case .f11: return "F11"
        case .f12: return "F12"
        case .f13: return "F13"
        case .f14: return "F14"
        case .f15: return "F15"
        case .f16: return "F16"
        case .f17: return "F17"
        case .f18: return "F18"
        case .f19: return "F19"
        case .f20: return "F20"
        default:
            // For letter/number keys, use uppercased character representation
            // The HotKey library's Key enum cases match their character names
            return "\(self)".uppercased()
        }
    }
}
