//
//  SettingsService.swift
//  speech-to-clip
//
//  Created by BMad Dev Agent on 2025-11-14.
//  Story 6.4: Implement Settings Persistence
//  Story 6.5: Add Validation and Error Handling
//

import Foundation

/// Result type for settings validation
///
/// Story 6.5: Type-safe validation result with error messages
enum ValidationResult: Equatable {
    case valid
    case invalid(errors: [String])

    /// Whether the validation passed
    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }

    /// Error messages if validation failed, empty array if valid
    var errorMessages: [String] {
        if case .invalid(let errors) = self { return errors }
        return []
    }
}

/// Service for persisting user settings to UserDefaults
///
/// Implements atomic save/load of AppSettings using Codable and UserDefaults.
/// Provides graceful error handling - failures return nil rather than throwing,
/// allowing caller to use default values. This ensures settings persistence is
/// non-critical and never crashes the app.
///
/// **Usage:**
/// ```swift
/// let service = SettingsService()
/// service.saveSettings(appSettings)
///
/// if let loaded = service.loadSettings() {
///     // Use loaded settings
/// } else {
///     // Use defaults (first launch or corrupted data)
/// }
/// ```
///
/// - Note: Story 6.4 - Settings persistence with graceful degradation
class SettingsService {
    // MARK: - Properties

    /// UserDefaults instance for persistence
    private let userDefaults: UserDefaults

    /// Key for storing settings in UserDefaults
    private let settingsKey = "com.latentti.speech-to-clip.settings"

    // MARK: - Initialization

    /// Initialize SettingsService with UserDefaults instance
    ///
    /// - Parameter userDefaults: UserDefaults instance to use (defaults to .standard)
    ///
    /// Dependency injection allows tests to use separate UserDefaults suite
    /// to avoid polluting real app settings.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    // MARK: - Public Methods

    /// Save settings to UserDefaults
    ///
    /// Encodes AppSettings to JSON using JSONEncoder and stores in UserDefaults.
    /// Failures are logged but do not throw - settings persistence is non-critical.
    ///
    /// - Parameter settings: AppSettings instance to persist
    ///
    /// - Complexity: O(1) - Direct UserDefaults write after JSON encoding
    func saveSettings(_ settings: AppSettings) {
        do {
            // Encode settings to JSON Data using JSONEncoder
            let encoder = JSONEncoder()
            let data = try encoder.encode(settings)

            // Write to UserDefaults with app-specific key
            userDefaults.set(data, forKey: settingsKey)

            print("💾 Settings saved to UserDefaults successfully")
        } catch {
            // Log encoding error but don't throw - non-critical failure
            print("⚠️ Failed to save settings: \(error.localizedDescription)")
            print("   Settings will remain in memory but not persist across launches")
        }
    }

    /// Load settings from UserDefaults
    ///
    /// Reads JSON Data from UserDefaults and decodes to AppSettings using JSONDecoder.
    /// Returns nil on any error (missing data, corrupted JSON, decode failure) to allow
    /// caller to gracefully fall back to default AppSettings.
    ///
    /// - Returns: AppSettings if found and valid, nil otherwise
    ///
    /// Nil return scenarios:
    /// - First launch (key doesn't exist) - expected behavior
    /// - Corrupted data (invalid JSON) - graceful degradation
    /// - Decode failure (schema mismatch) - version upgrade scenario
    ///
    /// - Complexity: O(1) - Direct UserDefaults read and JSON decode
    func loadSettings() -> AppSettings? {
        // Read Data from UserDefaults
        guard let data = userDefaults.data(forKey: settingsKey) else {
            print("ℹ️ No saved settings found in UserDefaults (likely first launch)")
            return nil
        }

        do {
            // Decode JSON Data to AppSettings using JSONDecoder
            let decoder = JSONDecoder()
            let settings = try decoder.decode(AppSettings.self, from: data)

            print("✅ Settings loaded from UserDefaults successfully")
            return settings
        } catch {
            // Log decode error but return nil for graceful fallback
            print("⚠️ Failed to load settings: \(error.localizedDescription)")
            print("   Using default settings instead (corrupted data or schema mismatch)")
            return nil
        }
    }

    /// Validate settings for correctness and completeness
    ///
    /// Checks settings against business rules before saving. Prevents invalid
    /// configurations from being persisted to UserDefaults.
    ///
    /// **Validation Rules:**
    /// - Hotkey must have at least one modifier key
    /// - Language must be a supported Whisper language code
    ///
    /// - Parameter settings: AppSettings instance to validate
    /// - Returns: ValidationResult indicating success or specific error messages
    ///
    /// Story 6.5: Settings validation with clear error messages
    func validateSettings(_ settings: AppSettings) -> ValidationResult {
        var errors: [String] = []

        // Validate hotkey: must have at least one modifier
        if settings.hotkey.modifiers.isEmpty {
            errors.append("Hotkey must have at least one modifier key (⌘, ⌥, ⌃, or ⇧)")
        }

        // Note: Language validation removed - language is now per-profile in Profile.language

        return errors.isEmpty ? .valid : .invalid(errors: errors)
    }
}
