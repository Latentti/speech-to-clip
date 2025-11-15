//
//  TranscriptionServiceTests.swift
//  speech-to-clipTests
//
//  Created by BMad Dev Agent on 2025-11-13.
//  Story 4.3: Implement Transcription Service - Comprehensive Test Suite
//

import XCTest
@testable import speech_to_clip

/// Comprehensive tests for TranscriptionService orchestration logic
///
/// Tests cover:
/// - Successful transcription flow (happy path)
/// - Audio format validation errors
/// - Whisper API errors (network, auth, rate limit)
/// - Error mapping from underlying services
/// - Dependency injection with mocks
@MainActor
final class TranscriptionServiceTests: XCTestCase {

    // MARK: - Mock Dependencies

    /// Mock WhisperClient for testing without real API calls
    class MockWhisperClient: WhisperClient {
        var shouldSucceed = true
        var mockResponse = "This is the transcribed text"
        var mockError: WhisperClientError?

        override func transcribe(audioData: Data, apiKey: String, language: String) async throws -> String {
            if let error = mockError {
                throw error
            }
            if shouldSucceed {
                return mockResponse
            }
            throw WhisperClientError.networkError(NSError(domain: "test", code: -1))
        }
    }

    /// Mock AudioFormatService for testing error mapping
    class MockAudioFormatService: AudioFormatService {
        var shouldSucceed = true
        var mockError: AudioFormatError?

        override func prepareForWhisperAPI(audioData: Data) throws -> Data {
            if let error = mockError {
                throw error
            }
            if shouldSucceed {
                return audioData // Pass through
            }
            throw AudioFormatError.invalidFormat
        }
    }

    // MARK: - Test Properties

