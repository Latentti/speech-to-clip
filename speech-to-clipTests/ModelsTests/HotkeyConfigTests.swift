//
//  HotkeyConfigTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 6.3: Implement Hotkey Capture Control
//

import XCTest
import AppKit
import HotKey
@testable import speech_to_clip

final class HotkeyConfigTests: XCTestCase {
    // MARK: - Initialization Tests

    func testHotkeyConfig_Initialization_CreatesInstanceWithKeyAndModifiers() {
        // Arrange & Act
        let config = HotkeyConfig(key: .space, modifiers: .control)

        // Assert
        XCTAssertEqual(config.key, .space)
        XCTAssertEqual(config.modifiers, .control)
    }

    func testHotkeyConfig_DefaultValue_MatchesControlSpace() {
        // Arrange & Act
        let defaultConfig = HotkeyConfig.default

        // Assert
        XCTAssertEqual(defaultConfig.key, .space)
        XCTAssertEqual(defaultConfig.modifiers, .control)
    }

    // MARK: - Codable Tests

    func testHotkeyConfig_Encoding_ProducesValidJSON() throws {
        // Arrange
        let config = HotkeyConfig(key: .a, modifiers: [.command, .option])
        let encoder = JSONEncoder()

        // Act
        let data = try encoder.encode(config)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Assert
        XCTAssertNotNil(json)
        XCTAssertNotNil(json?["keyCode"])
        XCTAssertNotNil(json?["modifierFlags"])
    }

    func testHotkeyConfig_Decoding_RestoresOriginalValue() throws {
        // Arrange
        let original = HotkeyConfig(key: .space, modifiers: [.control, .shift])
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(HotkeyConfig.self, from: data)

        // Assert
        XCTAssertEqual(decoded.key, original.key)
        XCTAssertEqual(decoded.modifiers, original.modifiers)
    }

    func testHotkeyConfig_Decoding_WithMultipleModifiers_RestoresAllModifiers() throws {
        // Arrange
        let original = HotkeyConfig(
            key: .f1,
            modifiers: [.command, .option, .control, .shift]
        )
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(HotkeyConfig.self, from: data)

        // Assert
        XCTAssertTrue(decoded.modifiers.contains(.command))
        XCTAssertTrue(decoded.modifiers.contains(.option))
        XCTAssertTrue(decoded.modifiers.contains(.control))
        XCTAssertTrue(decoded.modifiers.contains(.shift))
    }

    func testHotkeyConfig_Decoding_WithInvalidKeyCode_ThrowsError() {
        // Arrange
        let invalidJSON = """
        {"keyCode": 999999, "modifierFlags": 0}
        """.data(using: .utf8)!
        let decoder = JSONDecoder()

        // Act & Assert
        XCTAssertThrowsError(try decoder.decode(HotkeyConfig.self, from: invalidJSON)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }

    // MARK: - Equality Tests

    func testHotkeyConfig_Equality_SameKeyAndModifiers_ReturnsTrue() {
        // Arrange
        let config1 = HotkeyConfig(key: .space, modifiers: .control)
        let config2 = HotkeyConfig(key: .space, modifiers: .control)

        // Act & Assert
        XCTAssertEqual(config1, config2)
    }

    func testHotkeyConfig_Equality_DifferentKey_ReturnsFalse() {
        // Arrange
        let config1 = HotkeyConfig(key: .space, modifiers: .control)
        let config2 = HotkeyConfig(key: .a, modifiers: .control)

        // Act & Assert
        XCTAssertNotEqual(config1, config2)
    }

    func testHotkeyConfig_Equality_DifferentModifiers_ReturnsFalse() {
        // Arrange
        let config1 = HotkeyConfig(key: .space, modifiers: .control)
        let config2 = HotkeyConfig(key: .space, modifiers: .command)

        // Act & Assert
        XCTAssertNotEqual(config1, config2)
    }

    // MARK: - Display String Tests

    func testHotkeyConfig_DisplayString_ControlSpace_ReturnsCorrectFormat() {
        // Arrange
        let config = HotkeyConfig(key: .space, modifiers: .control)

        // Act
        let display = config.displayString

        // Assert
        XCTAssertTrue(display.contains("⌃"))
        XCTAssertTrue(display.contains("Space"))
    }

    func testHotkeyConfig_DisplayString_CommandOptionA_ReturnsCorrectFormat() {
        // Arrange
        let config = HotkeyConfig(key: .a, modifiers: [.command, .option])

        // Act
        let display = config.displayString

        // Assert
        XCTAssertTrue(display.contains("⌥"))
        XCTAssertTrue(display.contains("⌘"))
        XCTAssertTrue(display.contains("A"))
    }

    func testHotkeyConfig_DisplayString_AllModifiers_ContainsAllSymbols() {
        // Arrange
        let config = HotkeyConfig(
            key: .f5,
            modifiers: [.command, .option, .control, .shift]
        )

        // Act
        let display = config.displayString

        // Assert
        XCTAssertTrue(display.contains("⌃"), "Should contain Control symbol")
        XCTAssertTrue(display.contains("⌥"), "Should contain Option symbol")
        XCTAssertTrue(display.contains("⇧"), "Should contain Shift symbol")
        XCTAssertTrue(display.contains("⌘"), "Should contain Command symbol")
        XCTAssertTrue(display.contains("F5"), "Should contain key name")
    }

    // MARK: - Key Description Tests

    func testKey_Description_Space_ReturnsSpace() {
        // Arrange
        let key: Key = .space

        // Act & Assert
        XCTAssertEqual(key.description, "Space")
    }

    func testKey_Description_F1_ReturnsF1() {
        // Arrange
        let key: Key = .f1

        // Act & Assert
        XCTAssertEqual(key.description, "F1")
    }

    func testKey_Description_LetterKey_ReturnsUppercase() {
        // Arrange
        let key: Key = .a

        // Act
        let description = key.description

        // Assert
        XCTAssertEqual(description, "A")
    }

    func testKey_Description_Arrow_ReturnsArrowSymbol() {
        // Arrange
        let upKey: Key = .upArrow
        let downKey: Key = .downArrow

        // Act & Assert
        XCTAssertEqual(upKey.description, "↑")
        XCTAssertEqual(downKey.description, "↓")
    }
}
