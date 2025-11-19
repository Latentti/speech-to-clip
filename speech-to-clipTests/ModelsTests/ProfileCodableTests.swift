//
//  ProfileCodableTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-19.
//  Story 10.1: Extend Profile Model with Transcription Engine Fields
//

import XCTest
@testable import speech_to_clip

/// Tests for Profile Codable conformance and backward compatibility
///
/// Tests cover:
/// - TranscriptionEngine enum cases and raw values (AC: enum conformance)
/// - Profile encoding/decoding with new transcription engine fields (AC: Codable conformance)
/// - Backward compatibility: old profiles without new fields decode correctly (AC: backward compatible)
/// - Forward compatibility: new profiles with transcription engine fields encode/decode correctly
///
/// **Test Isolation:**
/// - Uses JSONEncoder/JSONDecoder for serialization testing
/// - No UserDefaults or Keychain dependency
/// - Pure model layer testing
final class ProfileCodableTests: XCTestCase {

    // MARK: - TranscriptionEngine Tests

    /// Test that TranscriptionEngine enum has correct cases and raw values (AC: enum with cases)
    func testTranscriptionEngine_EnumCases_HasCorrectRawValues() {
        // Assert: Verify raw values
        XCTAssertEqual(TranscriptionEngine.openai.rawValue, "OpenAI API", "OpenAI case should have correct raw value")
        XCTAssertEqual(TranscriptionEngine.localWhisper.rawValue, "Local Whisper", "LocalWhisper case should have correct raw value")

        // Assert: Verify all cases are present
        let allCases = TranscriptionEngine.allCases
        XCTAssertEqual(allCases.count, 2, "Should have exactly 2 cases")
        XCTAssertTrue(allCases.contains(.openai), "allCases should contain .openai")
        XCTAssertTrue(allCases.contains(.localWhisper), "allCases should contain .localWhisper")
    }

    /// Test that TranscriptionEngine conforms to Codable (AC: Codable conformance)
    func testTranscriptionEngine_Codable_EncodesAndDecodesCorrectly() throws {
        // Arrange
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // Act & Assert: OpenAI case
        let openaiData = try encoder.encode(TranscriptionEngine.openai)
        let decodedOpenai = try decoder.decode(TranscriptionEngine.self, from: openaiData)
        XCTAssertEqual(decodedOpenai, .openai, "OpenAI should encode and decode correctly")

        // Act & Assert: LocalWhisper case
        let whisperData = try encoder.encode(TranscriptionEngine.localWhisper)
        let decodedWhisper = try decoder.decode(TranscriptionEngine.self, from: whisperData)
        XCTAssertEqual(decodedWhisper, .localWhisper, "LocalWhisper should encode and decode correctly")
    }

    // MARK: - Profile Backward Compatibility Tests

    /// Test that old Profile JSON (without transcription engine fields) decodes successfully (AC: backward compatible)
    func testProfile_BackwardCompatibility_OldJSONDecodesWithDefaults() throws {
        // Arrange: JSON representing old Profile (before Story 10.1)
        let oldProfileJSON = """
        {
            "id": "550E8400-E29B-41D4-A716-446655440000",
            "name": "Old Profile",
            "language": "en",
            "createdAt": 631152000,
            "updatedAt": 631152000
        }
        """.data(using: .utf8)!

        // Act: Decode old JSON
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let profile = try decoder.decode(Profile.self, from: oldProfileJSON)

        // Assert: Verify profile decoded successfully with default values
        XCTAssertEqual(profile.name, "Old Profile", "Profile name should decode correctly")
        XCTAssertEqual(profile.language, "en", "Profile language should decode correctly")

        // Assert: Verify new fields have default values
        XCTAssertEqual(profile.transcriptionEngine, .openai, "transcriptionEngine should default to .openai")
        XCTAssertNil(profile.whisperModelName, "whisperModelName should default to nil")
        XCTAssertEqual(profile.whisperServerPort, 8080, "whisperServerPort should default to 8080")
    }

