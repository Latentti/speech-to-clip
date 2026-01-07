//
//  ProofreadingService.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2026-01-07.
//  Story 11.5-2: Create ProofreadingService with GPT-4o-mini
//

import Foundation
import os.log

/// ProofreadingService provides async API access to OpenAI GPT-4o-mini for text proofreading
///
/// This service corrects spelling, punctuation, and capitalization errors in transcribed text
/// using the OpenAI Chat Completions API with the gpt-4o-mini model.
///
/// Key features:
/// - Async/await API for clean error propagation
/// - JSON encoding/decoding for Chat Completions API
/// - 30-second timeout (GPT typically responds in 1-3 seconds)
/// - Comprehensive error handling (network, API, parsing)
/// - Language-aware proofreading via system prompt
/// - Thread-safe URLSession usage
/// - Unified logging with os.log for production-safe logging
///
/// Example:
/// ```swift
/// let service = ProofreadingService()
/// let correctedText = try await service.proofread(
///     text: "Helo wrold",
///     language: "English",
///     apiKey: "sk-..."
/// )
/// // correctedText: "Hello world"
/// ```
class ProofreadingService {
    // MARK: - Properties

    /// OpenAI Chat Completions API endpoint
    private let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    /// Request timeout in seconds
    private let timeout: TimeInterval = 30.0

    /// Model to use for proofreading (cost-effective, fast)
    private let model = "gpt-4o-mini"

    /// URLSession for making HTTP requests
    /// Can be injected for testing with URLProtocol mocking
    private let urlSession: URLSession

    /// Logger for ProofreadingService operations
    private let logger = Logger(subsystem: "com.latentti.speech-to-clip", category: "ProofreadingService")

    // MARK: - Initialization

    /// Initialize ProofreadingService with optional custom URLSession
    /// - Parameter urlSession: URLSession to use (defaults to .shared)
    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        logger.info("ProofreadingService initialized")
    }

    // MARK: - Public API

    /// Proofread text using OpenAI GPT-4o-mini
    ///
    /// Sends the text to the OpenAI Chat Completions API for spelling, punctuation,
    /// and capitalization corrections. The proofreading preserves sentence structure
    /// and meaning while fixing errors.
    ///
    /// - Parameters:
    ///   - text: The transcribed text to proofread
    ///   - language: Language name (e.g., "English", "Finnish") for context
    ///   - apiKey: OpenAI API key (Bearer token)
    /// - Returns: Corrected text string
    /// - Throws: `ProofreadingError` on failure
    func proofread(text: String, language: String, apiKey: String) async throws -> String {
        logger.info("Starting proofreading request (text length: \(text.count) characters, language: \(language))")

        // Build request body
        let requestBody = buildRequestBody(text: text, language: language)

        // Encode request body to JSON
        let httpBody: Data
        do {
            httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            logger.error("Failed to encode request body: \(error.localizedDescription)")
            throw ProofreadingError.invalidJSON(error)
        }

        // Create URLRequest
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody

        // Send request
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
            logger.error("Network request failed: \(error.localizedDescription)")
            throw ProofreadingError.networkError(error)
        }

        // Validate HTTP response
        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type received")
            throw ProofreadingError.emptyResponse
        }

        logger.debug("Received response with status: \(httpResponse.statusCode)")

        // Handle HTTP status codes
        switch httpResponse.statusCode {
        case 200:
            // Success - continue to parse response
            break
        case 401:
            logger.error("Authentication failed - invalid API key")
            throw ProofreadingError.invalidAPIKey
        case 429:
            logger.error("Rate limit exceeded")
            throw ProofreadingError.rateLimitExceeded
        case 500...599:
            logger.error("Server error: \(httpResponse.statusCode)")
            throw ProofreadingError.serverError(httpResponse.statusCode)
        default:
            logger.error("Unexpected status code: \(httpResponse.statusCode)")
            throw ProofreadingError.serverError(httpResponse.statusCode)
        }

        // Parse JSON response
        let chatResponse: ChatCompletionResponse
        do {
            chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        } catch {
            logger.error("Failed to parse response JSON: \(error.localizedDescription)")
            if let responseString = String(data: data, encoding: .utf8) {
                logger.debug("Response content: \(responseString)")
            }
            throw ProofreadingError.invalidJSON(error)
        }

        // Extract content from response
        guard let firstChoice = chatResponse.choices.first,
              let content = firstChoice.message.content,
              !content.isEmpty else {
            logger.error("Empty or missing content in response")
            throw ProofreadingError.emptyResponse
        }

        logger.info("Proofreading successful (result length: \(content.count) characters)")
        return content
    }

    // MARK: - Private Methods

    /// Build the Chat Completions API request body
    /// - Parameters:
    ///   - text: Text to proofread
    ///   - language: Language for context
    /// - Returns: Encodable request body
    private func buildRequestBody(text: String, language: String) -> ChatCompletionRequest {
        let systemPrompt = """
            You are a proofreader. Fix spelling, punctuation, and capitalization errors. \
            Do not change sentence structure or meaning. Output only the corrected text with no explanations. \
            The text is in \(language).
            """

        return ChatCompletionRequest(
            model: model,
            messages: [
                ChatMessage(role: "system", content: systemPrompt),
                ChatMessage(role: "user", content: text)
            ]
        )
    }
}

// MARK: - Request Models

/// Chat Completions API request body
private struct ChatCompletionRequest: Encodable {
    let model: String
    let messages: [ChatMessage]
}

/// Chat message for request
private struct ChatMessage: Encodable {
    let role: String
    let content: String
}

// MARK: - Response Models

/// Chat Completions API response structure
private struct ChatCompletionResponse: Decodable {
    let choices: [Choice]

    struct Choice: Decodable {
        let message: Message

        struct Message: Decodable {
            let role: String?
            let content: String?
        }
    }
}
