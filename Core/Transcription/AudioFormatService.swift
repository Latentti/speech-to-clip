//
//  AudioFormatService.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-13.
//  Story 4.2: Implement Audio Format Conversion
//

import Foundation
import os.log

/// AudioFormatService validates and prepares audio data for Whisper API
///
/// This service validates audio format and file size requirements before
/// sending to the Whisper API. Since AudioRecorder already outputs WAV format
/// at 16kHz mono (which is fully compatible with Whisper API), this service
/// primarily performs validation and passes through the data unchanged.
///
/// Key features:
/// - File size validation (< 25MB limit)
/// - WAV format validation (RIFF/WAVE header check)
/// - Fast performance (< 10ms validation)
/// - Comprehensive error handling
/// - Zero-copy passthrough for valid data
/// - Unified logging with os.log for production-safe logging
class AudioFormatService {
    // MARK: - Constants

    /// Maximum file size accepted by Whisper API (25MB)
    private let maxFileSize = 25_000_000

    /// Logger for AudioFormatService operations
    private let logger = Logger(subsystem: "com.latentti.speech-to-clip", category: "AudioFormatService")

    // MARK: - Initialization

    init() {
        logger.info("AudioFormatService initialized")
    }

    // MARK: - Public API

    /// Prepare audio data for Whisper API
    ///
    /// Validates audio format and file size. If validation passes, returns
    /// the data unchanged. AudioRecorder already provides WAV format at 16kHz
    /// mono, which is fully compatible with Whisper API requirements.
    ///
    /// - Parameter audioData: Raw audio data from AudioRecorder
    /// - Returns: Validated audio data ready for API upload
    /// - Throws: AudioFormatError if validation fails
    func prepareForWhisperAPI(audioData: Data) throws -> Data {
        let sizeMB = Double(audioData.count) / 1_000_000
        logger.info("Validating audio format (size: \(String(format: "%.2f", sizeMB))MB)")

        // 1. Validate file size (< 25MB)
        guard audioData.count < maxFileSize else {
            logger.error("Audio file too large: \(String(format: "%.2f", sizeMB))MB")
            throw AudioFormatError.fileTooLarge(size: audioData.count)
        }

        // 2. Validate WAV format (check RIFF/WAVE header)
        guard isValidWAV(audioData) else {
            logger.error("Invalid audio format - not a valid WAV file")
            throw AudioFormatError.invalidFormat
        }

        logger.info("Audio validation passed - ready for Whisper API")

        // 3. AudioRecorder already provides 16kHz mono WAV - no conversion needed!
        // Simply return the data as-is (zero-copy passthrough)
        return audioData
    }

    // MARK: - Private Methods

    /// Validate WAV format by checking RIFF/WAVE header
    ///
    /// WAV files start with:
    /// - Bytes 0-3: "RIFF" (chunk ID)
    /// - Bytes 4-7: File size - 8 (chunk size)
    /// - Bytes 8-11: "WAVE" (format)
    ///
    /// - Parameter data: Audio data to validate
    /// - Returns: True if data has valid WAV header
    private func isValidWAV(_ data: Data) -> Bool {
        // Need at least 12 bytes for RIFF header
        guard data.count >= 12 else {
            logger.debug("File too small to be valid WAV (< 12 bytes)")
            return false
        }

        // Extract first 12 bytes for header validation
        let header = data.prefix(12)

        // Check for "RIFF" at bytes 0-3
        let riffMarker = Data([0x52, 0x49, 0x46, 0x46]) // "RIFF" in ASCII
        let hasRIFF = header.prefix(4) == riffMarker

        // Check for "WAVE" at bytes 8-11
        let waveMarker = Data([0x57, 0x41, 0x56, 0x45]) // "WAVE" in ASCII
        let hasWAVE = header.suffix(from: 8).prefix(4) == waveMarker

        let isValid = hasRIFF && hasWAVE

        if !isValid {
            if !hasRIFF {
                logger.debug("Missing RIFF header marker")
            }
            if !hasWAVE {
                logger.debug("Missing WAVE format marker")
            }
        }

        return isValid
    }
}

// MARK: - Errors

/// Errors that can occur during audio format validation
enum AudioFormatError: LocalizedError {
    case fileTooLarge(size: Int)
    case invalidFormat
    case unsupportedFormat(String)
    case conversionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let size):
            let sizeMB = String(format: "%.2f", Double(size) / 1_000_000)
            return "Audio file too large (\(sizeMB)MB). Maximum size is 25MB."
        case .invalidFormat:
            return "Audio format is invalid or corrupted. Expected WAV format."
        case .unsupportedFormat(let format):
            return "Audio format '\(format)' is not supported by Whisper API"
        case .conversionFailed(let error):
            return "Failed to convert audio format: \(error.localizedDescription)"
        }
    }
}