    /// Test that new Profile with transcription engine fields encodes and decodes correctly (AC: forward compatible)
    func testProfile_ForwardCompatibility_NewProfileEncodesAndDecodesCorrectly() throws {
        // Arrange: Create new profile with transcription engine fields
        let profile = Profile(
            id: UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!,
            name: "Local Whisper Profile",
            language: "fi",
            createdAt: Date(timeIntervalSince1970: 631152000),
            updatedAt: Date(timeIntervalSince1970: 631152000),
            transcriptionEngine: .localWhisper,
            whisperModelName: "medium",
            whisperServerPort: 9090
        )

        // Act: Encode and decode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(profile)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decodedProfile = try decoder.decode(Profile.self, from: data)

        // Assert: Verify all fields preserved
        XCTAssertEqual(decodedProfile.id, profile.id, "ID should be preserved")
        XCTAssertEqual(decodedProfile.name, profile.name, "Name should be preserved")
        XCTAssertEqual(decodedProfile.language, profile.language, "Language should be preserved")
        XCTAssertEqual(decodedProfile.transcriptionEngine, .localWhisper, "transcriptionEngine should be preserved")
        XCTAssertEqual(decodedProfile.whisperModelName, "medium", "whisperModelName should be preserved")
        XCTAssertEqual(decodedProfile.whisperServerPort, 9090, "whisperServerPort should be preserved")
    }

    /// Test that Profile with OpenAI engine (default) encodes and decodes correctly
    func testProfile_OpenAIEngine_EncodesAndDecodesCorrectly() throws {
        // Arrange: Create profile with default OpenAI engine
        let profile = Profile(
            id: UUID(uuidString: "550E8400-E29B-41D4-A716-446655440000")!,
            name: "OpenAI Profile",
            language: "en",
            createdAt: Date(timeIntervalSince1970: 631152000),
            updatedAt: Date(timeIntervalSince1970: 631152000)
            // transcriptionEngine defaults to .openai
            // whisperModelName defaults to nil
            // whisperServerPort defaults to 8080
        )

        // Act: Encode and decode
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(profile)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decodedProfile = try decoder.decode(Profile.self, from: data)

        // Assert: Verify defaults are preserved
        XCTAssertEqual(decodedProfile.transcriptionEngine, .openai, "Default transcriptionEngine should be .openai")
        XCTAssertNil(decodedProfile.whisperModelName, "Default whisperModelName should be nil")
        XCTAssertEqual(decodedProfile.whisperServerPort, 8080, "Default whisperServerPort should be 8080")
    }

    // MARK: - Profile Identifiable and Equatable Tests

    /// Test that Profile still conforms to Identifiable (AC: maintains protocol conformance)
    func testProfile_Identifiable_MaintainsUniqueIDs() {
        // Arrange: Create two profiles
        let profile1 = Profile(name: "Profile 1", language: "en")
        let profile2 = Profile(name: "Profile 2", language: "fi")

        // Assert: Verify each has unique ID
        XCTAssertNotEqual(profile1.id, profile2.id, "Profiles should have unique IDs")
    }

    /// Test that Profile still conforms to Equatable (AC: maintains protocol conformance)
    func testProfile_Equatable_ComparesFieldsCorrectly() {
        // Arrange: Create two profiles with same data but different IDs
        let id = UUID()
        let profile1 = Profile(
            id: id,
            name: "Test",
            language: "en",
            createdAt: Date(timeIntervalSince1970: 631152000),
            updatedAt: Date(timeIntervalSince1970: 631152000),
            transcriptionEngine: .localWhisper,
            whisperModelName: "base",
            whisperServerPort: 8080
        )
        let profile2 = Profile(
            id: id,
            name: "Test",
            language: "en",
            createdAt: Date(timeIntervalSince1970: 631152000),
            updatedAt: Date(timeIntervalSince1970: 631152000),
            transcriptionEngine: .localWhisper,
            whisperModelName: "base",
            whisperServerPort: 8080
        )

        // Assert: Verify equality works with new fields
        XCTAssertEqual(profile1, profile2, "Profiles with identical fields should be equal")

        // Assert: Verify inequality when transcriptionEngine differs
        var profile3 = profile1
        profile3.transcriptionEngine = .openai
        XCTAssertNotEqual(profile1, profile3, "Profiles with different transcriptionEngine should not be equal")
    }
}
