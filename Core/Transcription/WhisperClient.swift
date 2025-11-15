//
//  WhisperClient.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-13.
//  Story 4.1: Implement Whisper API Client
//

import Foundation
import os.log

/// WhisperClient provides async API access to OpenAI Whisper transcription service
///
/// This client handles multipart/form-data encoding for audio file upload,
/// HTTP request/response management, and comprehensive error handling.
/// Follows async/await pattern established in previous stories (AudioRecorder, AppState).
///
/// Key features:
/// - Async/await API for clean error propagation
/// - Multipart form-data encoding per RFC 2388
/// - 30-second timeout (Whisper typically responds in 2-5 seconds)
/// - Comprehensive error handling (network, API, parsing)
/// - Thread-safe URLSession usage
/// - Unified logging with os.log for production-safe logging
class WhisperClient {
    // MARK: - Properties

    /// Whisper API transcription endpoint URL
    private let transcriptionEndpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    /// Whisper API translation endpoint URL (translates to English)
    private let translationEndpoint = URL(string: "https://api.openai.com/v1/audio/translations")!

    /// Request timeout in seconds
    private let timeout: TimeInterval = 30.0

    /// URLSession for making HTTP requests
    /// Can be injected for testing with URLProtocol mocking
    private let urlSession: URLSession

    /// Logger for WhisperClient operations
    private let logger = Logger(subsystem: "com.latentti.speech-to-clip", category: "WhisperClient")

    // MARK: - Initialization

