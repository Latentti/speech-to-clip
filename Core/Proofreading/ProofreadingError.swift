//
//  ProofreadingError.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2026-01-07.
//  Story 11.5-2: Create ProofreadingService with GPT-4o-mini
//

import Foundation

/// Errors that can occur during AI proofreading
///
/// This enum provides comprehensive error handling for GPT-4o-mini proofreading operations,
/// with user-friendly error messages and actionable recovery suggestions.
///
/// **Error Cases:**
/// - `missingProfile`: No proofreading profile selected in settings (Story 11.5-6)
/// - `missingAPIKey`: Profile selected but API key is empty/missing (Story 11.5-6)
/// - `networkError(Error)`: Network request failed (no connection, timeout, etc.)
/// - `invalidAPIKey`: OpenAI API key is invalid or unauthorized (HTTP 401)
/// - `rateLimitExceeded`: API rate limit reached (HTTP 429)
/// - `serverError(Int)`: OpenAI server error (HTTP 5xx)
/// - `invalidJSON(Error)`: Failed to parse API response
/// - `emptyResponse`: API returned empty or missing content
///
/// **LocalizedError Conformance:**
/// Each error case provides:
/// - `errorDescription`: User-friendly explanation of what went wrong
/// - `recoverySuggestion`: Actionable steps to resolve the issue
///
/// Example:
/// ```swift
/// do {
///     let correctedText = try await proofreadingService.proofread(...)
/// } catch let error as ProofreadingError {
///     print(error.errorDescription ?? "Unknown error")
///     print(error.recoverySuggestion ?? "")
/// }
/// ```
enum ProofreadingError: Error, LocalizedError {
    /// No proofreading profile selected in settings (Story 11.5-6)
    case missingProfile

    /// Profile selected but API key is empty or missing from Keychain (Story 11.5-6)
    case missingAPIKey

    /// Network request failed (no connection, timeout, DNS failure, etc.)
    case networkError(Error)

    /// API key is invalid or unauthorized (HTTP 401)
    case invalidAPIKey

    /// API rate limit exceeded (HTTP 429)
    case rateLimitExceeded

    /// Server error from OpenAI (HTTP 5xx)
    case serverError(Int)

    /// Failed to parse API response JSON
    case invalidJSON(Error)

    /// API returned empty or missing content in response
    case emptyResponse

    // MARK: - LocalizedError Protocol

    /// User-friendly error description
    var errorDescription: String? {
        switch self {
        case .missingProfile:
            return "Proofreading requires an OpenAI API key"

        case .missingAPIKey:
            return "No API key found for proofreading profile"

        case .networkError(let error):
            return "Network error during proofreading: \(error.localizedDescription)"

        case .invalidAPIKey:
            return "Invalid OpenAI API key for proofreading"

        case .rateLimitExceeded:
            return "OpenAI API rate limit exceeded"

        case .serverError(let statusCode):
            return "OpenAI server error (HTTP \(statusCode))"

        case .invalidJSON(let error):
            return "Failed to parse proofreading response: \(error.localizedDescription)"

        case .emptyResponse:
            return "Proofreading returned empty response"
        }
    }

    /// Actionable recovery suggestion
    var recoverySuggestion: String? {
        switch self {
        case .missingProfile:
            return """
            Please select an OpenAI profile in Settings → Proofreading.

            To set up proofreading:
            1. Open Settings from the menu bar
            2. Go to the Proofreading section
            3. Select an OpenAI profile from the dropdown
            4. Make sure the selected profile has a valid API key
            """

        case .missingAPIKey:
            return """
            The selected proofreading profile doesn't have an API key.

            Please:
            1. Open Settings from the menu bar
            2. Go to Profiles
            3. Edit the profile and add your OpenAI API key
            4. Or select a different profile with a valid key
            """

        case .networkError:
            return """
            Please check your internet connection and try again.

            If the problem persists:
            1. Check if api.openai.com is accessible
            2. Verify your network settings
            3. Try again in a few moments
            """

        case .invalidAPIKey:
            return """
            Your OpenAI API key appears to be invalid.

            Please verify:
            1. The API key is correct in Settings → Profiles
            2. The key has not been revoked in your OpenAI dashboard
            3. The key has access to GPT-4o-mini model
            """

        case .rateLimitExceeded:
            return """
            You've exceeded OpenAI's rate limit.

            Please:
            1. Wait a few moments and try again
            2. Check your usage limits in the OpenAI dashboard
            3. Consider upgrading your API plan if needed
            """

        case .serverError(let statusCode):
            return """
            OpenAI's servers returned an error (HTTP \(statusCode)).

            This is usually temporary. Please:
            1. Wait a few moments and try again
            2. Check status.openai.com for service issues
            """

        case .invalidJSON:
            return """
            The API response could not be parsed.

            This is unexpected. Please:
            1. Try again
            2. If the problem persists, report this issue
            """

        case .emptyResponse:
            return """
            The proofreading API returned no content.

            This can happen if:
            1. The input text was too short
            2. There was a temporary API issue

            Please try again with your text.
            """
        }
    }
}
