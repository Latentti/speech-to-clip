//
//  TranscriptionService.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-13.
//  Story 4.3: Implement Transcription Service
//

import Foundation
import os.log

/// TranscriptionService orchestrates the full transcription flow
///
/// This service coordinates between AudioFormatService (validation) and
/// WhisperClient (API transcription) to provide a clean, high-level
/// transcription interface. It maps all underlying errors to the unified
/// SpeechToClipError type for consistent error handling across the app.
///
/// Key features:
/// - Orchestrates audio validation + API transcription
/// - Maps errors to SpeechToClipError for app-wide consistency
/// - Async/await API for clean error propagation
/// - Dependency injection for testability
/// - Comprehensive logging with os.log
class TranscriptionService {
    // MARK: - Properties

    /// WhisperClient for API transcription
    private let whisperClient: WhisperClient

    /// AudioFormatService for audio validation/preparation
    private let audioFormatService: AudioFormatService

    /// Logger for TranscriptionService operations
    private let logger: Logger

    // MARK: - Initialization

    /// Initialize TranscriptionService with optional dependency injection
    /// - Parameters:
    ///   - whisperClient: WhisperClient instance (defaults to new instance)
    ///   - audioFormatService: AudioFormatService instance (defaults to new instance)
    init(
        whisperClient: WhisperClient = WhisperClient(),
        audioFormatService: AudioFormatService = AudioFormatService()
    ) {
        self.whisperClient = whisperClient
        self.audioFormatService = audioFormatService
        self.logger = Logger(subsystem: "com.latentti.speech-to-clip", category: "TranscriptionService")
        logger.info("TranscriptionService initialized")
    }

    // MARK: - Public API

    /// Transcribe audio data to text using OpenAI Whisper API
    ///
    /// This method orchestrates the full transcription flow:
    /// 1. Validates/prepares audio via AudioFormatService
    /// 2. Calls WhisperClient to transcribe via API
    /// 3. Maps all errors to SpeechToClipError
    ///
    /// - Parameters:
    ///   - audioData: Audio data to transcribe (WAV format from AudioRecorder)
    ///   - apiKey: OpenAI API key for authentication
    ///   - language: Language code (e.g., "en", "fi", "es")
    /// - Returns: Transcribed text string
    /// - Throws: SpeechToClipError on failure
    func transcribe(audioData: Data, apiKey: String, language: String) async throws -> String {
        let sizeMB = Double(audioData.count) / 1_000_000
        logger.info("Starting transcription (size: \(String(format: "%.2f", sizeMB))MB, language: \(language))")

        // Validate API key
        guard !apiKey.isEmpty else {
            logger.error("API key is missing")
            throw SpeechToClipError.apiKeyMissing
        }

        // Step 1: Validate and prepare audio
        let validatedAudio: Data
        do {
            validatedAudio = try audioFormatService.prepareForWhisperAPI(audioData: audioData)
            logger.debug("Audio validation passed")
        } catch let error as AudioFormatError {
            // Map AudioFormatError to SpeechToClipError
            logger.error("Audio validation failed: \(error.localizedDescription)")
            throw mapAudioFormatError(error)
        } catch {
            // Unexpected error
            logger.error("Unexpected error during audio validation: \(error.localizedDescription)")
            throw SpeechToClipError.transcriptionFailed(reason: error.localizedDescription)
        }

        // Step 2: Call Whisper API
        let transcribedText: String
        do {
            transcribedText = try await whisperClient.transcribe(
                audioData: validatedAudio,
                apiKey: apiKey,
                language: language
            )
            logger.info("Transcription successful (length: \(transcribedText.count) characters)")
        } catch let error as WhisperClientError {
            // Map WhisperClientError to SpeechToClipError
            logger.error("Whisper API error: \(error.localizedDescription)")
            throw mapWhisperClientError(error)
        } catch {
            // Unexpected error
            logger.error("Unexpected error during transcription: \(error.localizedDescription)")
            throw SpeechToClipError.transcriptionFailed(reason: error.localizedDescription)
        }

        return transcribedText
    }

