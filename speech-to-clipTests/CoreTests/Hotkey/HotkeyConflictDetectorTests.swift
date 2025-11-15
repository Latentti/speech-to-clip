//
//  HotkeyConflictDetectorTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 6.3: Implement Hotkey Capture Control
//

import XCTest
import AppKit
import HotKey
@testable import speech_to_clip

final class HotkeyConflictDetectorTests: XCTestCase {
    var detector: HotkeyConflictDetector!

    override func setUp() {
        super.setUp()
        detector = HotkeyConflictDetector()
    }

    override func tearDown() {
        detector = nil
        super.tearDown()
    }

    // MARK: - Hard Conflict Tests (Blocked)

    func testDetectConflict_CommandQ_ReturnsBlocked() {
        // Arrange
        let key: Key = .q
        let modifiers: NSEvent.ModifierFlags = .command

        // Act
        let result = detector.detectConflict(key: key, modifiers: modifiers)

        // Assert
        if case .blocked(let message) = result {
            XCTAssertTrue(message.contains("Quit"))
        } else {
            XCTFail("Expected blocked conflict for ⌘Q")
        }
    }

    func testDetectConflict_CommandW_ReturnsBlocked() {
        // Arrange
        let key: Key = .w
        let modifiers: NSEvent.ModifierFlags = .command

        // Act
        let result = detector.detectConflict(key: key, modifiers: modifiers)

        // Assert
        if case .blocked(let message) = result {
            XCTAssertTrue(message.contains("Close Window"))
        } else {
            XCTFail("Expected blocked conflict for ⌘W")
        }
    }

    func testDetectConflict_CommandTab_ReturnsBlocked() {
        // Arrange
        let key: Key = .tab
        let modifiers: NSEvent.ModifierFlags = .command

        // Act
        let result = detector.detectConflict(key: key, modifiers: modifiers)

        // Assert
        if case .blocked(let message) = result {
            XCTAssertTrue(message.contains("Application Switcher"))
        } else {
            XCTFail("Expected blocked conflict for ⌘Tab")
        }
    }

    // MARK: - Soft Conflict Tests (Warning)

    func testDetectConflict_CommandSpace_ReturnsWarning() {
        // Arrange
        let key: Key = .space
        let modifiers: NSEvent.ModifierFlags = .command

        // Act
        let result = detector.detectConflict(key: key, modifiers: modifiers)

        // Assert
        if case .warning(let message) = result {
            XCTAssertTrue(message.contains("Spotlight"))
        } else {
            XCTFail("Expected warning for ⌘Space (Spotlight)")
        }
    }

    func testDetectConflict_ControlUpArrow_ReturnsWarning() {
        // Arrange
        let key: Key = .upArrow
        let modifiers: NSEvent.ModifierFlags = .control

        // Act
        let result = detector.detectConflict(key: key, modifiers: modifiers)

        // Assert
        if case .warning(let message) = result {
            XCTAssertTrue(message.contains("Mission Control"))
        } else {
            XCTFail("Expected warning for ⌃↑ (Mission Control)")
        }
    }

    func testDetectConflict_CommandH_ReturnsWarning() {
        // Arrange
        let key: Key = .h
        let modifiers: NSEvent.ModifierFlags = .command

        // Act
        let result = detector.detectConflict(key: key, modifiers: modifiers)

        // Assert
        if case .warning(let message) = result {
            XCTAssertTrue(message.contains("Hide"))
        } else {
            XCTFail("Expected warning for ⌘H (Hide)")
        }
    }

    // MARK: - Safe Combination Tests (No Conflict)

    func testDetectConflict_ControlSpace_ReturnsNone() {
        // Arrange
        let key: Key = .space
        let modifiers: NSEvent.ModifierFlags = .control

        // Act
        let result = detector.detectConflict(key: key, modifiers: modifiers)

        // Assert
        XCTAssertEqual(result, .none, "Control+Space should be safe (default hotkey)")
    }

    func testDetectConflict_MultiModifierCombo_ReturnsNone() {
        // Arrange
        let key: Key = .a
        let modifiers: NSEvent.ModifierFlags = [.command, .option, .control]

        // Act
        let result = detector.detectConflict(key: key, modifiers: modifiers)

        // Assert
        XCTAssertEqual(result, .none, "Triple modifier combinations should be safe")
    }

    func testDetectConflict_CommandOptionShiftSpace_ReturnsNone() {
        // Arrange
        let key: Key = .space
        let modifiers: NSEvent.ModifierFlags = [.command, .option, .shift]

        // Act
        let result = detector.detectConflict(key: key, modifiers: modifiers)

        // Assert
        XCTAssertEqual(result, .none, "Complex modifier combos should be safe")
    }

    func testDetectConflict_FunctionKey_ReturnsNone() {
        // Arrange
        let key: Key = .f5
        let modifiers: NSEvent.ModifierFlags = .command

        // Act
        let result = detector.detectConflict(key: key, modifiers: modifiers)

        // Assert
        XCTAssertEqual(result, .none, "Function keys with modifiers should generally be safe")
    }

    // MARK: - Edge Cases

    func testDetectConflict_NoModifiers_StillChecksConflicts() {
        // Arrange
        let key: Key = .q
        let modifiers: NSEvent.ModifierFlags = []

        // Act
        let result = detector.detectConflict(key: key, modifiers: modifiers)

        // Assert
        // Q without modifiers should be safe (not ⌘Q)
        XCTAssertEqual(result, .none)
    }

    func testDetectConflict_ExtraModifiers_NormalizedCorrectly() {
        // Arrange
        let key: Key = .q
        // Include device-dependent flags that should be filtered out
        var modifiers: NSEvent.ModifierFlags = .command
        modifiers.insert(.deviceIndependentFlagsMask)

        // Act
        let result = detector.detectConflict(key: key, modifiers: modifiers)

        // Assert
        // Should still detect ⌘Q conflict despite extra flags
        if case .blocked = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Should detect ⌘Q conflict even with device flags")
        }
    }
}
