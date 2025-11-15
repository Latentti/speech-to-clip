//
//  WhisperLanguageTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 6.2: Implement General Settings Tab
//

import XCTest
@testable import speech_to_clip

/// Tests for WhisperLanguage enum
///
/// Covers:
/// - Enum contains all expected languages (55+ languages)
/// - Display names are correct and localized
/// - Language codes match ISO 639-1 standard
/// - Sorted collection works correctly
/// - Codable conformance for persistence
final class WhisperLanguageTests: XCTestCase {

    // MARK: - Language Coverage Tests

    /// Test that WhisperLanguage enum contains expected minimum number of languages
    func testWhisperLanguage_ContainsMinimumExpectedLanguages() {
        // Given: WhisperLanguage enum
        let languageCount = WhisperLanguage.allCases.count

        // Then: Should have at least 55 languages (OpenAI Whisper supports 55+)
        XCTAssertGreaterThanOrEqual(
            languageCount,
            55,
            "WhisperLanguage should contain at least 55 languages"
        )
    }

    /// Test that specific required languages are present
    func testWhisperLanguage_ContainsRequiredLanguages() {
        // Given: Common languages that must be supported
        let requiredLanguages: [WhisperLanguage] = [
            .english,
            .spanish,
            .french,
            .german,
            .italian,
            .portuguese,
            .russian,
            .chinese,
            .japanese,
            .korean
        ]

        // Then: All required languages should exist
        for language in requiredLanguages {
            XCTAssertTrue(
                WhisperLanguage.allCases.contains(language),
                "\(language) should be in WhisperLanguage enum"
            )
        }
    }

    // MARK: - Display Name Tests

    /// Test that display names are non-empty and correctly formatted
    func testWhisperLanguage_DisplayNamesAreValid() {
        // Given: All Whisper languages
        let allLanguages = WhisperLanguage.allCases

        // Then: Each language should have a valid display name
        for language in allLanguages {
            let displayName = language.displayName

            XCTAssertFalse(
                displayName.isEmpty,
                "\(language.rawValue) should have a non-empty display name"
            )

            // Display names should start with capital letter
            XCTAssertTrue(
                displayName.first?.isUppercase ?? false,
                "\(language.rawValue) display name should start with uppercase letter"
            )
        }
    }

    /// Test specific language display names match expected values
    func testWhisperLanguage_DisplayNamesMatchExpected() {
        // Given/When: Specific languages and their expected display names
        let expectations: [(WhisperLanguage, String)] = [
            (.english, "English"),
            (.spanish, "Spanish"),
            (.french, "French"),
            (.german, "German"),
            (.chinese, "Chinese"),
            (.japanese, "Japanese"),
            (.korean, "Korean"),
            (.portuguese, "Portuguese"),
            (.russian, "Russian"),
            (.arabic, "Arabic")
        ]

        // Then: Display names should match expectations
        for (language, expectedName) in expectations {
            XCTAssertEqual(
                language.displayName,
                expectedName,
                "\(language.rawValue) display name should be '\(expectedName)'"
            )
        }
    }

    // MARK: - Language Code Tests

    /// Test that language codes follow ISO 639-1 format (2-letter codes)
    func testWhisperLanguage_RawValuesAreISO6391Codes() {
        // Given: All Whisper languages
        let allLanguages = WhisperLanguage.allCases

        // Then: All raw values should be 2-letter ISO 639-1 codes
        for language in allLanguages {
            let code = language.rawValue

            XCTAssertEqual(
                code.count,
                2,
                "\(language.displayName) code '\(code)' should be 2 characters (ISO 639-1)"
            )

            // Should be lowercase letters
            XCTAssertTrue(
                code.allSatisfy { $0.isLowercase },
                "\(language.displayName) code '\(code)' should be lowercase"
            )
        }
    }