    /// Initialize WhisperClient with optional custom URLSession
    /// - Parameter urlSession: URLSession to use (defaults to .shared)
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        logger.info("WhisperClient initialized")
    }

    // MARK: - Public API

    /// Transcribe audio data using OpenAI Whisper API
    /// - Parameters:
    ///   - audioData: Audio data in WAV format (from AudioRecorder)
    ///   - apiKey: OpenAI API key (Bearer token)
    ///   - language: Language code (e.g., "en", "fi", "es")
    /// - Returns: Transcribed text string
    /// - Throws: WhisperClientError on failure
    func transcribe(audioData: Data, apiKey: String, language: String) async throws -> String {
        logger.info("Starting transcription request (audio size: \(audioData.count) bytes, language: \(language))")

        // Build multipart form-data request
        let boundary = generateBoundary()
        let httpBody = createMultipartBody(audioData: audioData, language: language, boundary: boundary)

        // Create URLRequest
        var request = URLRequest(url: transcriptionEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody

        // Send request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            logger.error("Network request failed: \(error.localizedDescription)")
            throw WhisperClientError.networkError(error)
        }

        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type received")
            throw WhisperClientError.invalidResponse
        }

        logger.debug("Received response with status: \(httpResponse.statusCode)")

        // Handle HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            // Success - parse response
            break
        case 401:
            logger.error("Authentication failed - invalid API key")
            throw WhisperClientError.invalidAPIKey
        case 429:
            logger.error("Rate limit exceeded")
            throw WhisperClientError.rateLimitExceeded
        case 500...599:
            logger.error("Server error: \(httpResponse.statusCode)")
            throw WhisperClientError.serverError(httpResponse.statusCode)
        default:
            logger.error("Unexpected status code: \(httpResponse.statusCode)")
            throw WhisperClientError.httpError(httpResponse.statusCode)
        }

        // Parse JSON response
        let transcriptionText: String
        do {
            let responseObject = try JSONDecoder().decode(WhisperResponse.self, from: data)
            transcriptionText = responseObject.text
        } catch {
            logger.error("Failed to parse response JSON: \(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Response content: \(responseString)")
            }
            throw WhisperClientError.invalidJSON(error)
        }

        logger.info("Transcription successful (length: \(transcriptionText.count) characters)")
        return transcriptionText
    }

    /// Translate audio data to English using OpenAI Whisper API
    /// - Parameters:
    ///   - audioData: Audio data in WAV format (from AudioRecorder)
    ///   - apiKey: OpenAI API key (Bearer token)
    /// - Returns: Translated text string (always in English)
    /// - Throws: WhisperClientError on failure
    /// - Note: /translations endpoint automatically detects source language and translates to English
    func translate(audioData: Data, apiKey: String) async throws -> String {
        logger.info("Starting translation request (audio size: \(audioData.count) bytes)")

        // Build multipart form-data request (no language parameter for translations)
        let boundary = generateBoundary()
        let httpBody = createMultipartBodyForTranslation(audioData: audioData, boundary: boundary)

        // Create URLRequest
        var request = URLRequest(url: translationEndpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody

        // Send request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            logger.error("Network request failed: \(error.localizedDescription)")
            throw WhisperClientError.networkError(error)
        }

        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type received")
            throw WhisperClientError.invalidResponse
        }

        logger.debug("Received response with status: \(httpResponse.statusCode)")

        // Handle HTTP status codes
        guard httpResponse.statusCode == 200 else {
            switch httpResponse.statusCode {
            case 400:
                logger.error("Bad request - invalid audio format or parameters")
                throw WhisperClientError.invalidRequest
            case 401, 403:
                logger.error("Authentication failed - invalid API key")
                throw WhisperClientError.invalidAPIKey
            case 429:
                logger.error("Rate limit exceeded")
                throw WhisperClientError.rateLimitExceeded
            case 500...599:
                logger.error("Server error: \(httpResponse.statusCode)")
                throw WhisperClientError.serverError(httpResponse.statusCode)
            default:
                logger.error("Unexpected status code: \(httpResponse.statusCode)")
                throw WhisperClientError.httpError(httpResponse.statusCode)
            }
        }

        // Parse JSON response
        let translatedText: String
        do {
            let responseObject = try JSONDecoder().decode(WhisperResponse.self, from: data)
            translatedText = responseObject.text
        } catch {
            logger.error("Failed to parse response JSON: \(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Response content: \(responseString)")
            }
            throw WhisperClientError.invalidJSON(error)
        }

        logger.info("Translation successful (length: \(translatedText.count) characters)")
        return translatedText
    }

    // MARK: - Multipart Form Data Encoding

    /// Generate a random boundary string for multipart form-data
    /// - Returns: Unique boundary string
    private func generateBoundary() -> String {
        return "Boundary-\(UUID().uuidString)"
    }

    /// Create multipart form-data body per RFC 2388
    /// - Parameters:
    ///   - audioData: Audio file data
    ///   - language: Language code
    ///   - boundary: Boundary string for multipart encoding
    /// - Returns: Encoded multipart body data
    private func createMultipartBody(audioData: Data, language: String, boundary: String) -> Data {
        var body = Data()

        // Add model parameter
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("whisper-1\r\n")

        // Add language parameter
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
        body.append("\(language)\r\n")

        // Add audio file
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        body.append("Content-Type: audio/wav\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")

        // Final boundary
        body.append("--\(boundary)--\r\n")

        return body
    }

    /// Create multipart form-data body for translation endpoint
    /// - Parameters:
    ///   - audioData: Audio file data
    ///   - boundary: Boundary string for multipart encoding
    /// - Returns: Encoded multipart body data
    /// - Note: Translation endpoint does not require language parameter (auto-detects)
    private func createMultipartBodyForTranslation(audioData: Data, boundary: String) -> Data {
        var body = Data()

        // Add model parameter
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("whisper-1\r\n")

        // Add audio file (no language parameter for translations)
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        body.append("Content-Type: audio/wav\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")

        // Final boundary
        body.append("--\(boundary)--\r\n")

        return body
    }
}

// MARK: - Response Models

/// Whisper API response structure
private struct WhisperResponse: Codable {
    let text: String
}

// MARK: - Errors

/// Errors that can occur during Whisper API transcription
enum WhisperClientError: LocalizedError {
    case networkError(Error)
    case invalidResponse
    case invalidAPIKey
    case invalidRequest
    case rateLimitExceeded
    case serverError(Int)
    case httpError(Int)
    case invalidJSON(Error)

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidAPIKey:
            return "Invalid API key - authentication failed"
        case .invalidRequest:
            return "Invalid request - check audio format and parameters"
        case .rateLimitExceeded:
            return "API rate limit exceeded - please try again later"
        case .serverError(let code):
            return "Server error (HTTP \(code))"
        case .httpError(let code):
            return "HTTP error \(code)"
        case .invalidJSON(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        }
    }
}

// MARK: - Data Extension

/// Helper extension to append strings to Data
private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
