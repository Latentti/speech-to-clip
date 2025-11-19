//
//  WhisperCppError.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-19.
//  Story 11.4: Create WhisperCppError Types
//

import Foundation

/// Errors that can occur during Local Whisper integration
///
/// This enum provides comprehensive error handling for whisper.cpp server communication,
/// with user-friendly error messages and actionable recovery suggestions.
///
/// **Error Cases:**
/// - `serverNotRunning`: Server is not accessible on the specified port
/// - `connectionTimeout`: Server did not respond within the timeout period
/// - `invalidResponse`: Server returned an unexpected or malformed response
/// - `transcriptionFailed(statusCode:)`: Server returned a non-200 HTTP status code
/// - `invalidModel(String)`: Specified model name is not valid
///
/// **LocalizedError Conformance:**
/// Each error case provides:
/// - `errorDescription`: User-friendly explanation of what went wrong
/// - `recoverySuggestion`: Actionable steps to resolve the issue
///
/// Example:
/// ```swift
/// do {
///     let text = try await whisperClient.transcribe(...)
/// } catch let error as WhisperCppError {
///     // Error will display user-friendly message
///     print(error.errorDescription ?? "Unknown error")
///     print(error.recoverySuggestion ?? "")
/// }
/// ```
enum WhisperCppError: Error, LocalizedError {
    /// Server is not running or not accessible on the specified port
    case serverNotRunning

    /// Connection to server timed out
    case connectionTimeout

    /// Server returned an invalid or unexpected response
    case invalidResponse

    /// Transcription request failed with a specific HTTP status code
    case transcriptionFailed(statusCode: Int)

    /// Invalid model name specified
    case invalidModel(String)

    // MARK: - Documentation URL

    /// URL to relevant whisper.cpp documentation for this error
    ///
    /// Returns a URL to the appropriate documentation section based on the error type.
    /// - serverNotRunning, connectionTimeout: Links to server setup documentation
    /// - Other errors: Links to general whisper.cpp documentation
    var helpURL: URL? {
        switch self {
        case .serverNotRunning, .connectionTimeout:
            return URL(string: "https://github.com/ggerganov/whisper.cpp#server")
        case .invalidResponse, .transcriptionFailed, .invalidModel:
            return URL(string: "https://github.com/ggerganov/whisper.cpp")
        }
    }

    // MARK: - LocalizedError Protocol

    /// User-friendly error description
    var errorDescription: String? {
        switch self {
        case .serverNotRunning:
            return "Local Whisper server is not running"

        case .connectionTimeout:
            return "Connection to Local Whisper server timed out"

        case .invalidResponse:
            return "Invalid response from Local Whisper server"

        case .transcriptionFailed(let statusCode):
            return "Transcription failed with HTTP status \(statusCode)"

        case .invalidModel(let name):
            return "Invalid model name: \(name)"
        }
    }

    /// Actionable recovery suggestion with documentation links
    var recoverySuggestion: String? {
        switch self {
        case .serverNotRunning:
            return """
            Please start the whisper.cpp server:

            1. Navigate to your whisper.cpp directory
            2. Run: ./server -m models/ggml-base.bin --port 8080

            For more information: https://github.com/ggerganov/whisper.cpp#server
            """

        case .connectionTimeout:
            return """
            The server did not respond in time. Please check:

            1. Verify whisper.cpp server is running
            2. Check the port number in profile settings (default: 8080)
            3. Review server logs for errors
            """

        case .invalidResponse:
            return """
            The server returned an unexpected response. Please:

            1. Check whisper.cpp server logs for errors
            2. Verify you're running a compatible whisper.cpp version
            3. Try restarting the server

            For troubleshooting: https://github.com/ggerganov/whisper.cpp#server
            """

        case .transcriptionFailed(let statusCode):
            return """
            The server returned HTTP status \(statusCode).

            Common status codes:
            - 400: Bad request (invalid audio format or parameters)
            - 500: Internal server error

            Check whisper.cpp server logs for detailed error information.
            """

        case .invalidModel(let name):
            return """
            Model "\(name)" is not valid.

            Valid whisper.cpp model names:
            - tiny (fastest, least accurate)
            - base (recommended for most uses)
            - small
            - medium
            - large (slowest, most accurate)

            Download models from: https://github.com/ggerganov/whisper.cpp#models
            """
        }
    }
}