    /// Translate audio data to English using OpenAI Whisper API
    ///
    /// This method orchestrates the full translation flow:
    /// 1. Validates/prepares audio via AudioFormatService
    /// 2. Calls WhisperClient to translate via API (auto-detects source language)
    /// 3. Maps all errors to SpeechToClipError
    ///
    /// - Parameters:
    ///   - audioData: Audio data to translate (WAV format from AudioRecorder)
    ///   - apiKey: OpenAI API key for authentication
    /// - Returns: Translated text string (always in English)
    /// - Throws: SpeechToClipError on failure
    func translate(audioData: Data, apiKey: String) async throws -> String {
        let sizeMB = Double(audioData.count) / 1_000_000
        logger.info("Starting translation (size: \(String(format: "%.2f", sizeMB))MB)")

        // Validate API key
        guard !apiKey.isEmpty else {
            logger.error("API key is missing")
            throw SpeechToClipError.apiKeyMissing
        }

        // Step 1: Validate and prepare audio
        let validatedAudio: Data
        do {
            validatedAudio = try audioFormatService.prepareForWhisperAPI(audioData: audioData)
            logger.debug("Audio validation passed")
        } catch let error as AudioFormatError {
            // Map AudioFormatError to SpeechToClipError
            logger.error("Audio validation failed: \(error.localizedDescription)")
            throw mapAudioFormatError(error)
        } catch {
            // Unexpected error
            logger.error("Unexpected error during audio validation: \(error.localizedDescription)")
            throw SpeechToClipError.transcriptionFailed(reason: error.localizedDescription)
        }

        // Step 2: Call Whisper API translation endpoint
        let translatedText: String
        do {
            translatedText = try await whisperClient.translate(
                audioData: validatedAudio,
                apiKey: apiKey
            )
            logger.info("Translation successful (length: \(translatedText.count) characters)")
        } catch let error as WhisperClientError {
            // Map WhisperClientError to SpeechToClipError
            logger.error("Whisper API error: \(error.localizedDescription)")
            throw mapWhisperClientError(error)
        } catch {
            // Unexpected error
            logger.error("Unexpected error during translation: \(error.localizedDescription)")
            throw SpeechToClipError.transcriptionFailed(reason: error.localizedDescription)
        }

        return translatedText
    }

    // MARK: - Error Mapping

    /// Map AudioFormatError to SpeechToClipError
    /// - Parameter error: AudioFormatError from AudioFormatService
    /// - Returns: Corresponding SpeechToClipError
    private func mapAudioFormatError(_ error: AudioFormatError) -> SpeechToClipError {
        switch error {
        case .fileTooLarge(let size):
            let sizeMB = Double(size) / 1_000_000
            return .audioTooLarge(sizeMB: sizeMB)
        case .invalidFormat, .unsupportedFormat:
            return .audioFormatInvalid
        case .conversionFailed:
            return .audioFormatInvalid
        }
    }

    /// Map WhisperClientError to SpeechToClipError
    /// - Parameter error: WhisperClientError from WhisperClient
    /// - Returns: Corresponding SpeechToClipError
    private func mapWhisperClientError(_ error: WhisperClientError) -> SpeechToClipError {
        switch error {
        case .networkError(let underlying):
            return .networkUnavailable(underlying: underlying)
        case .invalidResponse, .invalidJSON:
            return .transcriptionFailed(reason: "Invalid response from server")
        case .invalidAPIKey:
            return .apiKeyInvalid
        case .invalidRequest:
            return .audioFormatInvalid
        case .rateLimitExceeded:
            return .rateLimitExceeded
        case .serverError(let code):
            return .transcriptionFailed(reason: "Server error (HTTP \(code))")
        case .httpError(let code):
            return .transcriptionFailed(reason: "HTTP error \(code)")
        }
    }
}
