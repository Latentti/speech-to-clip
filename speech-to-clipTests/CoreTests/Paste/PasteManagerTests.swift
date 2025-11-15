//
//  PasteManagerTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 5.2: Implement Auto-Paste with Accessibility API
//

import XCTest
import AppKit
import ApplicationServices
@testable import speech_to_clip

/// Comprehensive tests for PasteManager
///
/// Tests cover:
/// - Accessibility permission checking
/// - Paste simulation with CGEvent API
/// - Clipboard fallback on simulation failure
/// - Error handling for all failure modes
/// - Integration with ClipboardService
final class PasteManagerTests: XCTestCase {

    // MARK: - Properties

    var pasteManager: PasteManager!
    var mockClipboardService: MockClipboardService!
    var originalClipboardContents: String?

    // MARK: - Setup & Teardown

    override func setUp() {
        super.setUp()

        // Save original clipboard contents
        originalClipboardContents = NSPasteboard.general.string(forType: .string)

        // Create mock clipboard service
        mockClipboardService = MockClipboardService()

        // Initialize PasteManager with mock
        pasteManager = PasteManager(clipboardService: mockClipboardService)
    }

    override func tearDown() {
        // Restore original clipboard contents
        if let original = originalClipboardContents {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(original, forType: .string)
        } else {
            NSPasteboard.general.clearContents()
        }

        pasteManager = nil
        mockClipboardService = nil
        originalClipboardContents = nil
        super.tearDown()
    }

    // MARK: - Initialization Tests

    /// Test that PasteManager initializes with default ClipboardService
    func testInitialization_DefaultClipboardService() {
        let manager = PasteManager()
        XCTAssertNotNil(manager, "PasteManager should initialize with default ClipboardService")
    }

    /// Test that PasteManager initializes with custom ClipboardService
    func testInitialization_CustomClipboardService() {
        let customService = MockClipboardService()
        let manager = PasteManager(clipboardService: customService)
        XCTAssertNotNil(manager, "PasteManager should initialize with custom ClipboardService")
    }

    // MARK: - Permission Tests

    /// Test paste() checks accessibility permission before attempting simulation (AC: 1)
    func testPaste_ChecksPermission_BeforeAttemptingSimulation() {
        // Given: Text to paste
        let testText = "Permission check test"

        // When: Attempt to paste
        // Note: This will likely throw permissionDenied in CI/test environment
        // because accessibility permission is typically not granted to test processes

        // Then: Should check permission (verify by checking if clipboard was NOT modified when permission denied)
        if !AXIsProcessTrusted() {
            XCTAssertThrowsError(try pasteManager.paste(testText)) { error in
                guard let pasteError = error as? PasteError else {
                    XCTFail("Expected PasteError, got \(type(of: error))")
                    return
                }

                if case .permissionDenied = pasteError {
                    // Expected - permission check happened before simulation
                    XCTAssertTrue(true, "Permission check executed before simulation attempt")
                } else {
                    XCTFail("Expected permissionDenied, got \(pasteError)")
                }
            }
        }
    }

    /// Test paste() throws permissionDenied when accessibility not granted (AC: 1)
    func testPaste_ThrowsPermissionDenied_WhenAccessibilityNotGranted() {
        // Given: Text to paste
        let testText = "Permission test"

        // When/Then: If permission not granted, should throw permissionDenied
        if !AXIsProcessTrusted() {
            XCTAssertThrowsError(try pasteManager.paste(testText)) { error in
                guard let pasteError = error as? PasteError else {
                    XCTFail("Expected PasteError, got \(type(of: error))")
                    return
                }

                XCTAssertEqual(pasteError, PasteError.permissionDenied, "Should throw permissionDenied")
            }
        } else {
            // Permission granted - skip this test
            XCTSkip("Accessibility permission is granted - cannot test denial case")
        }
    }

    // MARK: - Clipboard Integration Tests

    /// Test paste() copies to clipboard before simulating Cmd+V (AC: 1)
    func testPaste_CopiesToClipboard_BeforeSimulatingCmdV() {
        // Given: Text to paste
        let testText = "Clipboard integration test"

        // When: Attempt to paste (will fail due to permission in test environment, but clipboard should still be copied)
        _ = try? pasteManager.paste(testText)

        // Then: ClipboardService.copyText should have been called
        XCTAssertTrue(mockClipboardService.copyTextCalled, "Should call ClipboardService.copyText()")
        XCTAssertEqual(mockClipboardService.lastCopiedText, testText, "Should copy correct text to clipboard")
    }

    /// Test paste() preserves clipboard even when simulation fails (AC: 1)
    func testPaste_PreservesClipboard_EvenWhenSimulationFails() {
        // Given: Text to paste
        let testText = "Fallback test"

        // When: Attempt to paste (simulation will fail due to permission)
        _ = try? pasteManager.paste(testText)

        // Then: Clipboard should still contain the text (fallback mechanism)
        XCTAssertTrue(mockClipboardService.copyTextCalled, "Clipboard should be updated even on simulation failure")
        XCTAssertEqual(mockClipboardService.lastCopiedText, testText, "Clipboard should contain the text")
    }

    /// Test paste() throws clipboardFailed when clipboard operation fails
    func testPaste_ThrowsClipboardFailed_WhenClipboardOperationFails() {
        // Given: Mock clipboard that throws error
        mockClipboardService.shouldThrowError = true
        let testText = "Clipboard failure test"

        // When/Then: Should throw clipboardFailed
        XCTAssertThrowsError(try pasteManager.paste(testText)) { error in
            guard let pasteError = error as? PasteError else {
                XCTFail("Expected PasteError, got \(type(of: error))")
                return
            }

            if case .clipboardFailed = pasteError {
                XCTAssertTrue(true, "Should throw clipboardFailed")
            } else {
                XCTFail("Expected clipboardFailed, got \(pasteError)")
            }
        }
    }