    /// Test specific language codes match OpenAI Whisper API expectations
    func testWhisperLanguage_CodesMatchWhisperAPIExpectations() {
        // Given/When: Languages and their expected API codes
        let expectations: [(WhisperLanguage, String)] = [
            (.english, "en"),
            (.spanish, "es"),
            (.french, "fr"),
            (.german, "de"),
            (.chinese, "zh"),
            (.japanese, "ja"),
            (.korean, "ko"),
            (.portuguese, "pt"),
            (.russian, "ru"),
            (.dutch, "nl")
        ]

        // Then: Raw values should match expected API codes
        for (language, expectedCode) in expectations {
            XCTAssertEqual(
                language.rawValue,
                expectedCode,
                "\(language.displayName) should have code '\(expectedCode)'"
            )
        }
    }

    // MARK: - Sorted Collection Tests

    /// Test that sortedByDisplayName returns all languages
    func testWhisperLanguage_SortedByDisplayName_ContainsAllLanguages() {
        // Given: Sorted language array
        let sortedLanguages = WhisperLanguage.sortedByDisplayName

        // Then: Should contain same count as allCases
        XCTAssertEqual(
            sortedLanguages.count,
            WhisperLanguage.allCases.count,
            "Sorted array should contain all languages"
        )

        // And: Should contain each language exactly once
        for language in WhisperLanguage.allCases {
            let count = sortedLanguages.filter { $0 == language }.count
            XCTAssertEqual(
                count,
                1,
                "\(language.displayName) should appear exactly once in sorted array"
            )
        }
    }

    /// Test that sortedByDisplayName is actually sorted alphabetically
    func testWhisperLanguage_SortedByDisplayName_IsActuallySorted() {
        // Given: Sorted language array
        let sortedLanguages = WhisperLanguage.sortedByDisplayName

        // When: Extract display names
        let displayNames = sortedLanguages.map { $0.displayName }

        // Then: Display names should be in alphabetical order
        let expectedSorted = displayNames.sorted()
        XCTAssertEqual(
            displayNames,
            expectedSorted,
            "Languages should be sorted alphabetically by display name"
        )

        // And: First language alphabetically should be at index 0
        if let firstLanguage = sortedLanguages.first {
            XCTAssertEqual(
                firstLanguage,
                .afrikaans,
                "First language alphabetically should be Afrikaans"
            )
        }
    }

    // MARK: - Identifiable Conformance Tests

    /// Test that id property returns raw value for SwiftUI compatibility
    func testWhisperLanguage_IdPropertyReturnsRawValue() {
        // Given: All Whisper languages
        let allLanguages = WhisperLanguage.allCases

        // Then: id should equal rawValue for each language
        for language in allLanguages {
            XCTAssertEqual(
                language.id,
                language.rawValue,
                "\(language.displayName) id should equal raw value '\(language.rawValue)'"
            )
        }
    }

    /// Test that all ids are unique (required for SwiftUI ForEach)
    func testWhisperLanguage_IdsAreUnique() {
        // Given: All language ids
        let allIds = WhisperLanguage.allCases.map { $0.id }

        // Then: All ids should be unique
        let uniqueIds = Set(allIds)
        XCTAssertEqual(
            allIds.count,
            uniqueIds.count,
            "All language ids should be unique for SwiftUI ForEach compatibility"
        )
    }

    // MARK: - Codable Conformance Tests

    /// Test that WhisperLanguage can be encoded and decoded
    func testWhisperLanguage_CodableConformance() throws {
        // Given: A specific language
        let originalLanguage = WhisperLanguage.french

        // When: Encoding to JSON
        let encoder = JSONEncoder()
        let encoded = try encoder.encode(originalLanguage)

        // And: Decoding from JSON
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WhisperLanguage.self, from: encoded)

        // Then: Decoded language should match original
        XCTAssertEqual(
            decoded,
            originalLanguage,
            "Decoded language should match original"
        )
        XCTAssertEqual(
            decoded.rawValue,
            "fr",
            "Decoded language should have correct raw value"
        )
    }

    /// Test that all languages can be encoded and decoded
    func testWhisperLanguage_AllLanguagesAreCodable() throws {
        // Given: All Whisper languages
        let allLanguages = WhisperLanguage.allCases

        // Then: Each language should be encodable and decodable
        for language in allLanguages {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(language)

            let decoder = JSONDecoder()
            let decoded = try decoder.decode(WhisperLanguage.self, from: encoded)

            XCTAssertEqual(
                decoded,
                language,
                "\(language.displayName) should be codable"
            )
        }
    }
}