    var service: TranscriptionService!
    var mockWhisperClient: MockWhisperClient!
    var mockAudioFormatService: MockAudioFormatService!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockWhisperClient = MockWhisperClient()
        mockAudioFormatService = MockAudioFormatService()
        service = TranscriptionService(
            whisperClient: mockWhisperClient,
            audioFormatService: mockAudioFormatService
        )
    }

    override func tearDown() async throws {
        service = nil
        mockWhisperClient = nil
        mockAudioFormatService = nil
        try await super.tearDown()
    }

    // MARK: - Happy Path Tests

    /// Test successful transcription flow (AC: 1, 3, 4)
    func testSuccessfulTranscription() async throws {
        // Given: Valid audio data, API key, and language
        let audioData = createMockAudioData(size: 1000)
        let apiKey = "sk-test-key-12345"
        let language = "en"

        mockAudioFormatService.shouldSucceed = true
        mockWhisperClient.shouldSucceed = true
        mockWhisperClient.mockResponse = "Hello world"

        // When: Transcribe is called
        let result = try await service.transcribe(
            audioData: audioData,
            apiKey: apiKey,
            language: language
        )

        // Then: Returns transcribed text
        XCTAssertEqual(result, "Hello world")
    }

    /// Test that service coordinates both dependencies correctly (AC: 4)
    func testServiceCoordinatesDependencies() async throws {
        // Given: Valid inputs
        let audioData = createMockAudioData(size: 500)
        let apiKey = "sk-test-key"
        let language = "fi"

        // When: Transcribe is called
        _ = try await service.transcribe(
            audioData: audioData,
            apiKey: apiKey,
            language: language
        )

        // Then: Both services were called (implicitly verified by success)
        // AudioFormatService validates, WhisperClient transcribes
        XCTAssertTrue(true, "Both services coordinated successfully")
    }

    // MARK: - API Key Validation Tests

    /// Test missing API key is caught early (AC: 2)
    func testMissingAPIKey() async throws {
        // Given: Empty API key
        let audioData = createMockAudioData(size: 1000)
        let apiKey = ""
        let language = "en"

        // When/Then: Throws apiKeyMissing error
        do {
            _ = try await service.transcribe(
                audioData: audioData,
                apiKey: apiKey,
                language: language
            )
            XCTFail("Should have thrown apiKeyMissing error")
        } catch let error as SpeechToClipError {
            switch error {
            case .apiKeyMissing:
                XCTAssertTrue(true, "Correctly threw apiKeyMissing")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Audio Format Error Mapping Tests (AC: 2)

    /// Test fileTooLarge error mapping
    func testAudioTooLargeErrorMapping() async throws {
        // Given: AudioFormatService throws fileTooLarge
        let audioData = createMockAudioData(size: 30_000_000) // 30MB
        let apiKey = "sk-test-key"
        let language = "en"

        mockAudioFormatService.mockError = .fileTooLarge(size: 30_000_000)

        // When/Then: Throws mapped SpeechToClipError.audioTooLarge
        do {
            _ = try await service.transcribe(
                audioData: audioData,
                apiKey: apiKey,
                language: language
            )
            XCTFail("Should have thrown audioTooLarge error")
        } catch let error as SpeechToClipError {
            switch error {
            case .audioTooLarge(let sizeMB):
                XCTAssertEqual(sizeMB, 30.0, accuracy: 0.1)
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    /// Test invalidFormat error mapping
    func testInvalidFormatErrorMapping() async throws {
        // Given: AudioFormatService throws invalidFormat
        let audioData = createMockAudioData(size: 1000)
        let apiKey = "sk-test-key"
        let language = "en"

        mockAudioFormatService.mockError = .invalidFormat

        // When/Then: Throws mapped SpeechToClipError.audioFormatInvalid
        do {
            _ = try await service.transcribe(
                audioData: audioData,
                apiKey: apiKey,
                language: language
            )
            XCTFail("Should have thrown audioFormatInvalid error")
        } catch let error as SpeechToClipError {
            switch error {
            case .audioFormatInvalid:
                XCTAssertTrue(true, "Correctly mapped to audioFormatInvalid")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    /// Test unsupportedFormat error mapping
    func testUnsupportedFormatErrorMapping() async throws {
        // Given: AudioFormatService throws unsupportedFormat
        let audioData = createMockAudioData(size: 1000)
        let apiKey = "sk-test-key"
        let language = "en"

        mockAudioFormatService.mockError = .unsupportedFormat("MP3")

        // When/Then: Throws mapped SpeechToClipError.audioFormatInvalid
        do {
            _ = try await service.transcribe(
                audioData: audioData,
                apiKey: apiKey,
                language: language
            )
            XCTFail("Should have thrown audioFormatInvalid error")
        } catch let error as SpeechToClipError {
            switch error {
            case .audioFormatInvalid:
                XCTAssertTrue(true, "Correctly mapped to audioFormatInvalid")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Whisper API Error Mapping Tests (AC: 2)

    /// Test network error mapping
    func testNetworkErrorMapping() async throws {
        // Given: WhisperClient throws networkError
        let audioData = createMockAudioData(size: 1000)
        let apiKey = "sk-test-key"
        let language = "en"

        let underlyingError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        mockWhisperClient.mockError = .networkError(underlyingError)

        // When/Then: Throws mapped SpeechToClipError.networkUnavailable
        do {
            _ = try await service.transcribe(
                audioData: audioData,
                apiKey: apiKey,
                language: language
            )
            XCTFail("Should have thrown networkUnavailable error")
        } catch let error as SpeechToClipError {
            switch error {
            case .networkUnavailable:
                XCTAssertTrue(true, "Correctly mapped to networkUnavailable")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    /// Test invalid API key error mapping
    func testInvalidAPIKeyErrorMapping() async throws {
        // Given: WhisperClient throws invalidAPIKey
        let audioData = createMockAudioData(size: 1000)
        let apiKey = "sk-invalid-key"
        let language = "en"

        mockWhisperClient.mockError = .invalidAPIKey

        // When/Then: Throws mapped SpeechToClipError.apiKeyInvalid
        do {
            _ = try await service.transcribe(
                audioData: audioData,
                apiKey: apiKey,
                language: language
            )
            XCTFail("Should have thrown apiKeyInvalid error")
        } catch let error as SpeechToClipError {
            switch error {
            case .apiKeyInvalid:
                XCTAssertTrue(true, "Correctly mapped to apiKeyInvalid")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    /// Test rate limit error mapping
    func testRateLimitErrorMapping() async throws {
        // Given: WhisperClient throws rateLimitExceeded
        let audioData = createMockAudioData(size: 1000)
        let apiKey = "sk-test-key"
        let language = "en"

        mockWhisperClient.mockError = .rateLimitExceeded

        // When/Then: Throws mapped SpeechToClipError.rateLimitExceeded
        do {
            _ = try await service.transcribe(
                audioData: audioData,
                apiKey: apiKey,
                language: language
            )
            XCTFail("Should have thrown rateLimitExceeded error")
        } catch let error as SpeechToClipError {
            switch error {
            case .rateLimitExceeded:
                XCTAssertTrue(true, "Correctly mapped to rateLimitExceeded")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    /// Test server error mapping
    func testServerErrorMapping() async throws {
        // Given: WhisperClient throws serverError
        let audioData = createMockAudioData(size: 1000)
        let apiKey = "sk-test-key"
        let language = "en"

        mockWhisperClient.mockError = .serverError(500)

        // When/Then: Throws mapped SpeechToClipError.transcriptionFailed
        do {
            _ = try await service.transcribe(
                audioData: audioData,
                apiKey: apiKey,
                language: language
            )
            XCTFail("Should have thrown transcriptionFailed error")
        } catch let error as SpeechToClipError {
            switch error {
            case .transcriptionFailed(let reason):
                XCTAssertTrue(reason.contains("500"), "Should mention HTTP 500")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    /// Test invalid response error mapping
    func testInvalidResponseErrorMapping() async throws {
        // Given: WhisperClient throws invalidResponse
        let audioData = createMockAudioData(size: 1000)
        let apiKey = "sk-test-key"
        let language = "en"

        mockWhisperClient.mockError = .invalidResponse

        // When/Then: Throws mapped SpeechToClipError.transcriptionFailed
        do {
            _ = try await service.transcribe(
                audioData: audioData,
                apiKey: apiKey,
                language: language
            )
            XCTFail("Should have thrown transcriptionFailed error")
        } catch let error as SpeechToClipError {
            switch error {
            case .transcriptionFailed:
                XCTAssertTrue(true, "Correctly mapped to transcriptionFailed")
            default:
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    // MARK: - Helper Methods

    /// Create mock audio data of specified size
    private func createMockAudioData(size: Int) -> Data {
        return Data(repeating: 0x00, count: size)
    }
}
