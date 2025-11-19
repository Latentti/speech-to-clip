//
//  WhisperCppClient.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-19.
//  Story 11.1: Create WhisperCppClient Service with Health Check
//

import Foundation
import os.log

/// WhisperResponse represents the JSON response from whisper.cpp server
///
/// Response format matches OpenAI API specification: {"text": "transcribed text"}
private struct WhisperResponse: Codable, Sendable {
    let text: String
}

/// WhisperCppClient provides async access to local whisper.cpp server
///
/// This actor handles communication with a locally-running whisper.cpp server,
/// ensuring privacy by keeping all audio data on the local machine.
/// Follows async/await pattern and uses actor isolation for thread safety.
///
/// **Privacy Guarantee**: All network calls are localhost-only (127.0.0.1 or localhost).
/// No data ever leaves the machine when using this client.
///
/// Key features:
/// - Actor isolation for thread-safe concurrent access
/// - Health check endpoint to verify server availability
/// - 5-second timeout for quick feedback
/// - Localhost-only validation (privacy guarantee)
/// - Async/await API for clean error propagation
///
/// Reference: Architecture Decision #2 (HTTP/URLSession), #5 (async/await)
actor WhisperCppClient {
    // MARK: - Properties

    /// Health check timeout in seconds
    private let healthCheckTimeout: TimeInterval = 5.0

    /// Transcription timeout in seconds (longer than health check)
    private let transcriptionTimeout: TimeInterval = 60.0

    /// URLSession for making HTTP requests
    /// Can be injected for testing with URLProtocol mocking
    private let urlSession: URLSession

    /// Logger for WhisperCppClient operations
    private let logger = Logger(subsystem: "com.latentti.speech-to-clip", category: "WhisperCppClient")

    // MARK: - Initialization

    /// Initialize WhisperCppClient with optional custom URLSession
    /// - Parameter urlSession: URLSession to use (defaults to .shared)
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        logger.info("WhisperCppClient initialized")
    }

    // MARK: - Health Check

    /// Check if whisper.cpp server is running and available
    ///
    /// Makes a GET request to the server's health endpoint with a 5-second timeout.
    /// This method should be called before attempting transcription to ensure the
    /// server is available.
    ///
    /// **Privacy Note**: This method only connects to localhost (127.0.0.1).
    /// No external network calls are ever made.
    ///
    /// - Parameter port: Port number where whisper.cpp server is running (default: 8080)
    /// - Returns: `true` if server responds with HTTP 200 OK
    /// - Throws: `WhisperCppError.serverNotRunning` if server is not reachable
    /// - Throws: `WhisperCppError.connectionTimeout` if request times out
    ///
    /// Example:
    /// ```swift
    /// let client = WhisperCppClient()
    /// do {
    ///     let isAvailable = try await client.checkServerAvailability(port: 8080)
    ///     if isAvailable {
    ///         print("Server is ready for transcription")
    ///     }
    /// } catch {
    ///     print("Server is not available: \(error)")
    /// }
    /// ```
    func checkServerAvailability(port: Int) async throws -> Bool {
        // Construct localhost-only URL
        // Privacy guarantee: Only localhost or 127.0.0.1 are used
        guard let url = URL(string: "http://localhost:\(port)/health") else {
            logger.error("Failed to construct health check URL for port \(port)")
            throw WhisperCppError.serverNotRunning
        }

        // Create GET request with timeout
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = healthCheckTimeout

        logger.info("Checking whisper.cpp server availability at \(url.absoluteString)")

        do {
            // Make async network request
            let (_, response) = try await urlSession.data(for: request)

            // Check HTTP status code
            guard let httpResponse = response as? HTTPURLResponse else {
                logger.warning("Health check response was not HTTPURLResponse")
                throw WhisperCppError.serverNotRunning
            }

            if httpResponse.statusCode == 200 {
                logger.info("whisper.cpp server is available (HTTP 200)")
                return true
            } else {
                logger.warning("whisper.cpp server returned HTTP \(httpResponse.statusCode)")
                throw WhisperCppError.serverNotRunning
            }
        } catch let urlError as URLError where urlError.code == .timedOut {
            // Handle timeout specifically
            logger.error("Health check timed out after \(self.healthCheckTimeout) seconds")
            throw WhisperCppError.connectionTimeout
        } catch let whisperError as WhisperCppError {
            // Re-throw WhisperCppError as-is
            throw whisperError
        } catch {
            // Any other network error means server is not running
            logger.error("Health check failed: \(error.localizedDescription)")
            throw WhisperCppError.serverNotRunning
        }
    }

    // MARK: - Multipart Form-Data Encoding

    /// Create multipart form-data body for whisper.cpp HTTP endpoint
    ///
    /// Constructs a properly formatted multipart/form-data request body containing
    /// audio data and parameters for whisper.cpp transcription. The format matches
    /// OpenAI's API specification for compatibility.
    ///
    /// **Format Specification:**
    /// - File part: name="file", filename="audio.wav", Content-Type: audio/wav
    /// - Model part: name="model", value=model name
    /// - Language part: name="language", value=language code
    /// - CRLF line endings (\r\n) throughout as per HTTP multipart spec
    /// - Boundary markers: --{boundary} and --{boundary}-- for final
    ///
    /// **Privacy Note**: This method only prepares data for localhost transmission.
    /// No external network calls are made.
    ///
    /// - Parameters:
    ///   - audioData: WAV audio data to transcribe
    ///   - model: Whisper model name (e.g., "base", "medium", "large")
    ///   - language: Language code (e.g., "en", "fi")
    ///   - boundary: Unique boundary string (typically UUID().uuidString)
    /// - Returns: Complete multipart form-data body ready for HTTP POST
    ///
    /// Example:
    /// ```swift
    /// let boundary = UUID().uuidString
    /// let body = createMultipartBody(
    ///     audioData: wavData,
    ///     model: "base",
    ///     language: "en",
    ///     boundary: boundary
    /// )
    /// ```
    private func createMultipartBody(
        audioData: Data,
        model: String,
        language: String,
        boundary: String
    ) -> Data {
        var body = Data()

        // File part
        // Format: --boundary + CRLF + headers + blank line + binary data + CRLF
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n")
        body.append("Content-Type: audio/wav\r\n\r\n")
        body.append(audioData)
        body.append("\r\n")

        // Model part
        // Format: --boundary + CRLF + header + blank line + text value + CRLF
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        body.append("\(model)\r\n")

        // Language part
        // Format: --boundary + CRLF + header + blank line + text value + CRLF
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
        body.append("\(language)\r\n")

        // Final boundary marker with double dashes
        body.append("--\(boundary)--\r\n")

        return body
    }

    // MARK: - Transcription

    /// Transcribe audio data using whisper.cpp server
    ///
    /// Sends audio data to the local whisper.cpp server and returns the transcribed text.
    /// This method constructs a multipart/form-data POST request with a 60-second timeout
    /// and validates the HTTP 200 response with JSON decoding.
    ///
    /// **Privacy Guarantee**: All network calls are localhost-only (127.0.0.1 or localhost).
    /// No data ever leaves the machine when using this client.
    ///
    /// - Parameters:
    ///   - audioData: WAV audio data to transcribe
    ///   - model: Whisper model name (e.g., "base", "medium", "large")
    ///   - port: Port number where whisper.cpp server is running
    ///   - language: Language code (e.g., "en", "fi")
    /// - Returns: Transcribed text string
    /// - Throws: `WhisperCppError.serverNotRunning` if server is not reachable
    /// - Throws: `WhisperCppError.connectionTimeout` if request times out
    /// - Throws: `WhisperCppError.invalidResponse` if response is not valid HTTP or JSON
    /// - Throws: `WhisperCppError.transcriptionFailed(statusCode:)` if server returns non-200 status
    ///
    /// Example:
    /// ```swift
    /// let client = WhisperCppClient()
    /// do {
    ///     let text = try await client.transcribe(
    ///         audioData: wavData,
    ///         model: "base",
    ///         port: 8080,
    ///         language: "en"
    ///     )
    ///     print("Transcription: \(text)")
    /// } catch {
    ///     print("Transcription failed: \(error)")
    /// }
    /// ```
    func transcribe(
        audioData: Data,
        model: String,
        port: Int,
        language: String
    ) async throws -> String {
        // Construct localhost-only URL
        // Privacy guarantee: Only localhost or 127.0.0.1 are used
        let url = URL(string: "http://localhost:\(port)/v1/audio/transcriptions")!

        // Create POST request with multipart/form-data
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = transcriptionTimeout

        // Generate boundary and create multipart body
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)",
                        forHTTPHeaderField: "Content-Type")
        request.httpBody = createMultipartBody(
            audioData: audioData,
            model: model,
            language: language,
            boundary: boundary
        )

        logger.info("Starting transcription request (audio: \(audioData.count) bytes, model: \(model), language: \(language), port: \(port))")

        // Make async network call
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            logger.error("Transcription request timed out after \(self.transcriptionTimeout) seconds")
            throw WhisperCppError.connectionTimeout
        } catch {
            logger.error("Transcription request failed: \(error.localizedDescription)")
            throw WhisperCppError.serverNotRunning
        }

        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type received")
            throw WhisperCppError.invalidResponse
        }

        // Validate HTTP 200 status
        guard httpResponse.statusCode == 200 else {
            logger.error("Transcription failed with HTTP \(httpResponse.statusCode)")
            throw WhisperCppError.transcriptionFailed(statusCode: httpResponse.statusCode)
        }

        // Decode JSON response
        let result: WhisperResponse
        do {
            result = try JSONDecoder().decode(WhisperResponse.self, from: data)
        } catch {
            logger.error("Failed to decode response JSON: \(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Response content: \(responseString)")
            }
            throw WhisperCppError.invalidResponse
        }

        logger.info("Transcription successful (length: \(result.text.count) characters)")
        return result.text
    }
}