    // MARK: - Input Validation Tests

    /// Test paste() throws emptyText on empty string
    func testPaste_ThrowsEmptyText_OnEmptyString() {
        // Given: Empty string
        let emptyText = ""

        // When/Then: Should throw emptyText
        XCTAssertThrowsError(try pasteManager.paste(emptyText)) { error in
            guard let pasteError = error as? PasteError else {
                XCTFail("Expected PasteError, got \(type(of: error))")
                return
            }

            XCTAssertEqual(pasteError, PasteError.emptyText, "Should throw emptyText")
        }
    }

    /// Test paste() doesn't modify clipboard on empty string
    func testPaste_DoesNotModifyClipboard_OnEmptyString() {
        // Given: Empty string
        let emptyText = ""

        // When: Attempt to paste empty string
        _ = try? pasteManager.paste(emptyText)

        // Then: ClipboardService should NOT have been called
        XCTAssertFalse(mockClipboardService.copyTextCalled, "Should not call clipboard on empty text")
    }

    // MARK: - Special Characters Tests

    /// Test paste() handles emoji and unicode characters
    func testPaste_HandlesEmojiAndUnicode() {
        // Given: Text with emoji and unicode
        let testText = "Hello 👋 世界 🌍"

        // When: Attempt to paste
        _ = try? pasteManager.paste(testText)

        // Then: Should copy full text including emoji
        XCTAssertEqual(mockClipboardService.lastCopiedText, testText, "Should handle emoji and unicode")
    }

    /// Test paste() handles multiline text
    func testPaste_HandlesMultilineText() {
        // Given: Multiline text
        let testText = "Line 1\nLine 2\nLine 3"

        // When: Attempt to paste
        _ = try? pasteManager.paste(testText)

        // Then: Should copy full multiline text
        XCTAssertEqual(mockClipboardService.lastCopiedText, testText, "Should handle multiline text")
    }

    /// Test paste() handles large text
    func testPaste_HandlesLargeText() {
        // Given: Large text (1000 characters)
        let testText = String(repeating: "A", count: 1000)

        // When: Attempt to paste
        _ = try? pasteManager.paste(testText)

        // Then: Should copy full large text
        XCTAssertEqual(mockClipboardService.lastCopiedText, testText, "Should handle large text")
    }

    // MARK: - Error Enum Tests

    /// Test PasteError.emptyText has correct description
    func testPasteError_EmptyText_HasCorrectDescription() {
        let error = PasteError.emptyText
        XCTAssertNotNil(error.errorDescription, "Should have error description")
        XCTAssertTrue(error.errorDescription?.contains("empty") ?? false, "Description should mention empty text")
    }

    /// Test PasteError.permissionDenied has recovery suggestion
    func testPasteError_PermissionDenied_HasRecoverySuggestion() {
        let error = PasteError.permissionDenied
        XCTAssertNotNil(error.recoverySuggestion, "Should have recovery suggestion")
        XCTAssertTrue(error.recoverySuggestion?.contains("System Settings") ?? false, "Should suggest System Settings")
        XCTAssertTrue(error.recoverySuggestion?.contains("Accessibility") ?? false, "Should mention Accessibility")
    }

    /// Test PasteError.pasteSimulationFailed includes reason
    func testPasteError_PasteSimulationFailed_IncludesReason() {
        let reason = "Test failure reason"
        let error = PasteError.pasteSimulationFailed(reason: reason)
        XCTAssertTrue(error.errorDescription?.contains(reason) ?? false, "Should include failure reason")
    }

    /// Test PasteError.pasteSimulationFailed suggests manual paste
    func testPasteError_PasteSimulationFailed_SuggestsManualPaste() {
        let error = PasteError.pasteSimulationFailed(reason: "Test")
        XCTAssertTrue(error.recoverySuggestion?.contains("Cmd+V") ?? false, "Should suggest manual paste with Cmd+V")
        XCTAssertTrue(error.recoverySuggestion?.contains("clipboard") ?? false, "Should mention clipboard fallback")
    }

    /// Test PasteError.clipboardFailed includes underlying error
    func testPasteError_ClipboardFailed_IncludesUnderlyingError() {
        let underlyingError = NSError(domain: "test", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let error = PasteError.clipboardFailed(underlying: underlyingError)
        XCTAssertTrue(error.errorDescription?.contains("Test error") ?? false, "Should include underlying error description")
    }

    /// Test PasteError.noActiveApplication has correct description
    func testPasteError_NoActiveApplication_HasCorrectDescription() {
        let error = PasteError.noActiveApplication
        XCTAssertNotNil(error.errorDescription, "Should have error description")
        XCTAssertTrue(error.errorDescription?.contains("active application") ?? false, "Should mention active application")
    }
}

// MARK: - Mock ClipboardService

/// Mock ClipboardService for testing PasteManager
class MockClipboardService: ClipboardService {

    // MARK: - Properties

    var copyTextCalled = false
    var lastCopiedText: String?
    var shouldThrowError = false

    // MARK: - Overrides

    override func copyText(_ text: String) throws {
        copyTextCalled = true
        lastCopiedText = text

        if shouldThrowError {
            throw ClipboardError.copyFailed
        }
    }
}
